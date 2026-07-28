Create R+C alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"

Run the tests only on OSPv2 board with display capability:

  $ [ "$DUT_BOARD" = "mxl25641-hdk-6" ] || exit 80
  $ R "[ -e /etc/init.d/tr181-display ]" || exit 80

Add display service:

  $ C $TESTDIR/utilities/tr181-display-app1 root@${TARGET_LAN_IP}:/tmp/tr181-display-app1 2>/dev/null
  $ C $TESTDIR/utilities/tr181-display-app2 root@${TARGET_LAN_IP}:/tmp/tr181-display-app2 2>/dev/null
  $ R "chmod +x /tmp/tr181-display-app1"
  $ R "chmod +x /tmp/tr181-display-app2"

Add first application:
  $ R "ba-cli Device.Hardware.Display.Session.+{Alias=CramTestApp1,Path=file:///run/cramtestapp1} | grep -v \>"
  Device.Hardware.Display.Session.*. (glob)
  Device.Hardware.Display.Session.*.Alias="CramTestApp1" (glob)

Activate first application:

  $ R "/tmp/tr181-display-app1 start"

Wait for activation (and allow user to visually check)

  $ sleep 5

See if the DRI state is enabled

  $ R grep enable /sys/kernel/debug/dri/0/state
  \tenable=1 (esc)

Disable the screen

  $ R "ba-cli Device.Hardware.Display.Screen.1.Enable=0 | grep -v \>"
  Device.Hardware.Display.Screen.1.
  Device.Hardware.Display.Screen.1.Enable=0

See if the DRI state is disabled
  $ R grep enable /sys/kernel/debug/dri/0/state
  \tenable=0 (esc)

Enable the screen

  $ R "ba-cli Device.Hardware.Display.Screen.1.Enable=1 | grep -v \>"
  Device.Hardware.Display.Screen.1.
  Device.Hardware.Display.Screen.1.Enable=1

See if the DRI state is disabled
  $ R grep enable /sys/kernel/debug/dri/0/state
  \tenable=1 (esc)

Cleanup app1:

  $ R "/tmp/tr181-display-app1 stop"
  $ R "rm -r /tmp/tr181-display-app*"
  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp1.- | grep -v \>"
  Device.Hardware.Display.Session.*. (glob)