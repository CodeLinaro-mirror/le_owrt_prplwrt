Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Assure no unlimited core file shell resource limits:

  $ R " \
  > for file in \$(find /proc -type f -maxdepth 2 -name cmdline 2>/dev/null); do \
  >   dir=\$(dirname \$file); grep -q -s 'core.*size[[:space:]]*unlimited' \"\$dir/limits\" && \
  >   echo \"ERROR: unlimited core size detected: \$(cat \$file | tr '\0' ' ')\";
  > done \
  > " | grep -v -e netifd -e udhcpc -e wait_for
  [1]
