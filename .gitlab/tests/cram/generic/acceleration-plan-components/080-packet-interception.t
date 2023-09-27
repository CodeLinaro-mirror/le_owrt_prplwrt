Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check PacketInterception root datamodel:

  $ R "ubus -S call PacketInterception _get"
  {"PacketInterception.":{"InterceptionNumberOfEntries":1,"Enable":true,"PacketHandlerNumberOfEntries":1,"ConditionNumberOfEntries":3,"Status":"Enabled"}}
  {}
  {"amxd-error-code":0}

Check that interception is configured properly:

  $ R "iptables -t mangle -L INTERCEPT_Forward"
  Chain INTERCEPT_Forward (1 references)
  target     prot opt source               destination         
  NFQUEUE    udp  --  anywhere             anywhere             udp dpt:domain NFQUEUE num 2
  NFQUEUE    tcp  --  anywhere             anywhere             tcp dpt:www NFQUEUE num 3
  NFQUEUE    tcp  --  anywhere             anywhere             tcp dpt:https NFQUEUE num 4

Disable interception:

  $ R "ubus -S call PacketInterception _set '{\"parameters\":{\"Enable\":False}}'" ; sleep 2
  {"PacketInterception.":{"Enable":false}}
  {}
  {"amxd-error-code":0}

Check that no interception is being configured:

  $ R "iptables -t mangle -L INTERCEPT_Forward"
  Chain INTERCEPT_Forward (0 references)
  target     prot opt source               destination         

Enable interception again:

  $ R "ubus -S call PacketInterception _set '{\"parameters\":{\"Enable\":True}}'" ; sleep 2
  {"PacketInterception.":{"Enable":true}}
  {}
  {"amxd-error-code":0}

Check that interception is configured properly:

  $ R "iptables -t mangle -L INTERCEPT_Forward"
  Chain INTERCEPT_Forward (1 references)
  target     prot opt source               destination         
  NFQUEUE    udp  --  anywhere             anywhere             udp dpt:domain NFQUEUE num 2
  NFQUEUE    tcp  --  anywhere             anywhere             tcp dpt:www NFQUEUE num 3
  NFQUEUE    tcp  --  anywhere             anywhere             tcp dpt:https NFQUEUE num 4
