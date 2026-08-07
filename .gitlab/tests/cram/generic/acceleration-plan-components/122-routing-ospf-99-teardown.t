Tear down the OSPF test environment: remove the OSPF instances and the
RouteFiltering objects from the CPE, and stop the bird2 router on the testbed.
Must run after the other 122-routing-ospf-* tests.

Setup the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ OSPF_DM="Routing.X_PRPLWARE-COM_OSPF."
  $ RF_DM="Device.Routing.X_PRPLWARE-COM_RouteFiltering."

Perform teardown of IPv4 OSPF:

  $ R "ba-cli ${OSPF_DM}Config.ospf4.Enable=0" >/dev/null
  $ R "ba-cli ${OSPF_DM}Config.ospf4-" >/dev/null
  $ R "ba-cli ${RF_DM}FilterDefinition.filter4.Enable=0" >/dev/null
  $ R "ba-cli ${RF_DM}FilterDefinition.filter4-" >/dev/null
  $ R "ba-cli ${RF_DM}DefinedSets.PrefixSet.prefix4.Enable=0" >/dev/null
  $ R "ba-cli ${RF_DM}DefinedSets.PrefixSet.prefix4-" >/dev/null

Perform teardown of IPv6 OSPF:

  $ R "ba-cli ${OSPF_DM}Config.ospf6.Enable=0" >/dev/null
  $ R "ba-cli ${OSPF_DM}Config.ospf6-" >/dev/null
  $ R "ba-cli ${RF_DM}FilterDefinition.filter6.Enable=0" >/dev/null
  $ R "ba-cli ${RF_DM}FilterDefinition.filter6-" >/dev/null
  $ R "ba-cli ${RF_DM}DefinedSets.PrefixSet.prefix6.Enable=0" >/dev/null
  $ R "ba-cli ${RF_DM}DefinedSets.PrefixSet.prefix6-" >/dev/null
  $ R "ba-cli ${OSPF_DM}Enable=0" >/dev/null
  $ R "ps aux | grep [b]ird" | wc -l
  0

Teardown this OSPF router:

  $ sudo ip route del blackhole 11.22.44.0/24 2>/dev/null; sudo ip route del blackhole 11.22.45.0/24 2>/dev/null;
  $ sudo ip route del blackhole 2001:db8:4444::/48 2>/dev/null; sudo ip route del blackhole 2001:db8:5555::/48 2>/dev/null;
  $ BIRD_PID=$(cat /var/run/bird.pid)
  $ sudo kill $BIRD_PID 2>/dev/null
  $ ps aux | grep [b]ird | wc -l
  0
  $ sudo rm /etc/bird/bird.conf /var/log/bird.log 2>/dev/null

