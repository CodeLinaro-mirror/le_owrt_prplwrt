Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that HTTP from LAN is allowed by default:

  $ R "iptables -L INPUT_Services -v -n | grep 'br-lan.*dpt:443$'"
    * ACCEPT     tcp  --  br-lan *       0.0.0.0/0            0.0.0.0/0            tcp dpt:443 (glob)

Disable firewall rule for HTTP access from LAN:

  $ script --command "ssh -t root@$TARGET_LAN_IP ubus-cli Firewall.Service.[DestPort=='8080'].Enable=0" > /dev/null; sleep .5

Check that HTTP from LAN is forbidden:

  $ R "iptables -L INPUT_Services -v -n | grep 'br-lan.*dpt:443$'"
  [1]

Enable firewall rule for HTTP access from LAN:

  $ script --command "ssh -t root@$TARGET_LAN_IP ubus-cli Firewall.Service.[DestPort=='8080'].Enable=1" > /dev/null; sleep .5

Check that HTTP from LAN is allowed again:

  $ R "iptables -L INPUT_Services -v -n | grep 'br-lan.*dpt:443$'"
    * ACCEPT     tcp  --  br-lan *       0.0.0.0/0            0.0.0.0/0            tcp dpt:443 (glob)
