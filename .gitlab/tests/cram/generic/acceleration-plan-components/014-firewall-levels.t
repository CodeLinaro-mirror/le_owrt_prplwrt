Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Set firewall level to High:

  $ script --command "ssh -t root@$TARGET_LAN_IP ubus-cli Firewall.PolicyLevel='Firewall.Level.High'" > /dev/null; sleep 1

Check that it is set properly:

  $ R "iptables -L FORWARD_Firewall -nv | grep Low"
      0     0 FORWARD_L_Low  all  --  $DUT_WAN_INTERFACE    br-lcm  0.0.0.0/0            0.0.0.0/0           
      0     0 FORWARD_L_Low  all  --  br-lan br-lcm  0.0.0.0/0            0.0.0.0/0           

  $ R "iptables -L FORWARD_Firewall -nv | grep High"
      0     0 FORWARD_L_High  all  --  $DUT_WAN_INTERFACE    br-lan  0.0.0.0/0            0.0.0.0/0           
      0     0 FORWARD_L_High_Out  all  --  br-lan $DUT_WAN_INTERFACE     0.0.0.0/0            0.0.0.0/0           

Set firewall level to Low:

  $ script --command "ssh -t root@$TARGET_LAN_IP ubus-cli Firewall.PolicyLevel='Firewall.Level.Low'" > /dev/null; sleep 1

Check that it is set properly:

  $ R "iptables -L FORWARD_Firewall -nv | grep Low"
      0     0 FORWARD_L_Low  all  --  $DUT_WAN_INTERFACE    br-lan  0.0.0.0/0            0.0.0.0/0           
      0     0 FORWARD_L_Low  all  --  $DUT_WAN_INTERFACE    br-lcm  0.0.0.0/0            0.0.0.0/0           
      0     0 FORWARD_L_Low  all  --  br-lan br-lcm  0.0.0.0/0            0.0.0.0/0           

  $ R "iptables -L FORWARD_Firewall -nv | grep High"
  [1]
