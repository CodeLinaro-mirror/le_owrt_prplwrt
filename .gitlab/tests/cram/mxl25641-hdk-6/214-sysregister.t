Create R alias:
  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Read bootcount register:
  $ R "cat /sys/class/registers/bootcount"
  0

Write bootcount register:
  $ R "echo 2 > /sys/class/registers/bootcount"
  $ R "cat /sys/class/registers/bootcount"
  2

Reset bootcount to 0:
  $ R "echo 0 > /sys/class/registers/bootcount"
