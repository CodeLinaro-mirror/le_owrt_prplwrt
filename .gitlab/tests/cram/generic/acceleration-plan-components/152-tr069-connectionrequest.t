Define R() for access to DUT

  $ R() { ${CRAM_REMOTE_COMMAND:-} "$@"; }

Define G() hop via DUT -> GW

  $ G() {  ssh -y root@192.168.1.1 "$@"; }

Skip the test because it uses a reboot command and requires long delays in some of the steps:

  $ exit 80

AllowReservedAddr on Gataway:

  $ G 'ba-cli "Device.UPnP.X_PRPLWARE-COM_IGDConfig.AllowReservedAddr=1" | sed -e "/^> /d"' 2>/dev/null
  Device.UPnP.X_PRPLWARE-COM_IGDConfig.
  Device.UPnP.X_PRPLWARE-COM_IGDConfig.AllowReservedAddr=1
  
Switch to IPv4 mode

  $ R 'ba-cli "ManagementServer.URL=\"http://192.168.77.161:50555/\""' >/dev/null 2>&1

Restart tr069-connectionrequest 

  $ R 'service tr069-connectionrequest stop' 2>/dev/null
  $ sleep 5
  $ R 'service tr069-connectionrequest start' 2>/dev/null
  $ sleep 30

Check that tr069-connectionrequest is enabled and running by default:

  $ R 'ps ax | grep -q [t]r069-connectionrequest && echo OK || echo FAIL'
  OK

Check that port mapping is enabled on the GW:
  $ CONNREQ_PORT=$(R 'ba-cli "ManagementServer.ConnRequest._get()"' 2>/dev/null | sed -n 's/.*ConnRequestPort = \([0-9]\+\),/\1/p')
  $ G "ba-cli 'Device.NAT.PortMapping.[InternalClient==\"$TARGET_LAN_IP\" && InternalPort==$CONNREQ_PORT].Status?'"  2>/dev/null | grep -F Enable >/dev/null && echo OK || echo FAIL
  OK

Check that ConnectionRequestURL was set correctly:

  $ ORIG_WAN_IP=$(G 'ba-cli -l "Device.IP.Interface.wan.IPv4Address.1.IPAddress?"')
  $ R 'ba-cli "ManagementServer.ConnectionRequestURL?" | sed -e "/^> /d" | grep -F "http://$ORIG_WAN_IP" >/dev/null && echo OK || echo FAIL' 
  OK

Wait at least 300 seconds to check PortMapping keepalive:

  $ sleep 300

Check that port mapping still on the GW after 300 sec.:

  $ CONNREQ_PORT=$(R 'ba-cli "ManagementServer.ConnRequest._get()"' 2>/dev/null | sed -n 's/.*ConnRequestPort = \([0-9]\+\),/\1/p')
  $ G "ba-cli 'Device.NAT.PortMapping.[InternalClient==\"$TARGET_LAN_IP\" && InternalPort==$CONNREQ_PORT].Status?'"  2>/dev/null | grep -F Enable >/dev/null && echo OK || echo FAIL
  OK

Check that ConnectionRequestURL still correctly after 300 sec:

  $ ORIG_WAN_IP=$(G 'ba-cli -l "Device.IP.Interface.wan.IPv4Address.1.IPAddress?"')
  $ R 'ba-cli "ManagementServer.ConnectionRequestURL?" | sed -e "/^> /d" | grep -F "http://$ORIG_WAN_IP" >/dev/null && echo OK || echo FAIL' 
  OK

Check that service subscribed to IGD changes:

  $ NEW_WAN_IP=91.90.40.100
  $ G ba-cli "'IP.Interface.wan.IPv4Address.1._set\(parameters=\{IPAddress=\"$NEW_WAN_IP\"\}\)'" >/dev/null 2>&1
  $ sleep 3

Check that ConnectionRequestURL contain new WAN IP:

  $ R 'ba-cli "ManagementServer.ConnectionRequestURL?" | sed -e "/^> /d" | grep -F "http://$NEW_WAN_IP" >/dev/null && echo OK || echo FAIL' 
  OK

Return original WAN IP back:

  $ G ba-cli "'IP.Interface.wan.IPv4Address.1._set\(parameters=\{IPAddress=\"$ORIG_WAN_IP\"\}\)'" >/dev/null 2>&1

Check GW device has rebooted

  $ G 'reboot' 2>/dev/null
  $ sleep 120

Check that port mapping is enabled on the GW after GW reboot:

  $ CONNREQ_PORT=$(R 'ba-cli "ManagementServer.ConnRequest._get()"' 2>/dev/null | sed -n 's/.*ConnRequestPort = \([0-9]\+\),/\1/p')
  $ G "ba-cli 'Device.NAT.PortMapping.[InternalClient==\"$TARGET_LAN_IP\" && InternalPort==$CONNREQ_PORT].Status?'"  2>/dev/null | grep -F Enable >/dev/null && echo OK || echo FAIL
  OK

Check that ConnectionRequestURL was set correctly after GW reboot:

  $ ORIG_WAN_IP=$(G 'ba-cli -l "Device.IP.Interface.wan.IPv4Address.1.IPAddress?"')
  $ R 'ba-cli "ManagementServer.ConnectionRequestURL?" | sed -e "/^> /d" | grep -F "http://$ORIG_WAN_IP" >/dev/null && echo OK || echo FAIL' 
  OK

Check when IGD service on GW has stopped:

  $ G 'service tr181-upnp stop' 2>/dev/null
  $ sleep 10

Check that ConnectionRequestURL is FAIL after stop tr181-upnp:

  $ ORIG_WAN_IP=$(G 'ba-cli -l "Device.IP.Interface.wan.IPv4Address.1.IPAddress?"')
  $ R 'ba-cli "ManagementServer.ConnectionRequestURL?" | sed -e "/^> /d" | grep -F "http://$ORIG_WAN_IP" >/dev/null && echo OK || echo FAIL' 
  FAIL

Check when IGD service on GW has started:

  $ G 'service tr181-upnp start' 2>/dev/null
  $ sleep 10

Check that ConnectionRequestURL is OK after start tr181-upnp:

  $ ORIG_WAN_IP=$(G 'ba-cli -l "Device.IP.Interface.wan.IPv4Address.1.IPAddress?"')
  $ R 'ba-cli "ManagementServer.ConnectionRequestURL?" | sed -e "/^> /d" | grep -F "http://$ORIG_WAN_IP" >/dev/null && echo OK || echo FAIL' 
  OK
