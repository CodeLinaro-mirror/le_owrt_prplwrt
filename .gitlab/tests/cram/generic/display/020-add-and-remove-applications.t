Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Run the tests only on OSPv2 board with display capability:

  $ [ "$DUT_BOARD" = "mxl25641-hdk-6" ] || exit 80
  $ R "[ -e /etc/init.d/tr181-display ]" || exit 80

Add a new application:

  $ R "ba-cli Device.Hardware.Display.Session.+{Alias=CramTestApp1,Path=file:///run/cramtestapp1} | grep -v \>"
  Device.Hardware.Display.Session.*. (glob)
  Device.Hardware.Display.Session.*.Alias="CramTestApp1" (glob)

  $ R "ba-cli Device.Hardware.Display.Session.*.? | grep -v \>"
  Device.Hardware.Display.Session.*. (glob)
  Device.Hardware.Display.Session.*.Alias="CramTestApp1" (glob)
  Device.Hardware.Display.Session.*.Enable=1 (glob)
  Device.Hardware.Display.Session.*.ExclusiveAccess=0 (glob)
  Device.Hardware.Display.Session.*.Hidden=0 (glob)
  Device.Hardware.Display.Session.*.Path="file:///run/cramtestapp1" (glob)
  Device.Hardware.Display.Session.*.Status="Inactive" (glob)
  Device.Hardware.Display.Session.*.ZIndex=0 (glob)

Check wayland socket exists:
  $ R "[ -e /run/cramtestapp1 ]"

Add a second new application with autoassigned Alias:

  $ R "ba-cli Device.Hardware.Display.Session.+{Path=file:///run/cramtestapp2, ZIndex=99, Enable=0, Hidden=1, ExclusiveAccess=1} | grep -v \>"
  Device.Hardware.Display.Session.*. (glob)
  Device.Hardware.Display.Session.*.Alias="cpe-*" (glob)

  $ ALIAS=$(R 'ba-cli -l "Device.Hardware.Display.Session.[ Path == \"file:///run/cramtestapp2\" ].Alias?"' | grep '[a-zA-Z].*' | head -1)

  $ sleep 2

  $ R "ba-cli Device.Hardware.Display.Session.${ALIAS}.? | grep -v \>"
  Device.Hardware.Display.Session.*. (glob)
  Device.Hardware.Display.Session.*.Alias="*" (glob)
  Device.Hardware.Display.Session.*.Enable=0 (glob)
  Device.Hardware.Display.Session.*.ExclusiveAccess=1 (glob)
  Device.Hardware.Display.Session.*.Hidden=1 (glob)
  Device.Hardware.Display.Session.*.Path="file:///run/cramtestapp2" (glob)
  Device.Hardware.Display.Session.*.Status="Disabled" (glob)
  Device.Hardware.Display.Session.*.ZIndex=99 (glob)

  $ R "ba-cli Device.Hardware.Display.Session.*.Alias? | grep -v \>"
  Device.Hardware.Display.Session.*.Alias="CramTestApp*" (glob)
  Device.Hardware.Display.Session.*.Alias="*" (glob)

Check wayland socket does not exist:
  $ R "[ ! -e /run/cramtestapp2 ]"

Disable the session

  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp1.Enable=0 | grep Enable | grep -v \>"
  Device.Hardware.Display.Session.*.Enable=0 (glob)

  $ sleep 2

Check wayland socket does not exist:
  $ R "[ ! -e /run/cramtestapp1 ]"

Check application is now disabled:

  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp1.Status?"
  
  Disabled

Enable the session

  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp1.Enable=1 | grep Enable | grep -v \>"
  Device.Hardware.Display.Session.*.Enable=1 (glob)

  $ sleep 2

Check wayland socket exists:
  $ R "[ -e /run/cramtestapp1 ]"

Check application is now disabled:

  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp1.Status?"
  
  Inactive

Check session persistence works:

  $ R "/etc/init.d/tr181-display restart"
  $ sleep 5

  $ R "ba-cli Device.Hardware.Display.Session.*.? | grep -v \>"
  Device.Hardware.Display.Session.*. (glob)
  Device.Hardware.Display.Session.*.Alias="CramTestApp1" (glob)
  Device.Hardware.Display.Session.*.Enable=1 (glob)
  Device.Hardware.Display.Session.*.ExclusiveAccess=0 (glob)
  Device.Hardware.Display.Session.*.Hidden=0 (glob)
  Device.Hardware.Display.Session.*.Path="file:///run/cramtestapp1" (glob)
  Device.Hardware.Display.Session.*.Status="Inactive" (glob)
  Device.Hardware.Display.Session.*.ZIndex=0 (glob)
  Device.Hardware.Display.Session.*. (glob)
  Device.Hardware.Display.Session.*.Alias="*" (glob)
  Device.Hardware.Display.Session.*.Enable=0 (glob)
  Device.Hardware.Display.Session.*.ExclusiveAccess=1 (glob)
  Device.Hardware.Display.Session.*.Hidden=1 (glob)
  Device.Hardware.Display.Session.*.Path="file:///run/cramtestapp2" (glob)
  Device.Hardware.Display.Session.*.Status="Disabled" (glob)
  Device.Hardware.Display.Session.*.ZIndex=99 (glob)

  $ R "ba-cli Device.Hardware.Display.Session.*.? | grep Alias"
  Device.Hardware.Display.Session.*.Alias="CramTestApp*" (glob)
  Device.Hardware.Display.Session.*.Alias="*" (glob)

Check wayland socket exists:
  $ R "[ -e /run/cramtestapp1 ]"
  $ R "[ ! -e /run/cramtestapp2 ]"

Reenable session 2
  $ R "ba-cli Device.Hardware.Display.Session.${ALIAS}.Enable=1 | grep Enable | grep -v \>"
  Device.Hardware.Display.Session.*.Enable=1 (glob)
  $ sleep 2

Check the wayland socket exists:
  $ R "[ -e /run/cramtestapp2 ]"

Remove the second application by Alias:

  $ R "ba-cli Device.Hardware.Display.Session.${ALIAS}.- | grep -v \>"
  Device.Hardware.Display.Session.*. (glob)

  $ R "ba-cli Device.Hardware.Display.Session.*.? | grep Alias"
  Device.Hardware.Display.Session.*.Alias="CramTestApp1" (glob)

Check the wayland socket is removed:
  $ R "[ ! -e /run/cramtestapp2 ]"