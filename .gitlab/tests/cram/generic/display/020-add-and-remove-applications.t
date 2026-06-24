Create R+C alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"

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

Check the path is a symlink to the underlying wayland socket:
  $ R "[ -L /run/cramtestapp1 ]"
  $ SOCKET1=$(R "readlink /run/cramtestapp1")
  $ echo "$SOCKET1"
  /*/wayland-* (glob)

Check the underlying wayland socket is readable/writable by root only:
  $ R "stat -c '%A %U:%G' $SOCKET1"
  srw------- root:root

Copy the test clients that connect as a non-root user and directly to the underlying socket:

  $ C $TESTDIR/utilities/tr181-display-app-nobody root@${TARGET_LAN_IP}:/tmp/tr181-display-app-nobody
  $ C $TESTDIR/utilities/tr181-display-app-direct root@${TARGET_LAN_IP}:/tmp/tr181-display-app-direct
  $ R "chmod +x /tmp/tr181-display-app-nobody /tmp/tr181-display-app-direct"
  $ R "echo $SOCKET1 > /tmp/cramtest-socket1"

A client running as the nobody user cannot connect to the root-only socket:

  $ MARK_NOBODY="cramtest-display-nobody-$(date +%s)"
  $ R "logger -t cramtest $MARK_NOBODY"
  $ R "/tmp/tr181-display-app-nobody start"

Wait up to 10 seconds for the client to connect (a refused client keeps running, so a refusal takes the full 10 seconds):

  $ R "for i in \$(seq 1 20); do logread | sed -n '/$MARK_NOBODY/,\$p' | grep -q 'Client connected via listener: $SOCKET1\$' && break; sleep 0.5; done"

  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp1.Status?"
  
  Inactive

  $ R "logread | sed -n '/$MARK_NOBODY/,\$p' | grep -c 'Client connected via listener: $SOCKET1\$' || true"
  0

  $ R "/tmp/tr181-display-app-nobody stop"

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
  $ R "[ ! -L /run/cramtestapp1 ]"

Check the underlying wayland socket still exists but is not readable/writable:
  $ R "[ -S $SOCKET1 ]"
  $ R "stat -c %A $SOCKET1"
  s---------

Check application is now disabled:

  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp1.Status?"
  
  Disabled

A new client connecting directly to the underlying socket of the disabled session is refused:

  $ MARK_DISABLED="cramtest-display-disabled-$(date +%s)"
  $ R "logger -t cramtest $MARK_DISABLED"
  $ R "/tmp/tr181-display-app-direct start"

Wait up to 10 seconds for the client to connect (a refused client keeps running, so a refusal takes the full 10 seconds):

  $ R "for i in \$(seq 1 20); do logread | sed -n '/$MARK_DISABLED/,\$p' | grep -q 'Client connected via listener: $SOCKET1\$' && break; sleep 0.5; done"

  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp1.Status?"
  
  Disabled

  $ R "logread | sed -n '/$MARK_DISABLED/,\$p' | grep -c 'Client connected via listener: $SOCKET1\$' || true"
  0

  $ R "/tmp/tr181-display-app-direct stop"
  $ R "for i in \$(seq 1 20); do grep -qs 'CRAM TEST DIRECT' /proc/[0-9]*/environ || break; sleep 0.5; done"

Enable the session

  $ R "ba-cli Device.Hardware.Display.Session.CramTestApp1.Enable=1 | grep Enable | grep -v \>"
  Device.Hardware.Display.Session.*.Enable=1 (glob)

  $ sleep 2

Check wayland socket exists:
  $ R "[ -e /run/cramtestapp1 ]"

Check the path is a symlink to the same underlying wayland socket:
  $ R "readlink /run/cramtestapp1" | grep -qxF "$SOCKET1"

Check the underlying wayland socket is readable/writable again:
  $ R "stat -c %A $SOCKET1"
  srw-------

Check application is now inactive:

  $ R "ba-cli -l Device.Hardware.Display.Session.CramTestApp1.Status?"
  
  Inactive

Check session persistence over a tr181-display service restart, and that the plugin logs its start to syslog:

  $ MARK_RESTART="cramtest-display-restart-$(date +%s)"
  $ R "logger -t cramtest $MARK_RESTART"
  $ R "/etc/init.d/tr181-display restart"

Wait up to 30 seconds for the new plugin process to start and register its data model:

  $ R "for i in \$(seq 1 60); do logread | sed -n '/$MARK_RESTART/,\$p' | grep -q 'Starting tr181-display plugin' && break; sleep 0.5; done"
  $ R "amx_poll_object ubus Display. 30"

  $ R "logread | sed -n '/$MARK_RESTART/,\$p' | grep -c 'Starting tr181-display plugin' || true"
  1

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

Remove the temporary test clients:

  $ R "rm -f /tmp/tr181-display-app-nobody /tmp/tr181-display-app-direct /tmp/cramtest-socket1"
