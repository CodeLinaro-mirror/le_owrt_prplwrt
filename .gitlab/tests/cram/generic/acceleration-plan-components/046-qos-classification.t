Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Create QoS.Classification to disable HW offloading for packets with destination address 8.8.8.8
  $ R "ubus-cli 'QoS.Classification.+{Alias = \"ipv4_no_hw_offload\", DestIP = 8.8.8.8, Enable = 1, IPVersion = 4, X_PRPLWARE-COM_DoNotOffload = 1}'" > /dev/null 2>&1 
Check that a rule is created in the mangle table to mark traffic to 8.8.8.8 with skb mark 0x20
  $ R "iptables -t mangle -L -n | grep 0x20"
  MARK       0    --  0.0.0.0/0            8.8.8.8              MARK or 0x20

Delete the QoS.Classification to disable HW offloading
  $ R "ba-cli 'QoS.Classification.[Alias == \"ipv4_no_hw_offload\"].-'" > /dev/null 2>&1

Check that the firewall rule in the mangle table is removed
  $ R "iptables -t mangle -L -n | grep 0x20"
  [1]


Create QoS.Classification and Routing.Policy to redirect packets with destination 8.8.8.8 to the table Device.Routing.Router.1
  $ R "ubus-cli 'QoS.Classification.+{Alias = \"ipv4_forw_policy\", DestIP = 8.8.8.8, Enable = 1, IPVersion = 4, ForwardingPolicy = 16128}'" > /dev/null 2>&1
  $ R "ba-cli 'Routing.Policy.+{Alias = \"ipv4_forw_policy\", Priority = 500, ForwardingPolicy = 16128, RouterRef = \"Device.Routing.Router.1\", Enable = 1}'" > /dev/null 2>&1
 
Check that a rule is created in the mangle table to mark traffic to 8.8.8.8 with skb mark 0x3f00/0x3fc0
  $ R "iptables -t mangle -L -n | grep 0x3fc0"
  MARK       0    --  0.0.0.0/0            8.8.8.8              MARK xset 0x3f00/0x3fc0

Check that a routing policy is created for traffic marked with 0x3f00/0x3fc0
  $ R "ip rule | grep 0x3fc0"
  500:	from all fwmark 0x3f00/0x3fc0 lookup main

Delete the QoS.Classification and Routing.Policy
  $ R "ba-cli 'QoS.Classification.[Alias == \"ipv4_forw_policy\"].-'" > /dev/null 2>&1
  $ R "ba-cli 'Routing.Policy.[Alias == \"ipv4_forw_policy\"].-'" > /dev/null 2>&1

Check that the created firewall rule and routing policy are deleted in the LL API 
  $ R "iptables -t mangle -L -n | grep 0x3fc0"
  [1]

  $ R "ip rule | grep 500"
  [1]

