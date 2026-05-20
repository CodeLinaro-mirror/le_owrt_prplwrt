Setup test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh"
  $ C ${TESTDIR}/../lcm/script_functions.sh root@${TARGET_LAN_IP}:/tmp/script_functions.sh 2>/dev/null

Install PacketInterception Application container

  $ R "${S} && install_ctr --url_arch pi-app --uuid 'e2177328-bfcd-5591-8248-a5d759b52379' --ee generic --privileged true --moduleversion '1.0.0' --hostobject '[{Options = \"type=mount,create=dir,bind\", Source = \"/var/run/packetinterception\", Destination = \"/run/packetinterception\"}]'" > /dev/null

C-1: Check PacketInterception root datamodel and Status:

  $ R "ba-cli -l PacketInterception.Status?" | awk NF
  Disabled

C-2: Check that no iptables/ip6tables rules are being configured:

  $ R "iptables -t mangle -L INTERCEPT_Forward"
  Chain INTERCEPT_Forward (0 references)
  target     prot opt source               destination         

  $ R "ip6tables -t mangle -L INTERCEPT6_Forward"
  Chain INTERCEPT6_Forward (0 references)
  target     prot opt source               destination         

C-3: Enable interception of packets and check Status:

  $ R "ba-cli -l PacketInterception.Enable=True" | awk NF
  1

  $ R "ba-cli -l PacketInterception.Status?" | awk NF
  Enabled

C-4: Create dual VAS configuration (monitor + verdict sockets)

Add CommunicationConfig.Socket.1 with Event=true (monitor-only):

  $ R "ba-cli -l PacketInterception.CommunicationConfig.Socket.+{Alias=monitor_socket,Enable=True,URI=/var/run/packetinterception/monitor_sock,Event=True}"| awk NF
  monitor_socket

Add CommunicationConfig.Socket.2 with Event=false (verdict-capable):

  $ R "ba-cli -l PacketInterception.CommunicationConfig.Socket.+{Alias=verdict_socket,Enable=True,URI=/var/run/packetinterception/verdict_sock,Event=False}"| awk NF
  verdict_socket

Add a new PacketHandler with timeout and default verdict:

  $ R "ba-cli -l PacketInterception.PacketHandler.+{Alias=test_handler,Enable=True,Timeout=500,DefaultVerdict=ACCEPT}" | awk NF
  test_handler

Add Condition.1 (DNS IPv4):

  $ R "ba-cli -l PacketInterception.Condition.+{Alias=dns_ipv4,Protocol=UDP,DestPort=53,IPVersion=4,DestIP=8.8.8.8}" | awk NF
  dns_ipv4

Add Condition.2 (HTTP IPv6):

  $ R "ba-cli -l PacketInterception.Condition.+{Alias=tcp_ipv6,Protocol=TCP,DestPort=80,IPVersion=6}" | awk NF
  tcp_ipv6

Add Condition.3 (Local IPV4 traffic):

  $ R "ba-cli -l PacketInterception.Condition.+{Alias=local_ipv4_traffic,Protocol=TCP,IPVersion=4,SourceIP=127.0.0.1}" | awk NF
  local_ipv4_traffic

Add Interception.1 (OUTPUT route):

  $ R "ba-cli -l PacketInterception.Interception.+{Alias=test,Enable=True,TrafficRoute=OUTPUT}" | awk NF
  test

C-5: Add Bypass and Intercept Conditions with multi-VAS priority ordering

Add Bypass.1 (local traffic):

  $ R "ba-cli -l PacketInterception.Interception.test.Bypass.+{Alias=bypass_local,Enable=1,Condition=local_ipv4_traffic,Direction=reply}" | awk NF
  bypass_local

Add Intercept.1 (DNS IPv4) with dual VAS:

  $ R "ba-cli -l PacketInterception.Interception.test.Intercept.+{Alias=intercept_dns_ipv4,Enable=1,Condition=dns_ipv4,PacketHandler=test_handler,NumberOfPackets=1}" | awk NF
  intercept_dns_ipv4

Add monitor socket to Intercept.1 with Priority=1:

  $ R "ba-cli -l PacketInterception.Interception.test.Intercept.intercept_dns_ipv4.CommunicationConfig.+{Alias=monitor,Priority=1,CommunicationConfig=monitor_socket}" | awk NF
  monitor

Add verdict socket to Intercept.1 with Priority=2:

  $ R "ba-cli -l PacketInterception.Interception.test.Intercept.intercept_dns_ipv4.CommunicationConfig.+{Alias=verdict,Priority=2,CommunicationConfig=verdict_socket}" | awk NF
  verdict

Add Intercept.2 (TCP IPv6) with dual VAS:

  $ R "ba-cli -l PacketInterception.Interception.test.Intercept.+{Alias=intercept_tcp_ipv6,Enable=1,Condition=tcp_ipv6,PacketHandler=test_handler,NumberOfPackets=1}" | awk NF
  intercept_tcp_ipv6

Add monitor socket to Intercept.2 with Priority=1:

  $ R "ba-cli -l PacketInterception.Interception.test.Intercept.intercept_tcp_ipv6.CommunicationConfig.+{Alias=monitor,Priority=1,CommunicationConfig=monitor_socket}" | awk NF
  monitor

Add verdict socket to Intercept.2 with Priority=2:

  $ R "ba-cli -l PacketInterception.Interception.test.Intercept.intercept_tcp_ipv6.CommunicationConfig.+{Alias=verdict,Priority=2,CommunicationConfig=verdict_socket}" | awk NF
  verdict

Check that iptables rules are correctly configured:

  $ R "iptables -t mangle -L INTERCEPT_test"
  Chain INTERCEPT_test (1 references)
  target     prot opt source               destination         
  RETURN     tcp  --  anywhere             prplOS.lan           tcp
  NFQUEUE    udp  --  anywhere             dns.google           connbytes 0:1 connbytes mode packets connbytes direction original udp dpt:domain NFQUEUE num 3

Check that ip6tables rules are correctly configured:

  $ R "ip6tables -t mangle -L INTERCEPT6_test"
  Chain INTERCEPT6_test (1 references)
  target     prot opt source               destination         
  NFQUEUE    tcp  --  anywhere             anywhere             connbytes 0:1 connbytes mode packets connbytes direction original tcp dpt:www NFQUEUE num 4

C-6a: Traffic verification with Event=true (monitor-only socket)

  $ R "lxc-attach -n 5fc0d9e6-eb7b-5974-ab41-0b0183c7262c -- ba-cli -l EmbeddedFiltering.Socket='/run/packetinterception/monitor_sock'" > /dev/null

Verify monitor socket is connected:

  $ R "ba-cli -l PacketInterception.CommunicationConfig.Socket.monitor_socket.Connected?" | awk NF
  1

Send IPv4 DNS packet:

  $ R "nslookup -timeout=1 -retry=1 -type=A example.com. 8.8.8.8" | grep Server
  Server:		8.8.8.8

Check that packet was intercepted and accepted (DefaultVerdict used when no verdict socket connected):

  $ R "ba-cli -l PacketInterception.PacketHandler.test_handler.Stats.NrOfPacketsReceived?" | awk NF
  1

  $ R "ba-cli -l PacketInterception.PacketHandler.test_handler.Stats.NrOfPacketsAccepted?" | awk NF
  1

C-6b: Traffic verification with Event=false (verdict socket sends ACCEPT)

  $ R "lxc-attach -n 5fc0d9e6-eb7b-5974-ab41-0b0183c7262c -- ba-cli -l EmbeddedFiltering.Socket='/run/packetinterception/verdict_sock'" > /dev/null

  $ R "lxc-attach -n 5fc0d9e6-eb7b-5974-ab41-0b0183c7262c -- ba-cli -l EmbeddedFiltering.Verdict='Accept'" | awk NF
  Accept

Verify verdict socket is connected:

  $ R "ba-cli -l PacketInterception.CommunicationConfig.Socket.verdict_socket.Connected?" | awk NF
  1

Send IPv4 DNS packet:

  $ R nslookup -timeout=1 -retry=1 -type=A example.com. 8.8.8.8 | grep Server
  Server:		8.8.8.8

Check that packet was intercepted and accepted:

  $ R "ba-cli -l PacketInterception.PacketHandler.test_handler.Stats.NrOfPacketsReceived?" | awk NF
  2

  $ R "ba-cli -l PacketInterception.PacketHandler.test_handler.Stats.NrOfPacketsAccepted?" | awk NF
  2

  $ R "ba-cli -l PacketInterception.PacketHandler.test_handler.Stats.NrOfPacketsHandled?" | awk NF
  1

C-6c: Test negative verdict (Event=false with DROP)

  $ R "lxc-attach -n 5fc0d9e6-eb7b-5974-ab41-0b0183c7262c -- ba-cli -l EmbeddedFiltering.Verdict='Drop'" | awk NF
  Drop

Send IPv4 DNS packet (should be dropped):

  $ R nslookup -timeout=1 -retry=1 -type=A example.com. 8.8.8.8 > /dev/null 2>&1; echo $?
  1

Check that packet was intercepted and dropped:

  $ R "ba-cli -l PacketInterception.PacketHandler.test_handler.Stats.NrOfPacketsReceived?" | awk NF
  3

  $ R "ba-cli -l PacketInterception.PacketHandler.test_handler.Stats.NrOfPacketsHandled?" | awk NF
  2

  $ R "ba-cli -l PacketInterception.PacketHandler.test_handler.Stats.NrOfPacketsDropped?" | awk NF
  1

C-6d: Test timeout with DefaultVerdict (Event=false, no verdict sent)

  $ R "lxc-attach -n 5fc0d9e6-eb7b-5974-ab41-0b0183c7262c -- ba-cli -l EmbeddedFiltering.Verdict='Nothing'" | awk NF
  Nothing

Send IPv4 DNS packet (should timeout and use DefaultVerdict=ACCEPT):

  $ R nslookup -timeout=1 -retry=1 -type=A example.com. 8.8.8.8 | grep Server
  Server:		8.8.8.8

Check that packet used default verdict after timeout:

  $ R "ba-cli -l PacketInterception.PacketHandler.test_handler.Stats.NrOfPacketsReceived?" | awk NF
  4

  $ R "ba-cli -l PacketInterception.PacketHandler.test_handler.Stats.NrOfPacketsTimedout?" | awk NF
  1

  $ R "ba-cli -l PacketInterception.PacketHandler.test_handler.Stats.NrOfPacketsAccepted?" | awk NF
  3

C-7: Persistence and restart coverage

Verify current configuration before restart:

  $ R "/etc/init.d/packet-interception restart"

Verify configuration persisted after restart:

  $ R "ba-cli -l PacketInterception.CommunicationConfig.Socket.monitor_socket.Event?" | awk NF
  1

  $ R "ba-cli -l PacketInterception.CommunicationConfig.Socket.verdict_socket.Event?" | awk NF
  0

  $ R "ba-cli -l PacketInterception.Interception.test.Intercept.intercept_dns_ipv4.CommunicationConfig.monitor.Priority?" | awk NF
  1

  $ R "ba-cli -l PacketInterception.Interception.test.Intercept.intercept_dns_ipv4.CommunicationConfig.verdict.Priority?" | awk NF
  2

C-8: Disable interception of packets and verify cleanup:

  $ R "ba-cli -l PacketInterception.Enable=False" | awk NF
  0

Check that no iptables interception is configured:

  $ R "iptables -t mangle -L INTERCEPT_test"
  Chain INTERCEPT_test (0 references)
  target     prot opt source               destination         

Check that no ip6tables interception is configured:

  $ R "ip6tables -t mangle -L INTERCEPT6_test"
  Chain INTERCEPT6_test (0 references)
  target     prot opt source               destination         

Uninstall PacketInterception Application container

  $ R "${S} && uninstall_ctr --uuid e2177328-bfcd-5591-8248-a5d759b52379" > /dev/null 2>&1

Cleanup test environment:

  $ R "rm -f /tmp/script_functions.sh"         
