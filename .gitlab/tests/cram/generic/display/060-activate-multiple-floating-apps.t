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

Update first session so it takes up top half of the screen
  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp1.{PosX=0,PosY=0,Width=320,Height=120} | grep -v \>"
  Device.Hardware.Display.Session.*. (glob)
  Device.Hardware.Display.Session.*.Height=120 (glob)
  Device.Hardware.Display.Session.*.PosX=0 (glob)
  Device.Hardware.Display.Session.*.PosY=0 (glob)
  Device.Hardware.Display.Session.*.Width=320 (glob)

Wait for adjustment (and allow user to visually check)

  $ sleep 2

Check first session is still visible:

  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp1.Status?"
  
  Visible

Check second session is now active (but not visible):
  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp2.Status?"
  
  Active

Update second session so it takes up bottom half of the screen

  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp2.{PosX=0,PosY=120,Width=320,Height=120} | grep -v \>"
  Device.Hardware.Display.Session.*. (glob)
  Device.Hardware.Display.Session.*.Height=120 (glob)
  Device.Hardware.Display.Session.*.PosX=0 (glob)
  Device.Hardware.Display.Session.*.PosY=120 (glob)
  Device.Hardware.Display.Session.*.Width=320 (glob)

Wait for adjustment (and allow user to visually check)

  $ sleep 2

Check first session is still visible:

  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp1.Status?"
  
  Visible

Check second session is also now visible:
  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp2.Status?"
  
  Visible

Update first session so it takes up left half of the screen

  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp1.{PosX=0,PosY=0,Width=160,Height=240} | grep -v \>"
  Device.Hardware.Display.Session.*. (glob)
  Device.Hardware.Display.Session.*.Height=240 (glob)
  Device.Hardware.Display.Session.*.PosX=0 (glob)
  Device.Hardware.Display.Session.*.PosY=0 (glob)
  Device.Hardware.Display.Session.*.Width=160 (glob)

Wait for adjustment (and allow user to visually check)

  $ sleep 2

Check first session is still visible:

  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp1.Status?"
  
  Visible

Check second session is now active (but not visible):
  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp2.Status?"
  
  Active

Update second session so it takes up right half of the screen via UpdateGeometry
  $ R "ba-cli 'Device.Hardware.Display.Session.CramTestApp2.UpdateGeometry(PosX=160,PosY=0,Width=160,Height=240)' | grep -v \>"
  Device.Hardware.Display.Session.CramTestApp2.UpdateGeometry() returned
  [
      ""
  ]

Wait for adjustment (and allow user to visually check)

  $ sleep 2

Check first session is still visible:

  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp1.Status?"
  
  Visible

Check second session is also now visible:
  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp2.Status?"
  
  Visible

Make first session full screen again:
  $ R "ba-cli 'Device.Hardware.Display.Session.CramTestApp1.UpdateGeometry(Fullscreen=true,Screen=Device.Hardware.Display.Screen.1)' | grep -v \>"
  Device.Hardware.Display.Session.CramTestApp1.UpdateGeometry() returned
  [
      ""
  ]

Wait for adjustment (and allow user to visually check)

  $ sleep 2

Check first session is still visible:

  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp1.Status?"
  
  Visible

Check second session is now active (but not visible):
  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp2.Status?"
  
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
