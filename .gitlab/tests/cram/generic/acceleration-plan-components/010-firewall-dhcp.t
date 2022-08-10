Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Assure that fw3 is not installed and active:

  $ R "fw3"
  ash: fw3: not found
  [127]

  $ R "iptables -L INPUT | grep -c fw3"
  0
  [1]

Check that client is able to get new lease:

  $ sudo nmap --script broadcast-dhcp-discover -e $TESTBED_LAN_INTERFACE 2>&1 | egrep '(Server|Router|Subnet)' | sort
  |     Domain Name Server: 192.168.1.1
  |     Router: 192.168.1.1
  |     Server Identifier: 192.168.1.1
  |     Subnet Mask: 255.255.255.0

Remove dhcp-server rule:

  $ script --command "ssh -t root@$TARGET_LAN_IP ubus-cli Firewall.X_Prpl_Service.dhcp-server-" > /dev/null; sleep .5

Check that the firewall rule was actually removed:

  $ R "iptables -vnL INPUT_Services | grep :67 | cut -d ' ' -f 11,16,20,53 | sort"
  ACCEPT udp br-guest dpt:67

Check that client is unable to get new lease:

  $ sudo nmap --script broadcast-dhcp-discover -e $TESTBED_LAN_INTERFACE 2>&1 | egrep '(Server|Router|Subnet)'
  [1]

Add back firewall rule for dhcp-server access from LAN:

  $ printf "\
  > ubus-cli Firewall.X_Prpl_Service+{Alias='dhcp-server'}
  > ubus-cli Firewall.X_Prpl_Service.dhcp-server.Action=Accept
  > ubus-cli Firewall.X_Prpl_Service.dhcp-server.DestinationPort=67
  > ubus-cli Firewall.X_Prpl_Service.dhcp-server.IPVersion=4
  > ubus-cli Firewall.X_Prpl_Service.dhcp-server.Interface=br-lan
  > ubus-cli Firewall.X_Prpl_Service.dhcp-server.Protocol=UDP
  > ubus-cli Firewall.X_Prpl_Service.dhcp-server.Enable=1
  > " > /tmp/cram
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/cram)'" > /dev/null

Check that the firewall rule was actually created:

  $ R "iptables -vnL INPUT_Services | grep :67 | cut -d ' ' -f 11,16,20,53 | sort"
  ACCEPT udp br-guest dpt:67
  ACCEPT udp br-lan dpt:67

Check that client is able to get new lease again:

  $ sudo nmap --script broadcast-dhcp-discover -e $TESTBED_LAN_INTERFACE 2>&1 | egrep '(Server|Router|Subnet)' | sort
  |     Domain Name Server: 192.168.1.1
  |     Router: 192.168.1.1
  |     Server Identifier: 192.168.1.1
  |     Subnet Mask: 255.255.255.0
