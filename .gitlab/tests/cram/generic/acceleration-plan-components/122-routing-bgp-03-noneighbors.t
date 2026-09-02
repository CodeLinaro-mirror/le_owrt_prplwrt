
BGP is not created on failure test:

Verify that BGP does not automatically discover neighbors - peers must be
explicitly configured via TR-181 data model before any session can be
established. BGP instances can not be created if no BGP Neighbors are set.

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Enable BGP on CPE. Verify Device.Routing.X_PRPLWARE-COM_BGP.Enable = true.

  $ R "ba-cli Device.Routing.X_PRPLWARE-COM_BGP.Enable=true" | grep -Ev '^(>|$)' | grep '='
  Device.Routing.X_PRPLWARE-COM_BGP.Enable=1

Start BGP Server with configuration on isp-bgpd.

  $ sudo cp ${TESTDIR}/conf/routing/bgp_ipv4.frr.conf /etc/frr/frr.conf 2>&1 | grep -v "unable to resolve host"
  [1]
  $ sudo /usr/lib/frr/frrinit.sh start > /dev/null 2>&1

Configure CPE BGP instance with no neighbors.

  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.+{Alias=\"cram-config1\",AS=\"65000\"}'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.RouterID=1.1.1.1'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.MaxPrefixes=5000'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Timers.ConnectRetryInterval=120'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Timers.HoldTime=90'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Timers.KeepAlive=30'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Enable=true'" > /dev/null 2>&1

Verify status is Error with clear StatusMessage

  $ R "ba-cli Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Status?" | grep -Ev '^(>|$)' | grep '='
  Device.Routing.X_PRPLWARE-COM_BGP.Config.\d+.Status="Error_Misconfigured" (re)
  $ R "ba-cli Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.StatusMessage?" | grep -Ev '^(>|$)' | grep '='
  Device.Routing.X_PRPLWARE-COM_BGP.Config.\d+.StatusMessage="No enabled neighbors found" (re)

Configure eBGP neighbor explicitly.

  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.+{Alias=\"cram-nb1\"}'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.RemoteAddress=192.168.1.2'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.RemoteAS=65001'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.AFISAFI.+{Alias=\"cram-afisafi1\"}'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.AFISAFI.cram-afisafi1.Type=IPv4Unicast'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.AFISAFI.cram-afisafi1.Enable=true'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.Enable=true'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Enable=true'" > /dev/null 2>&1

Verify only one neighbor is configured on CPE.

  $ R "ba-cli Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.NeighborNumberOfEntries?" | grep -Ev '^(>|$)' | grep '='
  Device.Routing.X_PRPLWARE-COM_BGP.Config.\d+.NeighborNumberOfEntries=1 (re)

Verify Neighbor.1 session is Established.

  $ . ${TESTDIR}/script_functions_routing.sh
  $ wait_bgp_session cram-config1 cram-nb1 Established

Remove the instances created by this test.

  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.[Alias==\"cram-config1\"].-'" > /dev/null

Stop the FRR daemon on the BGP server.

  $ sudo /usr/lib/frr/frrinit.sh stop > /dev/null 2>&1
