Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"


Create new set objects:
  $ (R "ba-cli Firewall.Set.*.-") >> /dev/null

  $ (R "ba-cli Firewall.Set.+{Enable=1, Type="IPAddresses"}") >> /dev/null
  $ (R "ba-cli Firewall.Set.+{Enable=1, Type="IPAddresses", IPVersion=4}") >> /dev/null
  $ (R "ba-cli Firewall.Set.+{Enable=1, Type="MACAddresses"}") >> /dev/null
  $ (R "ba-cli Firewall.Set.+{Enable=1, Type="Ports"}") >> /dev/null

  $ (R ipset list)
  Name: cpe-Set-[0-9]* (re)
  Type: hash:net
  Revision: [0-9]* (re)
  Header: family inet6 .* (re)
  Size in memory: [0-9]* (re)
  References: 0
  Number of entries: 0
  Members:
  
  Name: cpe-Set-[0-9]* (re)
  Type: hash:net
  Revision: [0-9]* (re)
  Header: family inet .* (re)
  Size in memory: [0-9]* (re)
  References: 0
  Number of entries: 0
  Members:
  
  Name: cpe-Set-[0-9]* (re)
  Type: hash:mac
  Revision: [0-9]* (re)
  Header: .* (re)
  Size in memory: [0-9]* (re)
  References: 0
  Number of entries: 0
  Members:
  
  Name: cpe-Set-[0-9]* (re)
  Type: bitmap:port
  Revision: [0-9]* (re)
  Header: .* (re)
  Size in memory: [0-9]* (re)
  References: 0
  Number of entries: 0
  Members:


Create new set and rule objects:
  $ (R "ba-cli Firewall.Set.*.-") >> /dev/null
  $ (R "ba-cli Firewall.Set.+{Alias=\"testrule\", Enable=1, Type=\"IPAddresses\", IPVersion=4}") >> /dev/null
  $ (R "ba-cli 'Firewall.Set.testrule.Rule.+{IPAddressList=\"192.168.1.6,192.168.1.8\"}'") >> /dev/null
  $ (R "ba-cli Firewall.Set.testrule.Rule.+{IPAddressList='10.10.10.10'}") >> /dev/null

  $ (R ipset list) | sort
  10.10.10.10
  192.168.1.6
  192.168.1.8
  Header: family inet .* (re)
  Members:
  Name: testrule
  Number of entries: 3
  References: 0
  Revision: [0-9]* (re)
  Size in memory: [0-9]* (re)
  Type: hash:net


Utilize set in firewall rule:
  $ (R "ba-cli Firewall.Set.+{Alias=\"fwrule\", Enable=1, Type=\"IPAddresses\", IPVersion=4}") >> /dev/null
  $ (R "ba-cli Firewall.Chain.2.Rule.1.SourceMatchSet=\"Firewall.Set.fwrule.\"") >> /dev/null

  $ (R "ba-cli Firewall.Chain.2.Rule.1.Status?") | sed 's|[>,]||g'
   Firewall.Chain.2.Rule.1.Status?
  Firewall.Chain.2.Rule.1.Status="Enabled"
  

  $ (R "iptables -L FORWARD_L_Low") | sed 's|[0123456789,]||g'
  Chain FORWARD_L_Low ( references)
  target     prot opt source               destination         
  ACCEPT     all  --  anywhere             anywhere             match-set fwrule src

  $ (R "ba-cli Firewall.Chain.2.Rule.1.SourceMatchSet=\"\"") >> /dev/null


Not enabled set in firewall rule:
  $ (R "ba-cli Firewall.Set.*.-") >> /dev/null
  $ (R "ba-cli Firewall.Set.+{Alias=\"notenabled\", Enable=0, Type=\"IPAddresses\", IPVersion=4}") >> /dev/null
  $ (R "ba-cli Firewall.Chain.2.Rule.1.SourceMatchSet=\"Firewall.Set.notenabled.\"") >> /dev/null
  $ (R "ba-cli Firewall.Chain.2.Rule.1.Status?") | sed 's|[>,]||g'
   Firewall.Chain.2.Rule.1.Status?
  Firewall.Chain.2.Rule.1.Status="Error_Misconfigured"
  

  $ (R "ba-cli Firewall.Chain.2.Rule.1.SourceMatchSet=\"\"") >> /dev/null

Exclude set parameter:
  $ (R "ba-cli Firewall.Set.+{Alias=\"exclude\", Enable=1, Type=\"IPAddresses\", IPVersion=4}") >> /dev/null
  $ (R "ba-cli Firewall.Chain.2.Rule.1.SourceMatchSetExclude=\"Firewall.Set.exclude.\"") >> /dev/null

  $ (R "ba-cli Firewall.Chain.2.Rule.1.Status?") | sed 's|[>,]||g'
   Firewall.Chain.2.Rule.1.Status?
  Firewall.Chain.2.Rule.1.Status="Enabled"
  
  $ (R "iptables -L FORWARD_L_Low") | sed 's|[0123456789,]||g'
  Chain FORWARD_L_Low ( references)
  target     prot opt source               destination         
  ACCEPT     all  --  anywhere             anywhere             ! match-set exclude src


  $ (R "ba-cli Firewall.Chain.2.Rule.1.SourceMatchSetExclude=\"\"") >> /dev/null