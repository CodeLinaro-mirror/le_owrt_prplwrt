Sanitizer job only (cram QEMU x86-64 [sanitize]): leak-check broadcast at the end of a [full]
iteration, BEFORE qemu-x86-64/reboot.t (the loop driver puts it in front of reboot.t), so the SANSTATS
free rates (used by the quarantine calibration) and the leak checks cover the whole iteration, not the next boot.
Also a /proc RSS snapshot of every process before the reboot (proc-rss-prereboot.txt).

  $ C=$(echo "$CRAM_REMOTE_COMMAND" | sed 's/^ssh -n /ssh /')
  $ A=${TESTBED_QEMU_ARTIFACT_ROOT:-/artifacts}; test -d "$A" || A=/tmp

Boot 1 syslog and the process-monitor tests are lost at the reboot test, so save them now
(.gitlab/scripts/sanitize/san-pmreboots.py names the tests whose REBOOT fail action MaxReboots=0 blocked):

  $ $C "logread" < /dev/null > "$A"/logread-prereboot.txt; echo collected
  collected
  $ $C "ba-cli --json 'ProcessMonitor.Test.?'" < /dev/null > "$A"/pm-tests-prereboot.json; echo collected
  collected
  $ cat > "$CRAMTMP/san-broadcast.sh" <<'X'
  > # SIGRTMIN+3 (37) leak check + memory profile + stats to EVERY process with the sanitizer shim
  > # mapped. The loop driver runs this test once per [full] iteration.
  > # Skipped: this shell and its children; a process whose SigCgt has no bit for signal 37
  > # (bit 36, zero based): it reset 37 to SIG_DFL after the shim started and would be killed.
  > me=$$
  > sig=0; s_self=0; s_cgt=0; s_gone=0; s_fail=0; total=0
  > is_mine() {
  >   p=$1; i=0
  >   while [ -n "$p" ] && [ "$p" -gt 1 ] && [ "$i" -lt 64 ]; do
  >     [ "$p" = "$me" ] && return 0
  >     p=$(awk '/^PPid:/ {print $2}' /proc/"$p"/status 2>/dev/null)
  >     i=$((i + 1))
  >   done
  >   return 1
  > }
  > for m in $(grep -l sanitizer-shim /proc/[0-9]*/maps 2>/dev/null); do
  >   pid=${m#/proc/}; pid=${pid%/maps}
  >   name=$(awk '/^Name:/ {print $2}' /proc/"$pid"/status 2>/dev/null)
  >   cgt=$(awk '/^SigCgt:/ {print $2}' /proc/"$pid"/status 2>/dev/null)
  >   total=$((total + 1))
  >   if [ -z "$cgt" ]; then s_gone=$((s_gone + 1)); echo "skip $pid $name: gone (no status)"; continue; fi
  >   if is_mine "$pid"; then s_self=$((s_self + 1)); echo "skip $pid $name: broadcast shell or child"; continue; fi
  >   hi=${cgt%?????????}; d=${hi#"${hi%?}"}
  >   case $d in
  >     [13579bBdDfF]) ;;
  >     *) s_cgt=$((s_cgt + 1)); echo "skip $pid $name: SigCgt=$cgt has no bit for signal 37"; continue ;;
  >   esac
  >   if kill -37 "$pid" 2>/dev/null; then sig=$((sig + 1)); echo "signalled $pid $name"
  >   else s_fail=$((s_fail + 1)); echo "skip $pid $name: kill failed (gone)"; fi
  > done
  > skipped=$((s_self + s_cgt + s_gone + s_fail))
  > line="san-broadcast: signalled=$sig skipped=$skipped (self=$s_self sigcgt-clear=$s_cgt gone=$s_gone kill-failed=$s_fail) shim-processes=$total"
  > echo "$line"
  > logger -t san-broadcast "$line"
  > { echo "$line" > /dev/console; } 2>/dev/null
  > # Give the leak checks time: 30 s, 60 s when many processes were signalled.
  > if [ "$sig" -gt 20 ]; then sleep 60; else sleep 30; fi
  > echo "san-broadcast: waited, done"
  > X
  $ $C "cat > /tmp/san-broadcast.sh" < "$CRAMTMP/san-broadcast.sh"
  $ $C "sh /tmp/san-broadcast.sh" < /dev/null > "$A"/san-broadcast.txt; echo rc=$?
  rc=0
  $ grep -E '^san-broadcast: (signalled|waited)' "$A"/san-broadcast.txt
  san-broadcast: signalled=[0-9]+ skipped=[0-9]+ .* (re)
  san-broadcast: waited, done
  $ $C "for s in /proc/[0-9]*/status; do awk '/^Name|^Pid|^VmRSS/ {printf \"%s \", \$2} END {print \"\"}' \$s; done 2>/dev/null" < /dev/null > "$A"/proc-rss-prereboot.txt; echo collected
  collected
