Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check PacketInterception root datamodel and Status:

  $ R "ba-cli -l PacketInterception.Status?" | awk NF
  Disabled

Check that no iptables rules are being configured:

  $ R "iptables -t mangle -L INTERCEPT_Forward"
  Chain INTERCEPT_Forward (0 references)
  target     prot opt source               destination         

Enable interception of packets and check Status:

  $ R "ba-cli -l PacketInterception.Enable=True" | awk NF
  1

  $ R "ba-cli -l PacketInterception.Status?" | awk NF
  Enabled

Add a new CommunicationConfig

  $ R "ubus -S call PacketInterception.CommunicationConfig.Socket _add '{\"parameters\":{\"Alias\":\"test_socket\",\"Enable\":True,\"URI\":\"/var/run/packetinterception/test_sock\"}}'" ; sleep 2
  {"object":"PacketInterception.CommunicationConfig.Socket.test_socket.","index":1,"name":"test_socket","parameters":{"Alias":"test_socket"},"path":"PacketInterception.CommunicationConfig.Socket.1."}
  {}
  {"amxd-error-code":0}

Add a new Intercept

  $ R "ubus -S call PacketInterception.Interception.3.Intercept _add '{\"parameters\":{\"Alias\":\"test\",\"Enable\":True,\"Condition\":\"DNS\", \"NumberOfPackets\":1, \"PacketHandler\":\"default_handler\"}}'" ; sleep 2
  {"object":"PacketInterception.Interception.Output.Intercept.test.","index":2,"name":"test","parameters":{"Alias":"test"},"path":"PacketInterception.Interception.3.Intercept.2."}
  {}
  {"amxd-error-code":0}

Add the new CommunicationConfig to the Intercept

  $ R "ubus -S call PacketInterception.Interception.3.Intercept.2.CommunicationConfig _add '{\"parameters\":{\"Alias\":\"test_socket\",\"Priority\":1,\"CommunicationConfig\":\"test_socket\"}}'" ; sleep 2
  {"object":"PacketInterception.Interception.Output.Intercept.test.CommunicationConfig.test_socket.","index":1,"name":"test_socket","parameters":{"Alias":"test_socket"},"path":"PacketInterception.Interception.3.Intercept.2.CommunicationConfig.1."}
  {}
  {"amxd-error-code":0}

Check that iptables rule are correct

  $ R "iptables -t mangle -L INTERCEPT_Output"
  Chain INTERCEPT_Output (1 references)
  target     prot opt source               destination         
  RETURN     all  --  anywhere             prplOS.lan          
  NFQUEUE    udp  --  anywhere             anywhere             connbytes 0:1 connbytes mode packets connbytes direction original udp dpt:domain NFQUEUE num 2

Send out one DNS packet

  $ R nslookup -type=A example.com. 8.8.8.8 | grep Server
  Server:		8.8.8.8

Check that packet was intercepted using the Stats

  $ R "ba-cli -l PacketInterception.PacketHandler.1.Stats.NrOfPacketsReceived?" | awk NF
  1

  $ R "ba-cli -l PacketInterception.PacketHandler.1.Stats.NrOfPacketsAccepted?" | awk NF
  1

Disable interception of packets:

  $ R "ba-cli -l PacketInterception.Enable=False" | awk NF
  0

Check that no interception is being configured:

  $ R "iptables -t mangle -L INTERCEPT_Output"
  Chain INTERCEPT_Output (0 references)
  target     prot opt source               destination         
