
Establish eBGP ipv6 session test:

Verify that a CPE device correctly establishes an eBGP ipv6 session with a
remote BGP Server.

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ TESTBED_IP6_A="fd00:1::2"
  $ DUT_IP6_A="fd00:1::1"

Enable BGP on CPE. Verify Device.Routing.X_PRPLWARE-COM_BGP.Enable = true.

  $ R "usp-cli Device.Routing.X_PRPLWARE-COM_BGP.Enable=true" | grep -Ev '^(>|$)' | grep '='
  Device.Routing.X_PRPLWARE-COM_BGP.Enable=1

Start BGP Server with configuration on isp-bgpd.

  $ sudo cp ${TESTDIR}/conf/routing/bgp_ipv6.frr.conf /etc/frr/frr.conf 2>&1 | grep -v "unable to resolve host"
  [1]
  $ sudo sed -i "s/DUT_IP6_A/$DUT_IP6_A/" /etc/frr/frr.conf > /dev/null 2>&1
  $ sudo /usr/lib/frr/frrinit.sh start > /dev/null 2>&1

Configure BGP on CPE for ipv6 session.

  $ R "ip -6 addr add ${DUT_IP6_A}/64 dev br-lan 2>/dev/null || true"
  $ sudo ip -6 addr add ${TESTBED_IP6_A}/64 dev ${TESTBED_LAN_INTERFACE} 2>/dev/null || true

  $ R "usp-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.+{Alias=\"cram-config1\",AS=\"65000\"}'" > /dev/null 2>&1
  $ R "usp-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.[Alias == \"cram-config1\"].RouterID=1.1.1.1'" > /dev/null 2>&1
  $ R "usp-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.[Alias == \"cram-config1\"].MaxPrefixes=5000'" > /dev/null 2>&1
  $ R "usp-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.[Alias == \"cram-config1\"].Timers.ConnectRetryInterval=120'" > /dev/null 2>&1
  $ R "usp-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.[Alias == \"cram-config1\"].Timers.HoldTime=90'" > /dev/null 2>&1
  $ R "usp-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.[Alias == \"cram-config1\"].Timers.KeepAlive=30'" > /dev/null 2>&1
  $ R "usp-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.[Alias == \"cram-config1\"].Neighbor.+{Alias=\"cram-nb1\"}'" > /dev/null 2>&1
  $ R "usp-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.[Alias == \"cram-config1\"].Neighbor.[Alias == \"cram-nb1\"].RemoteAddress='${TESTBED_IP6_A}''" > /dev/null 2>&1
  $ R "usp-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.[Alias == \"cram-config1\"].Neighbor.[Alias == \"cram-nb1\"].RemoteAS=65001'" > /dev/null 2>&1
  $ R "usp-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.[Alias == \"cram-config1\"].Neighbor.[Alias == \"cram-nb1\"].AFISAFI.+{Alias=\"cram-afisafi1\",Type=\"IPv6Unicast\"}'" > /dev/null 2>&1
  $ R "usp-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.[Alias == \"cram-config1\"].Neighbor.[Alias == \"cram-nb1\"].AFISAFI.[Alias == \"cram-afisafi1\"].Enable=true'" > /dev/null 2>&1
  $ R "usp-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.[Alias == \"cram-config1\"].Neighbor.[Alias == \"cram-nb1\"].ApplyFilters.DefaultExportDisposition=AcceptRoute'" > /dev/null 2>&1
  $ R "usp-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.[Alias == \"cram-config1\"].Neighbor.[Alias == \"cram-nb1\"].ApplyFilters.DefaultImportDisposition=AcceptRoute'" > /dev/null 2>&1
  $ R "usp-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.[Alias == \"cram-config1\"].Neighbor.[Alias == \"cram-nb1\"].Enable=true'" > /dev/null 2>&1
  $ R "usp-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.[Alias == \"cram-config1\"].Enable=true'" > /dev/null 2>&1

Verify eBGP session is established.

  $ . ${TESTDIR}/script_functions_routing.sh
  $ wait_bgp_session cram-config1 cram-nb1 Established

  $ R "usp-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.[Alias == \"cram-config1\"].Neighbor.[Alias == \"cram-nb1\"].LocalAddress?'" | grep -Ev '^(>|$)' | sed "s/$DUT_IP6_A/MATCHED/"
  Device.Routing.X_PRPLWARE-COM_BGP.Config.\d+.Neighbor.\d+.LocalAddress="MATCHED" (re)


  $ R "usp-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.[Alias == \"cram-config1\"].Neighbor.[Alias == \"cram-nb1\"].Identifier?'" | grep -Ev '^(>|$)'
  Device.Routing.X_PRPLWARE-COM_BGP.Config.\d+.Neighbor.\d+.Identifier="2.2.2.2" (re)

Remove the instances and other created by this test.

  $ R "ip -6 addr del ${DUT_IP6_A}/64 dev br-lan 2>/dev/null || true"
  $ sudo ip -6 addr del ${TESTBED_IP6_A}/64 dev ${TESTBED_LAN_INTERFACE} 2>/dev/null || true

  $ R "usp-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.[Alias==\"cram-config1\"].-'" > /dev/null

Stop the FRR daemon on the BGP server.

  $ sudo /usr/lib/frr/frrinit.sh stop > /dev/null 2>&1
