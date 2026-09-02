
Group of the test:
- Empty RouterID
- Establish eBGP ipv4 session

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Enable BGP on CPE. Verify Device.Routing.X_PRPLWARE-COM_BGP.Enable = true.

  $ R "ba-cli Device.Routing.X_PRPLWARE-COM_BGP.Enable=true" | grep -Ev '^(>|$)' | grep '='
  Device.Routing.X_PRPLWARE-COM_BGP.Enable=1

Start BGP Server with configuration on isp-bgpd.

  $ sudo cp ${TESTDIR}/conf/routing/bgp_ipv4.frr.conf /etc/frr/frr.conf 2>&1 | grep -v "unable to resolve host"
  [1]
  $ sudo /usr/lib/frr/frrinit.sh start > /dev/null 2>&1

*Empty RouterID and AS*

Verify that CPE set Status="Error_Misconfigured" when RouterID or AS are not explicitly configured.

Configure CPE without explicitly setting RouterID.

  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.+{Alias=\"cram-config1\"}'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.MaxPrefixes=5000'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Timers.ConnectRetryInterval=120'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Timers.HoldTime=90'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Timers.KeepAlive=30'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.+{Alias=\"cram-nb1\"}'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.RemoteAddress=192.168.1.2'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.RemoteAS=65001'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.AFISAFI.+{Alias=\"cram-afisafi1\",Type=\"IPv4Unicast\"}'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.AFISAFI.cram-afisafi1.Enable=true'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.ApplyFilters.DefaultExportDisposition=AcceptRoute'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.ApplyFilters.DefaultImportDisposition=AcceptRoute'" > /dev/null 2>&1  
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.Enable=true'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Enable=true'" > /dev/null 2>&1

Verify that Status="Error_Misconfigured".

  $ R ba-cli "Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Status?" | grep -Ev '^(>|$)' | grep '='
  Device.Routing.X_PRPLWARE-COM_BGP.Config.\d+.Status="Error_Misconfigured" (re)

*Establish eBGP ipv4 session*

Verify that a CPE device correctly establishes an eBGP ipv4 session with a
remote BGP Server.

Configure RouterID.

  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.RouterID=1.1.1.1'" > /dev/null 2>&1

Verify that Status="Error_Misconfigured" still (AS is '0')

  $ R ba-cli "Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Status?" | grep -Ev '^(>|$)' | grep '='
  Device.Routing.X_PRPLWARE-COM_BGP.Config.\d+.Status="Error_Misconfigured" (re)

Configure AS.

  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.AS=65000'" > /dev/null 2>&1

Verify that Status="Enabled".

  $ R ba-cli "Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Status?" | grep -Ev '^(>|$)' | grep '='
  Device.Routing.X_PRPLWARE-COM_BGP.Config.\d+.Status="Enabled" (re)

Verify bird2 process is running on CPE.

  $ R birdc show status | grep 'Daemon is up and running'
  Daemon is up and running

Verify eBGP session is established.

  $ . ${TESTDIR}/script_functions_routing.sh
  $ wait_bgp_session cram-config1 cram-nb1 Established

  $ R "ba-cli Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.LocalAddress?" | grep -Ev '^(>|$)' | grep '='
  Device.Routing.X_PRPLWARE-COM_BGP.Config.\d+.Neighbor.\d+.LocalAddress="192.168.1.1" (re)

  $ R "ba-cli Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.Identifier?" | grep -Ev '^(>|$)' | grep '='
  Device.Routing.X_PRPLWARE-COM_BGP.Config.\d+.Neighbor.\d+.Identifier="2.2.2.2" (re)

Remove the instances created by this test.

  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.[Alias==\"cram-config1\"].-'" > /dev/null

Stop the FRR daemon on the BGP server.

  $ sudo /usr/lib/frr/frrinit.sh stop > /dev/null 2>&1
