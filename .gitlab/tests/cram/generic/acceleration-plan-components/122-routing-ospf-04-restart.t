Verify that OSPF recovers from a routing-manager restart: the IPv4 and IPv6
interface states and the discovered neighbors are re-established afterwards.

Setup the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ OSPF_DM="Routing.X_PRPLWARE-COM_OSPF."
  $ TESTBED_IP6_LLA=$(ip -6 --json addr show $TESTBED_LAN_INTERFACE | jq --raw-output '.[0].addr_info[] | select (.scope == "link") | .local')

Restart routing manager:

  $ R "service routing-manager stop"
  $ sleep 5
  $ R "service routing-manager start"
  $ sleep 7

Verify the connection is reestablished for IPv4 OSPF:

  $ R "ba-cli ${OSPF_DM}Config.ospf4.Area.1.Interface.1.State?" | grep -Ev '^(>|$)'
  Routing.X_PRPLWARE-COM_OSPF.Config.\d+.Area.1.Interface.1.State="BackupDesignatedRouter" (re)

Verify the connection is reestablished for IPv6 OSPF:

  $ R "ba-cli ${OSPF_DM}Config.ospf6.Area.1.Interface.1.State?" | grep -Ev '^(>|$)'
  Routing.X_PRPLWARE-COM_OSPF.Config.\d+.Area.1.Interface.1.State="BackupDesignatedRouter" (re)

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

