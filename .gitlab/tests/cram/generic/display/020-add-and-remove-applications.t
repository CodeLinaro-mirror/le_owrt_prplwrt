Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Run the tests only on OSPv2 board with display capability:

  $ [ "$DUT_BOARD" = "mxl25641-hdk-6" ] || exit 80
  $ R "[ -e /etc/init.d/tr181-display ]" || exit 80

Add a new application:

  $ R "ba-cli Device.Hardware.Display.Session.+{Alias=CramTestApp1} | grep -v \>"
  Device.Hardware.Display.Session.*. (glob)
  Device.Hardware.Display.Session.*.Alias="CramTestApp1" (glob)

  $ R "ba-cli Device.Hardware.Display.Session.? | grep Alias"
  Device.Hardware.Display.Session.*.Alias="CramTestApp1" (glob)

Add a second new application:

  $ R "ba-cli Device.Hardware.Display.Session.+{Alias=CramTestApp2} | grep -v \>"
  Device.Hardware.Display.Session.*. (glob)
  Device.Hardware.Display.Session.*.Alias="CramTestApp2" (glob)

  $ R "ba-cli Device.Hardware.Display.Session.? | grep Alias"
  Device.Hardware.Display.Session.*.Alias="CramTestApp*" (glob)
  Device.Hardware.Display.Session.*.Alias="CramTestApp*" (glob)

Remove an application by Alias:

  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp2.- | grep -v \>"
  Device.Hardware.Display.Session.*. (glob)

  $ R "ba-cli Device.Hardware.Display.Session.? | grep Alias"
  Device.Hardware.Display.Session.*.Alias="CramTestApp1" (glob)
