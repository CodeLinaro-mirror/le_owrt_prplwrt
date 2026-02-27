Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Run the test only on OSPv2 and Freedom boards (FEAT-29):

  $ [ "$DUT_BOARD" = "mxl25641-hdk-6" ] || [ "$DUT_BOARD" = "wnc-freedom" ] || exit 80

Read bootcount register:

  $ R "cat /sys/class/registers/bootcount"
  0

Write bootcount register:

  $ R "echo 2 > /sys/class/registers/bootcount"
  $ R "cat /sys/class/registers/bootcount"
  2

Reset bootcount to 0:

  $ R "echo 0 > /sys/class/registers/bootcount"
