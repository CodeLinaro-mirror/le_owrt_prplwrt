Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check PacketInterception root datamodel:

  $ R "ba-cli -l 'PacketInterception.InterceptionNumberOfEntries?;PacketInterception.Enable?;PacketInterception.PacketHandlerNumberOfEntries?;PacketInterception.ConditionNumberOfEntries?;PacketInterception.Status?' | sort"
  1
  3
  5
  Disabled
  false

Check that no interception is being configured:

  $ R "iptables -t mangle -L INTERCEPT_Forward"
  Chain INTERCEPT_Forward (0 references)
  target     prot opt source               destination         

Enable interception of packets:

  $ R "ba-cli 'PacketInterception.Enable=true' > /dev/null" ; sleep 2

Check that interception is configured properly:

  $ R "iptables -t mangle -L INTERCEPT_Forward"
  Chain INTERCEPT_Forward (1 references)
  target     prot opt source               destination         
  NFQUEUE    udp  --  anywhere             anywhere             connbytes 0:1 connbytes mode packets connbytes direction original udp dpt:domain NFQUEUE num 2
  NFQUEUE    tcp  --  anywhere             anywhere             connbytes 0:4 connbytes mode packets connbytes direction both tcp dpt:www NFQUEUE num 3
  NFQUEUE    tcp  --  anywhere             anywhere             connbytes 0:4 connbytes mode packets connbytes direction both tcp spt:www NFQUEUE num 3
  NFQUEUE    tcp  --  anywhere             anywhere             connbytes 0:6 connbytes mode packets connbytes direction both tcp dpt:https NFQUEUE num 4
  NFQUEUE    tcp  --  anywhere             anywhere             connbytes 0:6 connbytes mode packets connbytes direction both tcp spt:https NFQUEUE num 4
  NFQUEUE    udp  --  anywhere             anywhere             connbytes 0:1 connbytes mode packets connbytes direction original udp dpt:https NFQUEUE num 5

Disable interception of packets:

  $ R "ba-cli 'PacketInterception.Enable=false' > /dev/null" ; sleep 2

Check that no interception is being configured:

  $ R "iptables -t mangle -L INTERCEPT_Forward"
  Chain INTERCEPT_Forward (0 references)
  target     prot opt source               destination         
