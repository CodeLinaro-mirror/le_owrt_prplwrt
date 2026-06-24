Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Run the tests only on OSPv2 board with display capability:

  $ [ "$DUT_BOARD" = "mxl25641-hdk-6" ] || exit 80
  $ R "[ -e /etc/init.d/tr181-display ]" || exit 80

Check current path of running application:

  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp1.? | grep Path="
  Device.Hardware.Display.Session.*.Path="" (glob)

Rename wayland socket path of a running application:

  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp1.Path=file:///run/cramtestapp1_renamed | grep -v \>"
  Device.Hardware.Display.Session.*. (glob)
  Device.Hardware.Display.Session.*.Path="file:///run/cramtestapp1_renamed" (glob)

Wait for activation
  $ sleep 5

Check wayland socket exists:
  $ R "[ -e /run/cramtestapp1_renamed ]"

Check current path of running application after changing it:

  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp1.? | grep Path="
  Device.Hardware.Display.Session.*.Path="file:///run/cramtestapp1_renamed" (glob)

Rename back:

  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp1.Path=file:///run/cramtestapp1 | grep -v \>"
  Device.Hardware.Display.Session.*. (glob)
  Device.Hardware.Display.Session.*.Path="file:///run/cramtestapp1" (glob)

Wait for activation
  $ sleep 5

Check wayland socket exists:
  $ R "[ -e /run/cramtestapp1 ]"

Check current path of running application after changing it:

  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp1.? | grep Path="
  Device.Hardware.Display.Session.*.Path="file:///run/cramtestapp1" (glob)
