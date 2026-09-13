Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Warm up the DHCP path, the first probe of a session goes unanswered:

  $ sudo nmap --script broadcast-dhcp-discover --script-args broadcast-dhcp-discover.timeout=3 -e $TESTBED_LAN_INTERFACE > /dev/null 2>&1

Check that client is able to get new lease:

  $ sudo nmap --script broadcast-dhcp-discover -e $TESTBED_LAN_INTERFACE 2>&1 | egrep '(Server|Router|Subnet)' | sort
  |     Domain Name Server: 192.168.1.1
  |     Server Identifier: 192.168.1.1
  |     Subnet Mask: 255.255.255.0
  |_    Router: 192.168.1.1

Remove cpe-dhcpv4s-lan rule:

  $ R "ba-cli 'Firewall.Service.[DestPort==67 && \"IP.Interface.3\" in Interface].-'" > /dev/null; sleep .5
Check that the firewall rule was actually removed:

  $ R "iptables -vnL INPUT_Services | grep :67 | awk '/ACCEPT.*udp/ {print \$3, \$4, \$6, \$11}' | sort"
  ACCEPT 17 br-guest dpt:67
  ACCEPT 17 br-lcm dpt:67

Check that client is unable to get new lease:

  $ testbed_mac="$(cat /sys/class/net/$TESTBED_LAN_INTERFACE/address)"
  $ sudo timeout 20 tcpdump -c 1 -l -n -i $TESTBED_LAN_INTERFACE "ether src $testbed_mac and udp port 67 and udp[36:4] = 0xdeadc0de and udp[40:2] = 0xcafe" > /tmp/tcpdump-dhcp-discover 2> /dev/null &
  $ sleep 1

  $ sudo nmap --script broadcast-dhcp-discover -e $TESTBED_LAN_INTERFACE 2>&1 | egrep '(Server|Router|Subnet)'
  [1]

  $ grep -c 'BOOTP/DHCP, Request from de:ad:c0:de:ca:fe' /tmp/tcpdump-dhcp-discover
  1

Add back firewall rule for cpe-dhcpv4s-lan access from LAN:

  $ cat > /tmp/dhcpv4s-lan-config <<EOF
  > ba-cli 'Firewall.Service+{Alias="cpe-dhcpv4s-lan"}'
  > ba-cli 'Firewall.Service.cpe-dhcpv4s-lan.Action=Accept'
  > ba-cli 'Firewall.Service.cpe-dhcpv4s-lan.DestPort=67'
  > ba-cli 'Firewall.Service.cpe-dhcpv4s-lan.IPVersion=4'
  > ba-cli 'Firewall.Service.cpe-dhcpv4s-lan.Interface=Device.IP.Interface.3'
  > ba-cli 'Firewall.Service.cpe-dhcpv4s-lan.Protocol=17'
  > ba-cli 'Firewall.Service.cpe-dhcpv4s-lan.Enable=1'
  > EOF
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/dhcpv4s-lan-config)'" > /dev/null

Check that the firewall rule was actually created:

  $ R "iptables -vnL INPUT_Services | grep :67 | awk '/ACCEPT.*udp/ {print \$3, \$4, \$6, \$11}' | sort"
  ACCEPT 17 br-guest dpt:67
  ACCEPT 17 br-lan dpt:67
  ACCEPT 17 br-lcm dpt:67

Check that client is able to get new lease again:

  $ sudo nmap --script broadcast-dhcp-discover -e $TESTBED_LAN_INTERFACE 2>&1 | egrep '(Server|Router|Subnet)' | sort
  |     Domain Name Server: 192.168.1.1
  |     Server Identifier: 192.168.1.1
  |     Subnet Mask: 255.255.255.0
  |_    Router: 192.168.1.1
