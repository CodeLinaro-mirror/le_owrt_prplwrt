Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Run the tests only on OSPv2 board with display capability:

  $ [ "$DUT_BOARD" = "mxl25641-hdk-6" ] || exit 80
  $ R "[ -e /etc/init.d/tr181-display ]" || exit 80

Remove any existing Cram test apps:

  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp1.-"
  * (glob)
  * (glob)
  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp2.-"
  * (glob)
  * (glob)
