Verify OSPF route redistribution import filtering: a route matching a rejecting
RouteFiltering filter is kept out of the Local RIB and out of the kernel routing
table, while a non-matching route is redistributed, for IPv4 and IPv6.

Setup the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ OSPF_DM="Routing.X_PRPLWARE-COM_OSPF."
  $ RF_DM="Device.Routing.X_PRPLWARE-COM_RouteFiltering."
  $ TESTBED_IP6_LLA=$(ip -6 --json addr show $TESTBED_LAN_INTERFACE | jq --raw-output '.[0].addr_info[] | select (.scope == "link") | .local')
  $ TESTBED_IP4=$(ip -4 --json addr show $TESTBED_LAN_INTERFACE | jq -r '.[0].addr_info[0].local')
  $ LLA_LAN=$(R "ba-cli -l Device.IP.Interface.lan.IPv6Address.LLA.IPAddress? | awk 'NF'")

OSPF Route Redistribution Import Filtering for IPv4:

  $ R "ba-cli ${RF_DM}DefinedSets.PrefixSet+ {Alias=prefix4, IPVersion=4}" >/dev/null
  $ R "ba-cli ${RF_DM}DefinedSets.PrefixSet.prefix4.Prefix+ { Enable=1, IPPrefix='11.22.44.0/24', MaskLengthLower=24, MaskLengthUpper=32 }" >/dev/null
  $ R "ba-cli ${RF_DM}DefinedSets.PrefixSet.prefix4.Enable=1" >/dev/null
  $ PREFIX_SET_4=$(R "ba-cli -l resolve ${RF_DM}DefinedSets.PrefixSet.prefix4." | awk '{sub(/\.$/, "")} 1')
  $ R "ba-cli ${RF_DM}FilterDefinition+ {Alias=filter4}" >/dev/null
  $ R "ba-cli ${RF_DM}FilterDefinition.filter4.Statement+" >/dev/null
  $ R "ba-cli ${RF_DM}FilterDefinition.filter4.Statement.1.Actions.FilterResult='Reject'" >/dev/null
  $ R "ba-cli ${RF_DM}FilterDefinition.filter4.Statement.1.Conditions.MatchPrefixSet='${PREFIX_SET_4}'" >/dev/null
  $ R "ba-cli ${RF_DM}FilterDefinition.filter4.Statement.1.Enable=1" >/dev/null
  $ R "ba-cli ${RF_DM}FilterDefinition.filter4.Enable=1" >/dev/null
  $ FILTER4=$(R "ba-cli -l resolve ${RF_DM}FilterDefinition.filter4." | awk '{sub(/\.$/, "")} 1')
  $ R "ba-cli Routing.X_PRPLWARE-COM_OSPF.Config.ospf4.ApplyFilters.ImportFilters='${FILTER4}'" >/dev/null

  $ # simulate new route appearance
  $ sudo ip route add blackhole 11.22.44.0/24 2>/dev/null
  $ sudo ip route add blackhole 11.22.45.0/24 2>/dev/null
  $ sleep 1 # wait for route redistribution
  $ R "ba-cli '${OSPF_DM}RefreshRoutes()'" | grep -Ev '^(>|$)'
  Routing.X_PRPLWARE-COM_OSPF.RefreshRoutes() returned
  [
      {
          Status = "Success"
      }
  ]
  $ R "ba-cli '${OSPF_DM}Config.ospf4.LocalRIB.[Prefix==\"11.22.44.0/24\"].?'" | grep -Ev '^(>|$)'
  No data found
  $ R "ba-cli '${OSPF_DM}Config.ospf4.LocalRIB.[Prefix==\"11.22.45.0/24\"].?'" | grep -Ev '^(>|$)' | sed "s/$TESTBED_IP4/MATCHED/"
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\.Metric=10 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\.NextHopNumberOfEntries=1 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\.Prefix="11.22.45.0/24" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\.RouteType="External-2" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\.NextHop\.1\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\.NextHop\.1\.NextHop="MATCHED" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\.NextHop\.1\.OutgoingInterface="Device.IP.Interface.3" (re)
  $ R "ip -4 route" | grep "11.22.44.0/24" | wc -l
  0
  $ R "ip -4 route" | grep "11.22.45.0/24" | sed "s/$TESTBED_IP4/MATCHED/"
  11.22.45.0/24 via MATCHED dev br-lan proto bird metric 32 

OSPF Route Redistribution Import Filtering for IPv6:

  $ R "ba-cli ${RF_DM}DefinedSets.PrefixSet+ {Alias=prefix6, IPVersion=6}" >/dev/null
  $ R "ba-cli ${RF_DM}DefinedSets.PrefixSet.prefix6.Prefix+ { Enable=1, IPPrefix='2001:db8:4444::/48', MaskLengthLower=48, MaskLengthUpper=64 }" >/dev/null
  $ R "ba-cli ${RF_DM}DefinedSets.PrefixSet.prefix6.Enable=1" >/dev/null
  $ PREFIX_SET_6=$(R "ba-cli -l resolve ${RF_DM}DefinedSets.PrefixSet.prefix6." | awk '{sub(/\.$/, "")} 1')
  $ R "ba-cli ${RF_DM}FilterDefinition+ {Alias=filter6}" >/dev/null
  $ R "ba-cli ${RF_DM}FilterDefinition.filter6.Statement+" >/dev/null
  $ R "ba-cli ${RF_DM}FilterDefinition.filter6.Statement.1.Actions.FilterResult='Reject'" >/dev/null
  $ R "ba-cli ${RF_DM}FilterDefinition.filter6.Statement.1.Conditions.MatchPrefixSet='${PREFIX_SET_6}'" >/dev/null
  $ R "ba-cli ${RF_DM}FilterDefinition.filter6.Statement.1.Enable=1" >/dev/null
  $ R "ba-cli ${RF_DM}FilterDefinition.filter6.Enable=1" >/dev/null
  $ FILTER6=$(R "ba-cli -l resolve ${RF_DM}FilterDefinition.filter6." | awk '{sub(/\.$/, "")} 1')
  $ R "ba-cli Routing.X_PRPLWARE-COM_OSPF.Config.ospf6.ApplyFilters.ImportFilters='${FILTER6}'" >/dev/null

  $ # simulate new route appearance
  $ sudo ip -6 route add blackhole 2001:db8:4444::/48 2>/dev/null
  $ sudo ip -6 route add blackhole 2001:db8:5555::/48 2>/dev/null
  $ sleep 1 # wait for route redistribution
  $ R "ba-cli '${OSPF_DM}RefreshRoutes()'" | grep -Ev '^(>|$)'
  Routing.X_PRPLWARE-COM_OSPF.RefreshRoutes() returned
  [
      {
          Status = "Success"
      }
  ]
  $ R "ba-cli '${OSPF_DM}Config.ospf6.LocalRIB.[Prefix==\"2001:db8:4444::/48\"].?'" | grep -Ev '^(>|$)'
  No data found
  $ R "ba-cli '${OSPF_DM}Config.ospf6.LocalRIB.[Prefix==\"2001:db8:5555::/48\"].?'" | grep -Ev '^(>|$)' | sed "s/$TESTBED_IP6_LLA/MATCHED/"
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\.Metric=10 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\.NextHopNumberOfEntries=1 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\.Prefix="2001:db8:5555::/48" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\.RouteType="External-2" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\.NextHop\.1\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\.NextHop\.1\.NextHop="MATCHED" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\.NextHop\.1\.OutgoingInterface="Device.IP.Interface.3" (re)
  $ R "ip -6 route" | grep "2001:db8:4444::/48" | wc -l
  0
  $ R "ip -6 route" | grep "2001:db8:5555::/48" | sed "s/$TESTBED_IP6_LLA/MATCHED/"
  2001:db8:5555::/48 via MATCHED dev br-lan proto bird metric 32 pref medium
