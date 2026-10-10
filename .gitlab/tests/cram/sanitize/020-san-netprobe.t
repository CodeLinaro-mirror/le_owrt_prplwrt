Sanitizer job only (cram QEMU x86-64 [sanitize]): network probe (SSH/HTTP reachability during the loop). The loop driver runs it in the first
iteration only.
Starts a DUT-side logger: every 20 s for 15 min it writes the INPUT chains, the listening sockets,
dropbear/lighttpd pids and Firewall.Service to /ext/sanitizer/san-net-probe.log and to
/dev/console (prefix SANNET), so the state is kept even if SSH dies.

  $ C=$(echo "$CRAM_REMOTE_COMMAND" | sed 's/^ssh -n /ssh /')
  $ cat > "$CRAMTMP/san-netprobe.sh" <<'X'
  > echo -1000 > /proc/self/oom_score_adj
  > L=/ext/sanitizer/san-net-probe.log
  > T=/tmp/san-netprobe.txt
  > i=0
  > while [ $i -lt 45 ]; do
  >   i=$((i + 1))
  >   {
  >     echo "# probe $i $(date -u '+%Y-%m-%dT%H:%M:%SZ') up=$(cut -d' ' -f1 /proc/uptime)"
  >     iptables -S INPUT 2>&1
  >     iptables -S INPUT_Services 2>&1
  >     netstat -ltn 2>&1
  >     echo "dropbear: $(pidof dropbear) lighttpd: $(pidof lighttpd)"
  >     ba-cli -l 'Firewall.Service.?' 2>&1 | head -60
  >   } > $T 2>&1
  >   cat $T >> $L
  >   sed 's/^/SANNET /' $T > /dev/console
  >   sleep 20
  > done
  > X
  $ $C "cat > /tmp/san-netprobe.sh; (sh /tmp/san-netprobe.sh </dev/null >/dev/null 2>&1 &); sleep 2; test -s /ext/sanitizer/san-net-probe.log && echo started" < "$CRAMTMP/san-netprobe.sh"
  started
