Set up the OSPF test environment: start the bird2 router on the testbed and
create the IPv4 (RFC5838 address family) and IPv6 OSPF instances on the CPE.
Must run before the other 122-routing-ospf-* tests.

Setup the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ OSPF_DM="Routing.X_PRPLWARE-COM_OSPF."

Prepare bird configuration file:

  $ sudo cp ${TESTDIR}/conf/routing/ospf.bird2.conf /etc/bird/bird.conf 2>/dev/null
  $ sudo sed -i "s/INTERFACE/$TESTBED_LAN_INTERFACE/" /etc/bird/bird.conf 2>/dev/null

Verify the initial state:

  $ R "ba-cli ${OSPF_DM}?" | grep -Ev '^(>|$)'
  Routing.X_PRPLWARE-COM_OSPF.
  Routing.X_PRPLWARE-COM_OSPF.ConfigNumberOfEntries=0
  Routing.X_PRPLWARE-COM_OSPF.Enable=0
  Routing\.X_PRPLWARE-COM_OSPF\.LastRefreshTime=".*" (re)

Configure the first IPv4 OSPF instance (address family extensions - RFC5838):

  $ R "ba-cli ${OSPF_DM}Config+ {Alias='ospf4', InstanceID=64, RouterID='1.1.1.1', IPVersion=4}" >/dev/null
  $ R "ba-cli ${OSPF_DM}Config.ospf4.ApplyFilters.DefaultImportDisposition='AcceptRoute'" >/dev/null
  $ R "ba-cli ${OSPF_DM}Config.ospf4.ApplyFilters.DefaultExportDisposition='AcceptRoute'" >/dev/null
  $ R "ba-cli ${OSPF_DM}Config.ospf4.Area+ {AreaID='0.0.0.0'}" >/dev/null
  $ R "ba-cli ${OSPF_DM}Config.ospf4.Area.1.Interface+ {Interface='Device.IP.Interface.3', Priority=100, HelloInterval=1, DeadInterval=4, RetransmitInterval=5, Cost=10}" >/dev/null
  $ R "ba-cli ${OSPF_DM}Config.ospf4.Area.1.Interface.1.Enable=1" >/dev/null
  $ R "ba-cli ${OSPF_DM}Config.ospf4.Area.1.Enable=1" >/dev/null
  $ R "ba-cli ${OSPF_DM}Config.ospf4.Enable=1" >/dev/null

Configure the first IPv6 OSPF instance:

  $ R "ba-cli ${OSPF_DM}Config+ {Alias='ospf6', InstanceID=1, RouterID='1.1.1.1', IPVersion=6}" >/dev/null
  $ R "ba-cli ${OSPF_DM}Config.ospf6.ApplyFilters.DefaultImportDisposition='AcceptRoute'" >/dev/null
  $ R "ba-cli ${OSPF_DM}Config.ospf6.ApplyFilters.DefaultExportDisposition='AcceptRoute'" >/dev/null
  $ R "ba-cli ${OSPF_DM}Config.ospf6.Area+ {AreaID='0.0.0.0'}" >/dev/null
  $ R "ba-cli ${OSPF_DM}Config.ospf6.Area.1.Interface+ {Interface='Device.IP.Interface.3', Priority=100, HelloInterval=1, DeadInterval=4, RetransmitInterval=5, Cost=10}" >/dev/null
  $ R "ba-cli ${OSPF_DM}Config.ospf6.Area.1.Interface.1.Enable=1" >/dev/null
  $ R "ba-cli ${OSPF_DM}Config.ospf6.Area.1.Enable=1" >/dev/null
  $ R "ba-cli ${OSPF_DM}Config.ospf6.Enable=1" >/dev/null

Enable OSPF and verify corresponding processes:

  $ R "ps aux | grep [b]ird" | wc -l
  0
  $ R "ba-cli ${OSPF_DM}Enable=1" >/dev/null
  $ R "ps aux | grep [b]ird" | wc -l
  1

Run OSPF router that will be BDR (Backup Designated Router) for both IPv4 and IPv6 OSPF instances on LAN side:

  $ sudo bird -P /var/run/bird.pid 2>/dev/null
