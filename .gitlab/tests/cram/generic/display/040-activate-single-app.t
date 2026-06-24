Create R+C alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"

Run the tests only on OSPv2 board with display capability:

  $ [ "$DUT_BOARD" = "mxl25641-hdk-6" ] || exit 80
  $ R "[ -e /etc/init.d/tr181-display ]" || exit 80

Add display service:

  $ C $TESTDIR/utilities/tr181-display-app1 root@${TARGET_LAN_IP}:/tmp/tr181-display-app1 2>/dev/null
  $ R "chmod +x /tmp/tr181-display-app1"

Check application is not currently active:

  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp1.Status?"
  
  Inactive

Activate the application:

  $ R "/tmp/tr181-display-app1 start"

Wait for activation (and allow user to visually check)

  $ sleep 5

Check application is now visible:

  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp1.Status?"
  
  Visible

Hide the application

  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp1.Hidden=1 | grep Hidden | grep -v \>"
  Device.Hardware.Display.Session.*.Hidden=1 (glob)

  $ sleep 2

Check application is now active:

  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp1.Status?"
  
  Active

Show the application

  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp1.Hidden=0 | grep Hidden | grep -v \>"
  Device.Hardware.Display.Session.*.Hidden=0 (glob)

  $ sleep 2

Check application is now visible:

  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp1.Status?"
  
  Visible

Deactivate the app and check active value again:
  $ R "/tmp/tr181-display-app1 stop"
  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp1.Status?"
  
  Inactive

Remove temporary service executables:

  $ R "rm -r /tmp/tr181-display-app*"
