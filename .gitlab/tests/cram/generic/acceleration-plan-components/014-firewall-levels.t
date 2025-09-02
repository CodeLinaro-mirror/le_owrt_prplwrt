Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Set firewall level to High:

  $ script --command "ssh -t root@$TARGET_LAN_IP ba-cli Firewall.PolicyLevel='Firewall.Level.High'" > /dev/null; sleep 1

Check that it is set properly:

  $ R "iptables -L FORWARD_Firewall -nv | grep Low | grep $DUT_WAN_INTERFACE"
      0     0 FORWARD_L_Low  0    -- * br-lcm * 0.0.0.0/0 * 0.0.0.0/0 * (glob)

  $ R "iptables -L FORWARD_Firewall -nv | grep High | grep $DUT_WAN_INTERFACE"
      0     0 FORWARD_L_High  0    -- * br-lan * 0.0.0.0/0 * 0.0.0.0/0 * (glob)
      0     0 FORWARD_L_High_Out  0    -- * br-lan * 0.0.0.0/0 * 0.0.0.0/0 * (glob)
      0     0 FORWARD_L_High  0    -- * br-guest * 0.0.0.0/0 * 0.0.0.0/0 * (glob)
      0     0 FORWARD_L_High_Out  0    -- * br-guest * 0.0.0.0/0 * 0.0.0.0/0 * (glob)

Set firewall level to Low:

  $ script --command "ssh -t root@$TARGET_LAN_IP ba-cli Firewall.PolicyLevel='Firewall.Level.Low'" > /dev/null; sleep 1

Check that it is set properly:

  $ R "iptables -L FORWARD_Firewall -nv | grep Low | grep $DUT_WAN_INTERFACE"
      0     0 FORWARD_L_Low  0    -- * br-lan * 0.0.0.0/0 * 0.0.0.0/0 * (glob)
      0     0 FORWARD_L_Low  0    -- * br-guest * 0.0.0.0/0 * 0.0.0.0/0 * (glob)
      0     0 FORWARD_L_Low  0    -- * br-lcm * 0.0.0.0/0 * 0.0.0.0/0 * (glob)

  $ R "iptables -L FORWARD_Firewall -nv | grep High | grep $DUT_WAN_INTERFACE"
  [1]
