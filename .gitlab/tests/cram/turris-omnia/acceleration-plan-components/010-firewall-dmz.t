Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Add DMZ host:

  $ printf "\
  > ubus-cli Firewall.X_Prpl_DMZ+{Alias='test'}
  > ubus-cli Firewall.X_Prpl_DMZ.test.SourceInterface=eth2
  > ubus-cli Firewall.X_Prpl_DMZ.test.DestinationIPAddress=192.168.1.186
  > ubus-cli Firewall.X_Prpl_DMZ.test.Enable=1
  > " > /tmp/cram
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/cram)'" > /dev/null; sleep 1

Check that correct firewall rules were created:

  $ R "iptables -t nat -L POSTROUTING_DMZ | grep 186 | sort"
  SNAT       all  --  prplOS.lan           192.168.1.186        to:10.0.0.2

  $ R "iptables -t nat -L PREROUTING_DMZ | grep 186 | sort"
  DNAT       all  --  anywhere             10.0.0.2             to:192.168.1.186

  $ R "iptables -L FORWARD_DMZ | grep 186 | sort"
  ACCEPT     all  --  192.168.1.186        anywhere            
  ACCEPT     all  --  anywhere             192.168.1.186       

Remove DMZ host:

  $ script --command "ssh -t root@$TARGET_LAN_IP ubus-cli Firewall.X_Prpl_DMZ.test-" > /dev/null; sleep 1

Check that firewall rules are gone:

  $ R "iptables -t nat -L POSTROUTING_DMZ | grep 186 | sort"
  $ R "iptables -t nat -L PREROUTING_DMZ | grep 186 | sort"
  $ R "iptables -L FORWARD_DMZ | grep 186 | sort"
