
Import policy --- match source protocol BGP test:

Verify that CPE import policy correctly matches routes based on source protocol
BGP condition and accepts only BGP-learned routes into the RIB. Routes from
other source protocols (static, OSPF) are not affected by this filter statement.

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Disable BGP and verify that BGP is not enabled on CPE.

  $ R "ba-cli Device.Routing.X_PRPLWARE-COM_BGP.Enable=false" > /dev/null 2>&1

  $ R "ba-cli Device.Routing.X_PRPLWARE-COM_BGP.Enable?" | grep -Ev '^(>|$)' | grep '='
  Device.Routing.X_PRPLWARE-COM_BGP.Enable=0

Verify system routing table has no BGP routes present.

  $ R "ip route show" | grep -E "198.51."
  [1]

Enable BGP on CPE. Verify Device.Routing.X_PRPLWARE-COM_BGP.Enable = true.

  $ R "ba-cli Device.Routing.X_PRPLWARE-COM_BGP.Enable=true" | grep -Ev '^(>|$)' | grep '='
  Device.Routing.X_PRPLWARE-COM_BGP.Enable=1

Add example route 198.51.100.0 to test route sharing using BGP.

  $ sudo ip route add blackhole 198.51.100.0/24 2>&1 | cat > /dev/null; true

Start BGP Server with configuration on isp-bgpd.

  $ sudo cp ${TESTDIR}/conf/routing/bgp_ipv4.frr.conf /etc/frr/frr.conf 2>&1 | grep -v "unable to resolve host"
  [1]
  $ sudo /usr/lib/frr/frrinit.sh start > /dev/null 2>&1

Configure import filter definition on CPE - Statement.1 matches SourceProtocol=BGP
and accepts route, Statement.2 rejects all remaining.

  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_RouteFiltering.FilterDefinition.+{Alias=\"cram-fd\"}'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_RouteFiltering.FilterDefinition.cram-fd.Statement.+{Alias=\"cram-st1\"}'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_RouteFiltering.FilterDefinition.cram-fd.Statement.cram-st1.Conditions.SourceProtocol=BGP'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_RouteFiltering.FilterDefinition.cram-fd.Statement.cram-st1.Actions.FilterResult=Accept'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_RouteFiltering.FilterDefinition.cram-fd.Statement.cram-st1.Enable=true'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_RouteFiltering.FilterDefinition.cram-fd.Statement.+{Alias=\"cram-st2\"}'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_RouteFiltering.FilterDefinition.cram-fd.Statement.cram-st2.Actions.FilterResult=Reject'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_RouteFiltering.FilterDefinition.cram-fd.Statement.cram-st2.Enable=true'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_RouteFiltering.FilterDefinition.cram-fd.Enable=true'" > /dev/null 2>&1

Resolve cram-fd to its numeric index: the DM validates the filter list against
"...FilterDefinition.<n>", so an alias-addressed path is rejected at write time
and the value never lands. Looked up, not hardcoded - the index is
auto-assigned:

  $ FD=$(R "ba-cli 'Device.Routing.X_PRPLWARE-COM_RouteFiltering.FilterDefinition.[Alias==\"cram-fd\"].?'" 2>&1 | grep -oE 'FilterDefinition\.[0-9]+' | head -1)
  $ echo "$FD" | grep -qE '^FilterDefinition\.[0-9]+$' && echo resolved
  resolved

Configure CPE BGP instance with import filter applied to Neighbor.cram-nb1.

  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.+{Alias=\"cram-config1\",AS=\"65000\"}'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.RouterID=1.1.1.1'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.MaxPrefixes=5000'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Timers.ConnectRetryInterval=120'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Timers.HoldTime=90'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Timers.KeepAlive=30'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.+{Alias=\"cram-nb1\"}'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.RemoteAddress=192.168.1.2'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.RemoteAS=65001'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.AFISAFI.+{Alias=\"cram-afisafi1\"}'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.AFISAFI.cram-afisafi1.Type=IPv4Unicast'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.AFISAFI.cram-afisafi1.Enable=true'" > /dev/null 2>&1

Route filtering rules.

  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.ApplyFilters.ImportFilters=Device.Routing.X_PRPLWARE-COM_RouteFiltering.$FD'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.ApplyFilters.DefaultImportDisposition=RejectRoute'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.ApplyFilters.DefaultExportDisposition=RejectRoute'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.Enable=true'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Enable=true'" > /dev/null 2>&1

Verify BGP Instance 1 Status is Enabled.

  $ R "ba-cli Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Status?" | grep -Ev '^(>|$)' | grep '='
  Device.Routing.X_PRPLWARE-COM_BGP.Config.\d+.Status="Enabled" (re)

Verify BGP session is Established.

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

Verify BGP prefix is received in AdjRIBIn from BGP Peer before import policy is applied.

  $ R "ba-cli Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.AdjRIBIn.IPv4.Route.*.Prefix?" | grep -Ev '^(>|$)' | grep '='
  Device.Routing.X_PRPLWARE-COM_BGP.Config.\d+.Neighbor.\d+.AdjRIBIn.IPv4.Route.\d+.Prefix="198.51.100.0/24" (re)

Verify BGP RIB - BGP-learned prefix is installed, static route is not present.

  $ R "ba-cli Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.RIB.IPv4.Route.*.Prefix?" | grep -Ev '^(>|$)' | grep '='
  Device.Routing.X_PRPLWARE-COM_BGP.Config.\d+.RIB.IPv4.Route.\d+.Prefix="198.51.100.0/24" (re)

Verify BGP-learned prefix is installed in CPE system routing table.

  $ R "ip route show" | grep "198.51.100"
  198.51.100.0/24 via 192.168.1.2 dev br-lan proto bird metric 32.* (re)

Verify static route 192.168.1.0/24 is not affected by BGP import filter - still
present in system routing table.

  $ R "ip route show" | grep "192.168.1.0/24"
  192.168.1.0/24 dev br-lan proto kernel scope link src 192.168.1.1.* (re)

Remove the instances and route created by this test.

  $ sudo ip route del blackhole 198.51.100.0/24 2>&1 | cat > /dev/null; true

  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.[Alias==\"cram-config1\"].-'" > /dev/null
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_RouteFiltering.FilterDefinition.[Alias==\"cram-fd\"].-'" > /dev/null

Stop the FRR daemon on the BGP server.

  $ sudo /usr/lib/frr/frrinit.sh stop > /dev/null 2>&1
