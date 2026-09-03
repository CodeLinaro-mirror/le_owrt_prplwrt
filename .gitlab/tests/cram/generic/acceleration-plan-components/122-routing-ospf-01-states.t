Verify the OSPF adjacency and database state exposed in the data model:
interface DR/BDR election, discovered neighbors, the Local RIB and the
Link-State Database (Router-, Network- and Intra-Area-Prefix-LSAs), for IPv4 and IPv6.

Setup the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ OSPF_DM="Routing.X_PRPLWARE-COM_OSPF."
  $ TESTBED_IP6_LLA=$(ip -6 --json addr show $TESTBED_LAN_INTERFACE | jq --raw-output '.[0].addr_info[] | select (.scope == "link") | .local')
  $ TESTBED_IP4=$(ip -4 --json addr show $TESTBED_LAN_INTERFACE | jq -r '.[0].addr_info[0].local')
  $ LLA_LAN=$(R "ba-cli -l Device.IP.Interface.lan.IPv6Address.LLA.IPAddress? | awk 'NF'")

Wait for establishing connection and neighbors:

  $ . ${TESTDIR}/script_functions_routing.sh
  $ wait_ospf_state ospf4 1 1 DesignatedRouter
  $ wait_ospf_state ospf6 1 1 DesignatedRouter
  $ wait_ospf_neighbors ospf4 1 1
  $ wait_ospf_neighbors ospf6 1 1
  $ sleep 1 # wait for route redistribution

Verify interface state priority for IPv4 OSPF:

  $ R "ba-cli ${OSPF_DM}Config.ospf4.Area.1.Interface.1.State?" | grep -Ev '^(>|$)'
  Routing.X_PRPLWARE-COM_OSPF.Config.\d+.Area.1.Interface.1.State="DesignatedRouter" (re)
  $ R "ba-cli ${OSPF_DM}Config.ospf4.Area.1.Interface.1.Priority?" | grep -Ev '^(>|$)'
  Routing.X_PRPLWARE-COM_OSPF.Config.\d+.Area.1.Interface.1.Priority=100 (re)

Verify the data of elected DR and BDR is populated for IPv4 OSPF:

  $ R "ba-cli ${OSPF_DM}Config.ospf4.Area.1.Interface.1.DesignatedRouterID?" | grep -Ev '^(>|$)'
  Routing.X_PRPLWARE-COM_OSPF.Config.\d+.Area.1.Interface.1.DesignatedRouterID="1.1.1.1" (re)
  $ R "ba-cli ${OSPF_DM}Config.ospf4.Area.1.Interface.1.DesignatedRouterIPAddress?" | grep -Ev '^(>|$)' | sed "s/$LLA_LAN/MATCHED/"
  Routing.X_PRPLWARE-COM_OSPF.Config.\d+.Area.1.Interface.1.DesignatedRouterIPAddress="MATCHED" (re)
  $ R "ba-cli ${OSPF_DM}Config.ospf4.Area.1.Interface.1.BackupDesignatedRouterID?" | grep -Ev '^(>|$)'
  Routing.X_PRPLWARE-COM_OSPF.Config.\d+.Area.1.Interface.1.BackupDesignatedRouterID="2.2.2.2" (re)
  $ R "ba-cli ${OSPF_DM}Config.ospf4.Area.1.Interface.1.BackupDesignatedRouterIPAddress?" | grep -Ev '^(>|$)' | sed "s/$TESTBED_IP6_LLA/MATCHED/"
  Routing.X_PRPLWARE-COM_OSPF.Config.\d+.Area.1.Interface.1.BackupDesignatedRouterIPAddress="MATCHED" (re)

Verify the data of elected DR and BDR is populated for IPv6 OSPF:

  $ R "ba-cli ${OSPF_DM}Config.ospf6.Area.1.Interface.1.DesignatedRouterID?" | grep -Ev '^(>|$)'
  Routing.X_PRPLWARE-COM_OSPF.Config.\d+.Area.1.Interface.1.DesignatedRouterID="1.1.1.1" (re)
  $ R "ba-cli ${OSPF_DM}Config.ospf6.Area.1.Interface.1.DesignatedRouterIPAddress?" | grep -Ev '^(>|$)' | sed "s/$LLA_LAN/MATCHED/"
  Routing.X_PRPLWARE-COM_OSPF.Config.\d+.Area.1.Interface.1.DesignatedRouterIPAddress="MATCHED" (re)
  $ R "ba-cli ${OSPF_DM}Config.ospf6.Area.1.Interface.1.BackupDesignatedRouterID?" | grep -Ev '^(>|$)'
  Routing.X_PRPLWARE-COM_OSPF.Config.\d+.Area.1.Interface.1.BackupDesignatedRouterID="2.2.2.2" (re)
  $ R "ba-cli ${OSPF_DM}Config.ospf6.Area.1.Interface.1.BackupDesignatedRouterIPAddress?" | grep -Ev '^(>|$)' | sed "s/$TESTBED_IP6_LLA/MATCHED/"
  Routing.X_PRPLWARE-COM_OSPF.Config.\d+.Area.1.Interface.1.BackupDesignatedRouterIPAddress="MATCHED" (re)

Verify that the discovered neighbor and its adjacency for IPv4 OSPF:

  $ R "ba-cli ${OSPF_DM}Config.ospf4.Area.1.Interface.1.Neighbor.1.NeighborRouterID?" | grep -Ev '^(>|$)'
  Routing.X_PRPLWARE-COM_OSPF.Config.\d+.Area.1.Interface.1.Neighbor.1.NeighborRouterID="2.2.2.2" (re)
  $ R "ba-cli ${OSPF_DM}Config.ospf4.Area.1.Interface.1.Neighbor.1.Address?" | grep -Ev '^(>|$)' | sed "s/$TESTBED_IP6_LLA/MATCHED/"
  Routing.X_PRPLWARE-COM_OSPF.Config.\d+.Area.1.Interface.1.Neighbor.1.Address="MATCHED" (re)
  $ R "ba-cli ${OSPF_DM}Config.ospf4.Area.1.Interface.1.Neighbor.1.State?" | grep -Ev '^(>|$)'
  Routing.X_PRPLWARE-COM_OSPF.Config.\d+.Area.1.Interface.1.Neighbor.1.State="Full" (re)

Verify that the discovered neighbor and its adjacency for IPv6 OSPF:

  $ R "ba-cli ${OSPF_DM}Config.ospf6.Area.1.Interface.1.Neighbor.1.NeighborRouterID?" | grep -Ev '^(>|$)'
  Routing.X_PRPLWARE-COM_OSPF.Config.\d+.Area.1.Interface.1.Neighbor.1.NeighborRouterID="2.2.2.2" (re)
  $ R "ba-cli ${OSPF_DM}Config.ospf6.Area.1.Interface.1.Neighbor.1.Address?" | grep -Ev '^(>|$)' | sed "s/$TESTBED_IP6_LLA/MATCHED/"
  Routing.X_PRPLWARE-COM_OSPF.Config.\d+.Area.1.Interface.1.Neighbor.1.Address="MATCHED" (re)
  $ R "ba-cli ${OSPF_DM}Config.ospf6.Area.1.Interface.1.Neighbor.1.State?" | grep -Ev '^(>|$)'
  Routing.X_PRPLWARE-COM_OSPF.Config.\d+.Area.1.Interface.1.Neighbor.1.State="Full" (re)

Populate routing information in the data model for all OSPF:

  $ # the USP command is asynchronous but running it in foreground ba-cli makes it synchronous so we should be good
  $ R "ba-cli '${OSPF_DM}RefreshRoutes()'" | grep -Ev '^(>|$)'
  Routing.X_PRPLWARE-COM_OSPF.RefreshRoutes() returned
  [
      {
          Status = "Success"
      }
  ]
  $ R "ip -4 route" | grep "11.22.33.0/24" | sed "s/$TESTBED_IP4/MATCHED/"
  11.22.33.0/24 via MATCHED dev br-lan proto bird metric 32 
  $ R "ip -6 route" | grep "2001:db8:1234::/48" | sed "s/$TESTBED_IP6_LLA/MATCHED/"
  2001:db8:1234::/48 via MATCHED dev br-lan proto bird metric 32 pref medium

Verify Local RIB for IPv4 OSPF:

  $ R "ba-cli ${OSPF_DM}Config.ospf4.LocalRIB.?" | grep -Ev '^(>|$)' | sed "s/$TESTBED_IP4/MATCHED/"
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.1\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.1\.Metric=10 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.1\.NextHopNumberOfEntries=1 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.1\.Prefix="11.22.33.0/24" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.1\.RouteType="External-2" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.1\.NextHop\.1\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.1\.NextHop\.1\.NextHop="MATCHED" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.1\.NextHop\.1\.OutgoingInterface="Device.IP.Interface.3" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.2\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.2\.Metric=10 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.2\.NextHopNumberOfEntries=1 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.2\.Prefix="192.168.1.0/24" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.2\.RouteType="IntraArea" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.2\.NextHop\.1\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.2\.NextHop\.1\.NextHop="" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.2\.NextHop\.1\.OutgoingInterface="Device.IP.Interface.3" (re)

Verify Local RIB for IPv6 OSPF:

# GUA test is diabled as it looks like testbed does not have a GU address
#  $ GUA_IP6_PREFIX=$(ip -6 route show dev $TESTBED_LAN_INTERFACE proto kernel | awk '{print $1}' | head -n 1)
#  $ R "ba-cli '${OSPF_DM}Config.ospf6.LocalRIB.[Prefix == \"$GUA_IP6_PREFIX\"].?'" | grep -Ev '^(>|$)' | sed "s|$GUA_IP6_PREFIX|MATCHED|"
#  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\. (re)
#  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\.Metric=10 (re)
#  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\.NextHopNumberOfEntries=1 (re)
#  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\.Prefix="MATCHED" (re)
#  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\.RouteType="IntraArea" (re)
#  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\.NextHop\.1\. (re)
#  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\.NextHop\.1\.NextHop="" (re)
#  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\.NextHop\.1\.OutgoingInterface="Device.IP.Interface.3" (re)
  $ R "ba-cli '${OSPF_DM}Config.ospf6.LocalRIB.[Prefix == \"2001:db8:1234::/48\"].?'" | grep -Ev '^(>|$)' | sed "s/$TESTBED_IP6_LLA/MATCHED/"
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\.Metric=10 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\.NextHopNumberOfEntries=1 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\.Prefix="2001:db8:1234::/48" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\.RouteType="External-2" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\.NextHop\.1\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\.NextHop\.1\.NextHop="MATCHED" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.LocalRIB\.\d+\.NextHop\.1\.OutgoingInterface="Device.IP.Interface.3" (re)

Verify Link-State Database for IPv4 OSPF

Verify Router-LSAs (LSA type = 0x2001 or 8193):

  $ R "ba-cli Routing.X_PRPLWARE-COM_OSPF.Config.ospf4.Area.1.LSDB.RouterLSANumberOfEntries?" | grep -Ev '^(>|$)'
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSANumberOfEntries=2 (re)
  $ R "ba-cli 'Routing.X_PRPLWARE-COM_OSPF.Config.ospf4.Area.1.LSDB.LSA.[LSAType==8193 && AdvRouter==\"1.1.1.1\"].?'" | grep -Ev '^(>|$)'
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.AdvRouter="1.1.1.1" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.Age=\d+ (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.Checksum="[0-9a-fA-F]+" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.LSAID="0.0.0.0" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.LSAType=8193 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.SeqNum=\d+ (re)
  $ R "ba-cli 'Routing.X_PRPLWARE-COM_OSPF.Config.ospf4.Area.1.LSDB.LSA.[LSAType==8193 && AdvRouter==\"2.2.2.2\"].?'" | grep -Ev '^(>|$)'
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.AdvRouter="2.2.2.2" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.Age=\d+ (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.Checksum="[0-9a-fA-F]+" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.LSAID="0.0.0.0" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.LSAType=8193 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.SeqNum=\d+ (re)
  $ R "ba-cli 'Routing.X_PRPLWARE-COM_OSPF.Config.ospf4.Area.1.LSDB.RouterLSA.[AdvRouter==\"1.1.1.1\"].?'" | grep -Ev '^(>|$)'
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\.AdvRouter="1.1.1.1" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\.LinkNumberOfEntries=1 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\.Link\.1\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\.Link\.1\.Metric=10 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\.Link\.1\.NeighborInterfaceID=\d+ (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\.Link\.1\.NeighborRouterID="1.1.1.1" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\.Link\.1\.Type="TransitNetwork" (re)
  $ R "ba-cli 'Routing.X_PRPLWARE-COM_OSPF.Config.ospf4.Area.1.LSDB.RouterLSA.[AdvRouter==\"2.2.2.2\"].?'" | grep -Ev '^(>|$)'
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\.AdvRouter="2.2.2.2" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\.LinkNumberOfEntries=1 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\.Link\.1\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\.Link\.1\.Metric=10 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\.Link\.1\.NeighborInterfaceID=\d+ (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\.Link\.1\.NeighborRouterID="1.1.1.1" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\.Link\.1\.Type="TransitNetwork" (re)

Verify Network-LSAs (LSA type = 0x2002 or 8194):

  $ R "ba-cli Routing.X_PRPLWARE-COM_OSPF.Config.ospf4.Area.1.LSDB.NetworkLSANumberOfEntries?" | grep -Ev '^(>|$)'
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.NetworkLSANumberOfEntries=1 (re)
  $ R "ba-cli 'Routing.X_PRPLWARE-COM_OSPF.Config.ospf4.Area.1.LSDB.LSA.[LSAType==8194].?'" | grep -Ev '^(>|$)'
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.AdvRouter="1.1.1.1" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.Age=\d+ (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.Checksum="[0-9a-fA-F]+" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.LSAID="0.0.0.\d+" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.LSAType=8194 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.SeqNum=\d+ (re)
  $ R "ba-cli 'Routing.X_PRPLWARE-COM_OSPF.Config.ospf4.Area.1.LSDB.NetworkLSA.?'" | grep -Ev '^(>|$)'
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.NetworkLSA\.1\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.NetworkLSA\.1\.AdvRouter="1.1.1.1" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.NetworkLSA\.1\.AttachedRouterNumberOfEntries=2 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.NetworkLSA\.1\.AttachedRouter\.1\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.NetworkLSA\.1\.AttachedRouter\.1\.RouterID="1.1.1.1" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.NetworkLSA\.1\.AttachedRouter\.2\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.NetworkLSA\.1\.AttachedRouter\.2\.RouterID="2.2.2.2" (re)

Verify Intra-Area-Prefix-LSAs (LSA type = 0x2009 or 8201):

  $ R "ba-cli Routing.X_PRPLWARE-COM_OSPF.Config.ospf4.Area.1.LSDB.IntraAreaPrefixLSANumberOfEntries?" | grep -Ev '^(>|$)'
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.IntraAreaPrefixLSANumberOfEntries=1 (re)
  $ # RFC5340(A.4.10): A router can originate multiple intra-area-prefix-LSAs for each router or transit network.
  $ R "ba-cli 'Routing.X_PRPLWARE-COM_OSPF.Config.ospf4.Area.1.LSDB.LSA.[LSAType==8201 && AdvRouter==\"1.1.1.1\" && LSAID==\"0.0.0.0\"].?'" | grep -Ev '^(>|$)'
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.AdvRouter="1.1.1.1" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.Age=\d+ (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.Checksum="[0-9a-fA-F]+" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.LSAID="0.0.0.0" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.LSAType=8201 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.SeqNum=\d+ (re)
  $ R "ba-cli 'Routing.X_PRPLWARE-COM_OSPF.Config.ospf4.Area.1.LSDB.LSA.[LSAType==8201 && AdvRouter==\"2.2.2.2\"].?'" | grep -Ev '^(>|$)'
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.AdvRouter="2.2.2.2" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.Age=\d+ (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.Checksum="[0-9a-fA-F]+" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.LSAID="0.0.0.0" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.LSAType=8201 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.SeqNum=\d+ (re)
  $ LAN_IP4_PREFIX=$(ip -4 route show dev $TESTBED_LAN_INTERFACE proto kernel | awk '{print $1}' | head -n 1)
  $ R "ba-cli 'Routing.X_PRPLWARE-COM_OSPF.Config.ospf4.Area.1.LSDB.IntraAreaPrefixLSA.?'" | grep -Ev '^(>|$)' | sed "s|$LAN_IP4_PREFIX|MATCHED|"
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.IntraAreaPrefixLSA\.1\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.IntraAreaPrefixLSA\.1\.AdvRouter="1.1.1.1" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.IntraAreaPrefixLSA\.1\.PrefixNumberOfEntries=1 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.IntraAreaPrefixLSA\.1\.Prefix\.1\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.IntraAreaPrefixLSA\.1\.Prefix\.1\.Metric=0 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.IntraAreaPrefixLSA\.1\.Prefix\.1\.Prefix="MATCHED" (re)



Verify Link-State Database for IPv6 OSPF

Verify Router-LSAs (LSA type = 0x2001 or 8193):

  $ R "ba-cli Routing.X_PRPLWARE-COM_OSPF.Config.ospf6.Area.1.LSDB.RouterLSANumberOfEntries?" | grep -Ev '^(>|$)'
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSANumberOfEntries=2 (re)
  $ R "ba-cli 'Routing.X_PRPLWARE-COM_OSPF.Config.ospf6.Area.1.LSDB.LSA.[LSAType==8193 && AdvRouter==\"1.1.1.1\"].?'" | grep -Ev '^(>|$)'
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.AdvRouter="1.1.1.1" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.Age=\d+ (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.Checksum="[0-9a-fA-F]+" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.LSAID="0.0.0.0" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.LSAType=8193 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.SeqNum=\d+ (re)
  $ R "ba-cli 'Routing.X_PRPLWARE-COM_OSPF.Config.ospf6.Area.1.LSDB.LSA.[LSAType==8193 && AdvRouter==\"2.2.2.2\"].?'" | grep -Ev '^(>|$)'
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.AdvRouter="2.2.2.2" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.Age=\d+ (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.Checksum="[0-9a-fA-F]+" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.LSAID="0.0.0.0" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.LSAType=8193 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.SeqNum=\d+ (re)
  $ R "ba-cli 'Routing.X_PRPLWARE-COM_OSPF.Config.ospf6.Area.1.LSDB.RouterLSA.[AdvRouter==\"1.1.1.1\"].?'" | grep -Ev '^(>|$)'
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\.AdvRouter="1.1.1.1" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\.LinkNumberOfEntries=1 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\.Link\.1\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\.Link\.1\.Metric=10 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\.Link\.1\.NeighborInterfaceID=\d+ (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\.Link\.1\.NeighborRouterID="1.1.1.1" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\.Link\.1\.Type="TransitNetwork" (re)
  $ R "ba-cli 'Routing.X_PRPLWARE-COM_OSPF.Config.ospf6.Area.1.LSDB.RouterLSA.[AdvRouter==\"2.2.2.2\"].?'" | grep -Ev '^(>|$)'
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\.AdvRouter="2.2.2.2" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\.LinkNumberOfEntries=1 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\.Link\.1\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\.Link\.1\.Metric=10 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\.Link\.1\.NeighborInterfaceID=\d+ (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\.Link\.1\.NeighborRouterID="1.1.1.1" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.RouterLSA\.\d+\.Link\.1\.Type="TransitNetwork" (re)

Verify Network-LSAs (LSA type = 0x2002 or 8194):

  $ R "ba-cli Routing.X_PRPLWARE-COM_OSPF.Config.ospf6.Area.1.LSDB.NetworkLSANumberOfEntries?" | grep -Ev '^(>|$)'
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.NetworkLSANumberOfEntries=1 (re)
  $ R "ba-cli 'Routing.X_PRPLWARE-COM_OSPF.Config.ospf6.Area.1.LSDB.LSA.[LSAType==8194].?'" | grep -Ev '^(>|$)'
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.AdvRouter="1.1.1.1" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.Age=\d+ (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.Checksum="[0-9a-fA-F]+" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.LSAID="0.0.0.\d+" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.LSAType=8194 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.SeqNum=\d+ (re)
  $ R "ba-cli 'Routing.X_PRPLWARE-COM_OSPF.Config.ospf6.Area.1.LSDB.NetworkLSA.?'" | grep -Ev '^(>|$)'
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.NetworkLSA\.1\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.NetworkLSA\.1\.AdvRouter="1.1.1.1" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.NetworkLSA\.1\.AttachedRouterNumberOfEntries=2 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.NetworkLSA\.1\.AttachedRouter\.1\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.NetworkLSA\.1\.AttachedRouter\.1\.RouterID="1.1.1.1" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.NetworkLSA\.1\.AttachedRouter\.2\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.NetworkLSA\.1\.AttachedRouter\.2\.RouterID="2.2.2.2" (re)

Verify Intra-Area-Prefix-LSAs (LSA type = 0x2009 or 8201):
# GUA test is diabled as it looks like testbed does not have a GU address
#  $ R "ba-cli Routing.X_PRPLWARE-COM_OSPF.Config.ospf6.Area.1.LSDB.IntraAreaPrefixLSANumberOfEntries?" | grep -Ev '^(>|$)'
#  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.IntraAreaPrefixLSANumberOfEntries=1 (re)
# RFC5340(A.4.10): A router can originate multiple intra-area-prefix-LSAs for each router or transit network.
  $ R "ba-cli 'Routing.X_PRPLWARE-COM_OSPF.Config.ospf6.Area.1.LSDB.LSA.[LSAType==8201 && AdvRouter==\"1.1.1.1\" && LSAID==\"0.0.0.0\"].?'" | grep -Ev '^(>|$)'
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.AdvRouter="1.1.1.1" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.Age=\d+ (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.Checksum="[0-9a-fA-F]+" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.LSAID="0.0.0.0" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.LSAType=8201 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.SeqNum=\d+ (re)
  $ R "ba-cli 'Routing.X_PRPLWARE-COM_OSPF.Config.ospf6.Area.1.LSDB.LSA.[LSAType==8201 && AdvRouter==\"2.2.2.2\"].?'" | grep -Ev '^(>|$)'
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\. (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.AdvRouter="2.2.2.2" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.Age=\d+ (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.Checksum="[0-9a-fA-F]+" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.LSAID="0.0.0.0" (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.LSAType=8201 (re)
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.LSA\.\d+\.SeqNum=\d+ (re)
# GUA test is diabled as it looks like testbed does not have a GU address
#  $ LAN_IP6_PREFIX=$(ip -6 route show dev $TESTBED_LAN_INTERFACE proto kernel | awk '{print $1}' | head -n 1)
#  $ R "ba-cli 'Routing.X_PRPLWARE-COM_OSPF.Config.ospf6.Area.1.LSDB.IntraAreaPrefixLSA.?'" | grep -Ev '^(>|$)' | sed "s|$LAN_IP6_PREFIX|MATCHED|"
#  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.IntraAreaPrefixLSA\.1\. (re)
#  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.IntraAreaPrefixLSA\.1\.AdvRouter="1.1.1.1" (re)
#  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.IntraAreaPrefixLSA\.1\.PrefixNumberOfEntries=1 (re)
#  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.IntraAreaPrefixLSA\.1\.Prefix\.1\. (re)
#  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.IntraAreaPrefixLSA\.1\.Prefix\.1\.Metric=0 (re)
#  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.LSDB\.IntraAreaPrefixLSA\.1\.Prefix\.1\.Prefix="MATCHED" (re)
