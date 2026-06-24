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

Update app socket:

  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp1.Path=file:///run/cramtestapp1 | grep -v \>"
  Device.Hardware.Display.Session.*. (glob)
  Device.Hardware.Display.Session.*.Path="file:///run/cramtestapp1" (glob)

Add second application:

  $ R "ba-cli Device.Hardware.Display.Session.+{Alias=CramTestApp2,Path=file:///run/cramtestapp2} | grep -v \>"
  Device.Hardware.Display.Session.*. (glob)
  Device.Hardware.Display.Session.*.Alias="CramTestApp2" (glob)

Update ZIndex of first session
  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp1.ZIndex=90 | grep ZIndex | grep -v \>"
  Device.Hardware.Display.Session.*.ZIndex=90 (glob)

Activate first application:

  $ R "/tmp/tr181-display-app1 start"

Wait for activation (and allow user to visually check)

  $ sleep 5

Check first session is now active:

  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp1.Status?"
  
  Visible

Check second session is still inactive :
  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp2.Status?"
  
  Inactive

Activate second application:
  $ R "/tmp/tr181-display-app2 start"

Wait for switch (and allow user to visually check)

  $ sleep 2

Check first session is now visible:

  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp1.Status?"
  
  Visible

Check second session is now active (but not visible):
  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp2.Status?"
  
  Active

Update ZIndex of second session
  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp2.ZIndex=91 | grep ZIndex | grep -v \>"
  Device.Hardware.Display.Session.*.ZIndex=91 (glob)

Wait for switch (and allow user to visually check)

  $ sleep 5

Check second application is now visible:

  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp2.Status?"
  
  Visible

Check first application is now active (but not visible):
  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp1.Status?"
  
  Active

Hide the second application:

  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp2.Hidden=1 | grep Hidden | grep -v \>"
  Device.Hardware.Display.Session.*.Hidden=1 (glob)

  $ sleep 2

Check second application is now active:

  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp2.Status?"
  
  Active

Check first application is now visible:
  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp1.Status?"
  
  Visible

Reshow the second application

  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp2.Hidden=0 | grep Hidden | grep -v \>"
  Device.Hardware.Display.Session.*.Hidden=0 (glob)

  $ sleep 2

Check second application is now visible again:

  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp2.Status?"
  
  Visible

Check first application is now active (but not visible):
  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp1.Status?"
  
  Active

Give application 1 exclusive access

  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp1.ExclusiveAccess=1 | grep ExclusiveAccess | grep -v \>"
  Device.Hardware.Display.Session.*.ExclusiveAccess=1 (glob)

  $ sleep 2

Check second application is now active:

  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp2.Status?"
  
  Active

Check first application is now visible:
  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp1.Status?"
  
  Visible

Deactivate application 1 exclusive access

  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp1.ExclusiveAccess=0 | grep ExclusiveAccess | grep -v \>"
  Device.Hardware.Display.Session.*.ExclusiveAccess=0 (glob)

  $ sleep 2

Check second application is now visible again:

  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp2.Status?"
  
  Visible

Check first application is now active (but not visible):
  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp1.Status?"
  
  Active

Deactivate app2:

  $ R "/tmp/tr181-display-app2 stop"

Check first is now visible:

  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp1.Status?"
  
  Visible

Deactivate app1:

  $ R "/tmp/tr181-display-app1 stop"

  $ sleep 2

  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp1.Status?"
  
  Inactive

  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp2.Status?"
  
  Inactive

Remove applications:

  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp2.- | grep -v \>"
  Device.Hardware.Display.Session.*. (glob)
  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp1.- | grep -v \>"
  Device.Hardware.Display.Session.*. (glob)

Remove temporary service executables:

  $ R "rm -r /tmp/tr181-display-app*"
