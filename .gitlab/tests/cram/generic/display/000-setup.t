Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Run the tests only on OSPv2 board with display capability:

  $ [ "$DUT_BOARD" = "mxl25641-hdk-6" ] || exit 80
  $ R "[ -e /etc/init.d/tr181-display ]" || exit 80

Remove any existing Cram test apps:

  $ R "ba-cli Device.Hardware.Display.Session.*.- >/dev/null && true"

Stop and remove test clients left over from an earlier run that did not finish:

  $ R "for c in nobody direct; do [ -x /tmp/tr181-display-app-\$c ] && /tmp/tr181-display-app-\$c stop; done; rm -f /tmp/tr181-display-app-nobody /tmp/tr181-display-app-direct /tmp/cramtest-socket1; true"
