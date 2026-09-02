

Disable BGP instance test:

Verify that BGP sessions drop and all BGP-learned routes are removed when BGP instance is disabled.

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Enable BGP on CPE. Verify Device.Routing.X_PRPLWARE-COM_BGP.Enable = true.

  $ R "ba-cli Device.Routing.X_PRPLWARE-COM_BGP.Enable=true" | grep -Ev '^(>|$)' | grep '='
  Device.Routing.X_PRPLWARE-COM_BGP.Enable=1

Start BGP Server with configuration on isp-bgpd.

  $ sudo cp ${TESTDIR}/conf/routing/bgp_ipv4.frr.conf /etc/frr/frr.conf 2>&1 | grep -v "unable to resolve host"
  [1]
  $ sudo /usr/lib/frr/frrinit.sh start > /dev/null 2>&1

Configure CPE.

  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.+{Alias=\"cram-config1\",AS=\"65000\"}'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.RouterID=1.1.1.1'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.MaxPrefixes=5000'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Timers.ConnectRetryInterval=120'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Timers.HoldTime=90'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Timers.KeepAlive=30'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.+{Alias=\"cram-nb1\"}'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.RemoteAddress=192.168.1.2'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.RemoteAS=65001'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.AFISAFI.+{Alias=\"cram-afisafi1\",Type=\"IPv4Unicast\"}'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.AFISAFI.cram-afisafi1.Enable=true'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.ApplyFilters.DefaultImportDisposition=AcceptRoute'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.Enable=true'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Enable=true'" > /dev/null 2>&1

Add example route 198.51.100.0 to test route sharing using BGP.

  $ sudo ip route add blackhole 198.51.100.0/24 2>&1 | cat > /dev/null; true

Verify eBGP session is established.

  $ . ${TESTDIR}/script_functions_routing.sh
  $ wait_bgp_session cram-config1 cram-nb1 Established

Refresh routes in DM.

  $ sleep 1

  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.RefreshRoutes()'" | grep -Ev '^(>|$)'
  Device.Routing.X_PRPLWARE-COM_BGP.RefreshRoutes() returned
  [
      {
          Status = "Success"
      }
  ]

Verify BGP-learned routes present in CPE BGP RIB.

  $ R "ba-cli Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.RIB.IPv4.Route.[Prefix==\'198.51.100.0\/24\'].NextHop?" | grep -Ev '^(>|$)' | grep '='
  Device.Routing.X_PRPLWARE-COM_BGP.Config.\d+.RIB.IPv4.Route.\d+.NextHop="192.168.1.2" (re)

Verify that TCP session on port 179 is present.

  $ R "netstat -an | grep 192.168.1.1:179 | grep -q ESTABLISHED"

Disable BGP instance on CPE.

  $ R "ba-cli Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Enable=false" | grep -Ev '^(>|$)' | grep '='
  Device.Routing.X_PRPLWARE-COM_BGP.Config.\d+.Enable=0 (re)

Verify BGP instance Status is not Enabled and not Error got immediately after
disabling.

  $ R "ba-cli Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Status?" | grep -Ev '^(>|$)' | grep '='
  Device.Routing.X_PRPLWARE-COM_BGP.Config.\d+.Status="Disabled" (re)

Verify BGP session is no longer Established.

  $ R "ba-cli Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.SessionState?" | grep -Ev '^(>|$)' | grep '='
  Device.Routing.X_PRPLWARE-COM_BGP.Config.\d+.Neighbor.\d+.SessionState="Idle" (re)

Verify TCP session on port 179 is terminated.

  $ R "netstat -an | grep 192.168.1.1:179 | grep -v TIME_WAIT"
  [1]

Refresh routes in DM.

  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.RefreshRoutes()'" | grep -Ev '^(>|$)'
  Device.Routing.X_PRPLWARE-COM_BGP.RefreshRoutes() returned
  [
      {
          Status = "Success"
      }
  ]

Verify BGP-learned routes removed from CPE BGP RIB.

  $ R "ba-cli Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.RIB.IPv4.Route.* get instances" | grep -Ev '^(>|$)'
  [1]

Remove the instances and route created by this test.

  $ sudo ip route del blackhole 198.51.100.0/24 2>&1 | cat > /dev/null; true

Remove the instances created by this test.

  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.[Alias==\"cram-config1\"].-'" > /dev/null

Stop the FRR daemon on the BGP server.

  $ sudo /usr/lib/frr/frrinit.sh stop > /dev/null 2>&1
