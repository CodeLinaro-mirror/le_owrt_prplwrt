Sanitizer job collector (post test, run by the loop driver after every iteration): sanitizer reports, logread and
per-process RSS into the artifacts dir.
The leak-check broadcast is not here: it runs before the reboot test in
sanitize/010-san-broadcast.t, so it covers the whole [full] iteration (this post test runs after
qemu-x86-64/reboot.t, in the next boot).

  $ C=$(echo "$CRAM_REMOTE_COMMAND" | sed 's/^ssh -n /ssh /')
  $ A=${TESTBED_QEMU_ARTIFACT_ROOT:-/artifacts}; test -d "$A" || A=/tmp
  $ $C "if test -d /ext/sanitizer && test -n \"\$(ls -A /ext/sanitizer 2>/dev/null)\"; then echo 'report dir ok'; else echo 'report dir MISSING or empty'; fi" < /dev/null
  report dir ok
  $ $C "cat /ext/sanitizer/san-rss.log" < /dev/null > "$A"/san-rss.log; echo collected
  collected
  $ $C "tar -czf - -C / ext/sanitizer 2>/dev/null" < /dev/null > "$A"/sanitizer-reports.tar.gz; echo collected
  collected
  $ $C "logread" < /dev/null > "$A"/logread-full.txt; echo collected
  collected
  $ $C "for s in /proc/[0-9]*/status; do awk '/^Name|^Pid|^VmRSS/ {printf \"%s \", \$2} END {print \"\"}' \$s; done 2>/dev/null" < /dev/null > "$A"/proc-rss.txt; echo collected
  collected
