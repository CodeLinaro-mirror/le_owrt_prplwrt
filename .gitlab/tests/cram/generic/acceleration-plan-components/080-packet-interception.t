Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check PacketInterception root datamodel:

  $ R "ubus -S call PacketInterception _get"
  {"PacketInterception.":{"CommunicationConfigNumberOfEntries":1,"ConditionNumberOfEntries":1,"Status":"Disabled","InterceptionNumberOfEntries":1,"Enable":false,"SupportedCommControllers":"socket","PacketHandlerNumberOfEntries":1,"SupportedParsers":""}}

Check that no interception is being configured:

  $ R "iptables -t mangle -L INTERCEPT_Forward"
  Chain INTERCEPT_Forward (0 references)
  target     prot opt source               destination         

Enable interception of DNS packets:

  $ R "ubus -S call PacketInterception _set '{\"parameters\":{\"Enable\":True}}'" ; sleep 2
  {"PacketInterception.":{"Enable":true}}

Check that interception is configured properly:

  $ R "iptables -t mangle -L INTERCEPT_Forward"
  Chain INTERCEPT_Forward (1 references)
  target     prot opt source               destination         
  NFQUEUE    udp  --  anywhere             anywhere             udp dpt:domain NFQUEUE num 2

Disable interception of DNS packets:

  $ R "ubus -S call PacketInterception _set '{\"parameters\":{\"Enable\":False}}'" ; sleep 2
  {"PacketInterception.":{"Enable":false}}

Check that no interception is being configured:

  $ R "iptables -t mangle -L INTERCEPT_Forward"
  Chain INTERCEPT_Forward (0 references)
  target     prot opt source               destination         
