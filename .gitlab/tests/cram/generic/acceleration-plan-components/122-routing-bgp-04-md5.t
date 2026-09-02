
Key Chain Authentication MD5 test:

Verify that a BGP session can be established between CPE and BGP Peer when MD5
authentication is configured on both sides using matching key chain and password.
Verify that session fails to establish when mismatched password is used.

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Enable BGP on CPE. Verify Device.Routing.X_PRPLWARE-COM_BGP.Enable = true.

  $ R "ba-cli Device.Routing.X_PRPLWARE-COM_BGP.Enable=true" | grep -Ev '^(>|$)' | grep '='
  Device.Routing.X_PRPLWARE-COM_BGP.Enable=1

Start BGP Server with MD5 authentication configured on isp-bgpd.

  $ sudo cp ${TESTDIR}/conf/routing/bgp_cp.frr.conf /etc/frr/frr.conf 2>&1 | grep -v "unable to resolve host"
  [1]
  $ sudo /usr/lib/frr/frrinit.sh start > /dev/null 2>&1

Configure CPE BGP instance with MD5 secure session.

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
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.Enable=true'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Enable=true'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.AFISAFI.cram-afisafi1.Enable=true'" > /dev/null 2>&1

Security parameters MD5.

  $ R "ba-cli Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.Transport.SecureSession.MD5.Password=mysecretpassword" > /dev/null 2>&1
  $ R "ba-cli Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.Transport.SecureSession.Enable=true" > /dev/null 2>&1
  $ R "ba-cli Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.ApplyFilters.DefaultImportDisposition=AcceptRoute" > /dev/null 2>&1
  $ R "ba-cli Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.ApplyFilters.DefaultExportDisposition=RejectRoute" > /dev/null 2>&1
  $ R "ba-cli Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.Enable=true" > /dev/null 2>&1
  $ R "ba-cli Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Enable=true" > /dev/null 2>&1

Verify BGP Instance 1 Status is Enabled.

  $ R "ba-cli Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Status?" | grep -Ev '^(>|$)' | grep '='
  Device.Routing.X_PRPLWARE-COM_BGP.Config.\d+.Status="Enabled" (re)

Verify Neighbor.1 session is Established with MD5 authentication.

  $ . ${TESTDIR}/script_functions_routing.sh
  $ wait_bgp_session cram-config1 cram-nb1 Established

Verify MD5 session is active on BGP Server side (FRRouting).

  $ sudo vtysh -c "show ip bgp neighbors" 2>&1 | grep Authent
  Peer Authentication Enabled

Verify SecureSession is enabled on CPE.

  $ R "ba-cli Device.Routing.X_PRPLWARE-COM_BGP.Config.cram-config1.Neighbor.cram-nb1.Transport.SecureSession.Enable?" | grep -Ev '^(>|$)' | grep '='
  Device.Routing.X_PRPLWARE-COM_BGP.Config.\d+.Neighbor.\d+.Transport.SecureSession.Enable=1 (re)

Now verify session fails with mismatched password - update BGP Peer with wrong
password on isp-bgpd.

  $ sudo cp ${TESTDIR}/conf/routing/bgp_wp.frr.conf /etc/frr/frr.conf 2>&1 | grep -v "unable to resolve host"
  [1]
  $ sudo /usr/lib/frr/frrinit.sh restart > /dev/null 2>&1

Wait and verify BGP session is no longer Established.

  $ wait_bgp_session cram-config1 cram-nb1 Connect

Restore correct password on BGP Peer on isp-bgpd.

  $ sudo cp ${TESTDIR}/conf/routing/bgp_cp.frr.conf /etc/frr/frr.conf 2>&1 | grep -v "unable to resolve host"
  [1]
  $ sudo /usr/lib/frr/frrinit.sh restart > /dev/null 2>&1

Wait and verify BGP session is re-established after password is restored.

  $ wait_bgp_session cram-config1 cram-nb1 Established

Remove the instances created by this test.

  $ R "ba-cli 'Device.Routing.X_PRPLWARE-COM_BGP.Config.[Alias==\"cram-config1\"].-'" > /dev/null

Stop the FRR daemon on the BGP server.

  $ sudo /usr/lib/frr/frrinit.sh stop > /dev/null 2>&1
