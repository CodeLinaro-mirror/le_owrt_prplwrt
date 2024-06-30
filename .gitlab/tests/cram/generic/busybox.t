Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Assure that sysntpd is not running:

  $ R "pgrep -ax ntpd"
  [1]
