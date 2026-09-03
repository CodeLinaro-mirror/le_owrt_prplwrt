Verify OSPF interface authentication: the IPv4 adjacency is lost once the remote
router enables MD5 authentication, and is re-established after the matching
authentication trailer is configured on the CPE.

Setup the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ OSPF_DM="Routing.X_PRPLWARE-COM_OSPF."
  $ RF_DM="Device.Routing.X_PRPLWARE-COM_RouteFiltering."
  $ TESTBED_IP6_LLA=$(ip -6 --json addr show $TESTBED_LAN_INTERFACE | jq --raw-output '.[0].addr_info[] | select (.scope == "link") | .local')

Setup bird for authentication:

  $ sudo cp ${TESTDIR}/conf/routing/ospf_auth.bird2.conf /etc/bird/bird.conf 2>/dev/null
  $ sudo sed -i "s/INTERFACE/$TESTBED_LAN_INTERFACE/" /etc/bird/bird.conf 2>/dev/null
  $ sudo birdc configure >/dev/null 2>/dev/null
  $ sleep 10

Verify the neighbor disappeared because of the new authentication:

  $ R "ba-cli ${OSPF_DM}Config.ospf4.Area.1.Interface.1.State?" | grep -Ev '^(>|$)'
  Routing.X_PRPLWARE-COM_OSPF.Config.\d+.Area.1.Interface.1.State="DesignatedRouter" (re)
  $ R "ba-cli ${OSPF_DM}Config.ospf4.Area.1.Interface.1.NeighborNumberOfEntries?" | grep -Ev '^(>|$)'
  Routing\.X_PRPLWARE-COM_OSPF\.Config\.\d+\.Area\.1\.Interface\.1\.NeighborNumberOfEntries=0 (re)

Setup the authentication for IPv4 OSPF:

  $ R "ba-cli ${OSPF_DM}Config.ospf4.Area.1.Interface.1.Authentication.Trailer.ID=1" >/dev/null
  $ R "ba-cli ${OSPF_DM}Config.ospf4.Area.1.Interface.1.Authentication.Trailer.Algorithm=HMAC-MD5" >/dev/null
  $ R "ba-cli ${OSPF_DM}Config.ospf4.Area.1.Interface.1.Authentication.Trailer.Key='secret-key'" >/dev/null
  $ R "ba-cli ${OSPF_DM}Config.ospf4.Area.1.Interface.1.Authentication.Trailer.Enable=1" >/dev/null
  $ . ${TESTDIR}/script_functions_routing.sh
  $ wait_ospf_neighbors ospf4 1 1

Verify the connection is established for IPv4 OSPF with authentication (MD5):

  $ R "ba-cli ${OSPF_DM}Config.ospf4.Area.1.Interface.1.State?" | grep -Ev '^(>|$)'
  Routing.X_PRPLWARE-COM_OSPF.Config.\d+.Area.1.Interface.1.State="DesignatedRouter" (re)
  $ R "ba-cli ${OSPF_DM}Config.ospf4.Area.1.Interface.1.Neighbor.1.NeighborRouterID?" | grep -Ev '^(>|$)'
  Routing.X_PRPLWARE-COM_OSPF.Config.\d+.Area.1.Interface.1.Neighbor.1.NeighborRouterID="2.2.2.2" (re)
  $ R "ba-cli ${OSPF_DM}Config.ospf4.Area.1.Interface.1.Neighbor.1.Address?" | grep -Ev '^(>|$)' | sed "s/$TESTBED_IP6_LLA/MATCHED/"
  Routing.X_PRPLWARE-COM_OSPF.Config.\d+.Area.1.Interface.1.Neighbor.1.Address="MATCHED" (re)
  $ R "ba-cli ${OSPF_DM}Config.ospf4.Area.1.Interface.1.Neighbor.1.State?" | grep -Ev '^(>|$)'
  Routing.X_PRPLWARE-COM_OSPF.Config.\d+.Area.1.Interface.1.Neighbor.1.State="Full" (re)
