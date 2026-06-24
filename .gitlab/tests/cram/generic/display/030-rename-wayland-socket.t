Note: This test assumes running after 020-add-and-remove-applications.t
Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Run the tests only on OSPv2 board with display capability:

  $ [ "$DUT_BOARD" = "mxl25641-hdk-6" ] || exit 80
  $ R "[ -e /etc/init.d/tr181-display ]" || exit 80

Check current path of running application:

  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp1.? | grep Path="
  Device.Hardware.Display.Session.*.Path="file:///run/cramtestapp1" (glob)

Rename wayland socket path of a running application:

  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp1.Path=file:///run/cramtestapp1_renamed | grep -v \>"
  Device.Hardware.Display.Session.*. (glob)
  Device.Hardware.Display.Session.*.Path="file:///run/cramtestapp1_renamed" (glob)

Wait for activation
  $ sleep 2

Check wayland socket exists with the new name:
  $ R "[ -e /run/cramtestapp1_renamed ]"

Check application is not currently active:

  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp1.Status?"
  
  Inactive

Check current path of running application after changing it:

  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp1.? | grep Path="
  Device.Hardware.Display.Session.*.Path="file:///run/cramtestapp1_renamed" (glob)

Set path to a directory that does not exist:

  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp1.Path=file:///cannot_exist/cramtestapp1 | grep -v \>"
  Device.Hardware.Display.Session.*. (glob)
  Device.Hardware.Display.Session.*.Path="file:///cannot_exist/cramtestapp1" (glob)

Wait for update
  $ sleep 2

Check wayland socket not longer exists with the previous name:
  $ R "[ ! -e /run/cramtestapp1_renamed ]"

Check application is in error state:

  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp1.Status?"
  
  Error

Rename back:

  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp1.Path=file:///run/cramtestapp1 | grep -v \>"
  Device.Hardware.Display.Session.*. (glob)
  Device.Hardware.Display.Session.*.Path="file:///run/cramtestapp1" (glob)

Wait for activation
  $ sleep 2

Check wayland socket exists and matches the original name:
  $ R "[ -e /run/cramtestapp1 ]"

Check application is not currently active:

  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp1.Status?"
  
  Inactive

Check current path of running application after changing it:

  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp1.? | grep Path="
  Device.Hardware.Display.Session.*.Path="file:///run/cramtestapp1" (glob)
