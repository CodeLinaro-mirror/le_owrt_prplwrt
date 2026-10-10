Sanitizer job only (cram QEMU x86-64 [sanitize]): start a per-minute RSS sampler on the DUT.
This test is not part of any [auto|full|...] selection. The sanitize loop driver (.gitlab/scripts/sanitize/run-loop.sh)
runs it first in every iteration: the reboot test of [full] stops the sampler, so each iteration starts a new one
(the series restarts at seq 1 after a reboot; serial-check.py judges every boot on its own).
Two copies of every sample:
- /ext/sanitizer/san-rss.log on the persistent overlay: "# seq=<n> <UTC time> up=<uptime s> MemAvailable_kB=<n> ExtFree_kB=<n>",
then the 15 largest VmRSS lines "<uptime> <pid> <name> <kB>". The file is written only while the report directory exists;
- /dev/console, so QEMU writes it to serial.log on the host at once: "SANRSS <seq> <uptime> <pid> <name> <kB>",
with MemAvailable as pid 0, name MemAvailable, the free space as pid 0, name ExtFree_kB, and the state of the
report directory as pid 0, name ReportDir, value 1 or 0: "SANRSS <seq> <uptime> 0 ReportDir <1|0>".
ReportDir is 1 if /ext/sanitizer exists and a probe file can be created and removed in it, else 0. The sampler never
creates the directory (the shim package ships it): a missing directory must show as 0, not be repaired. The console
lines are always printed, also when the directory is missing.
ExtFree_kB is the 4th column of line 2 of busybox "df -k /ext/sanitizer", i.e. the filesystem that holds the
report directory: /ext if it is a mount point, else the root overlay. -1 = df failed (also when the directory is gone).
The harness flags the run below 50 MB.
PSS sampling: after the SANRSS lines, the sampler writes a second line type to the console only (not to san-rss.log):
"SANPSS <seq> <uptime> <pid> <name> <pss_kB> <anon_kB> <swap_kB>", from /proc/<pid>/smaps_rollup (Pss, Anonymous, Swap), for
the same 15 processes as the SANRSS rows of that <seq>. Pss splits shared pages between the processes that map them, so the sum
does not double-count; RSS does. Two more kinds of row, both with pid 0 and unused columns 0:
"SANPSS <seq> <uptime> 0 PssSum <pss_kB> <anon_kB> <swap_kB>" the sum over ALL processes with a smaps_rollup (not only the top 15);
"SANPSS <seq> <uptime> 0 PssProcs <n> 0 0" the number of processes in that sum;
"SANPSS <seq> <uptime> 0 <AnonPages|Shmem|SUnreclaim> <kB> 0 0" kernel-side numbers from /proc/meminfo (MemAvailable is in SANRSS).
A process that exits during the pass is skipped. No SANPSS line is printed without smaps_rollup. The lines never start with
SANRSS, so the serial-check.py metrics check and the watchdog ignore them. The pass reads one small file per process (busybox sh and awk only).
The sampler runs with oom_score_adj -1000 (inherited by its awk/sort children).
The check at the end needs san-rss.log: if the directory is missing at the start, this test fails visibly.

  $ C=$(echo "$CRAM_REMOTE_COMMAND" | sed 's/^ssh -n /ssh /')
  $ cat > "$CRAMTMP/san-sampler.sh" <<'X'
  > echo -1000 > /proc/self/oom_score_adj
  > D=/ext/sanitizer
  > S=/tmp/san-sample.txt
  > P=/tmp/san-pss.txt
  > seq=0
  > while true; do
  >   seq=$((seq + 1))
  >   t=$(cut -d' ' -f1 /proc/uptime)
  >   m=$(awk '/^MemAvailable/ {print $2}' /proc/meminfo)
  >   for s in /proc/[0-9]*/status; do awk -v t="$t" '/^Name/ {n=$2} /^Pid/ {p=$2} /^VmRSS/ {print $2, t, p, n}' $s 2>/dev/null; done | sort -n -r | head -15 | awk '{print $2, $3, $4, $1}' > $S
  >   f=$(df -k $D 2>/dev/null | awk 'NR == 2 {print $4}')
  >   case $f in ''|*[!0-9]*) f=-1 ;; esac
  >   r=0
  >   if [ -d /ext/sanitizer ] && touch /ext/sanitizer/.san-probe 2>/dev/null && rm -f /ext/sanitizer/.san-probe 2>/dev/null; then r=1; fi
  >   if [ $r = 1 ]; then { echo "# seq=$seq $(date -u '+%Y-%m-%dT%H:%M:%SZ') up=$t MemAvailable_kB=$m ExtFree_kB=$f"; cat $S; } >> /ext/sanitizer/san-rss.log 2>/dev/null; fi
  >   { echo "$t 0 MemAvailable $m"; echo "$t 0 ExtFree_kB $f"; echo "$t 0 ReportDir $r"; cat $S; } | sed "s/^/SANRSS $seq /" > /dev/console
  >   for s in /proc/[0-9]*/smaps_rollup; do p=${s#/proc/}; p=${p%%/*}; awk -v p="$p" '/^Pss:/ {a=$2} /^Anonymous:/ {b=$2} /^Swap:/ {c=$2} END {if (a != "") print p, a, b + 0, c + 0}' $s 2>/dev/null; done > $P
  >   { awk -v q="$seq" -v t="$t" 'FILENAME == ARGV[1] {n[$2] = $3; o[++k] = $2; next} {sp += $2; sa += $3; sw += $4; np++; pp[$1] = $2; pa[$1] = $3; pw[$1] = $4} END {for (i = 1; i <= k; i++) if (o[i] in pp) print "SANPSS", q, t, o[i], n[o[i]], pp[o[i]], pa[o[i]], pw[o[i]]; if (np) {print "SANPSS", q, t, 0, "PssSum", sp, sa, sw; print "SANPSS", q, t, 0, "PssProcs", np, 0, 0}}' $S $P; awk -v q="$seq" -v t="$t" '/^(AnonPages|Shmem|SUnreclaim):/ {sub(/:$/, "", $1); print "SANPSS", q, t, 0, $1, $2, 0, 0}' /proc/meminfo; } > /dev/console
  >   sleep 60
  > done
  > X
  $ $C "cat > /tmp/san-sampler.sh; (sh /tmp/san-sampler.sh </dev/null >/dev/null 2>&1 &); i=0; while [ \$i -lt 30 ] && ! test -s /ext/sanitizer/san-rss.log; do sleep 1; i=\$((i + 1)); done; test -s /ext/sanitizer/san-rss.log && echo started" < "$CRAMTMP/san-sampler.sh"
  started
