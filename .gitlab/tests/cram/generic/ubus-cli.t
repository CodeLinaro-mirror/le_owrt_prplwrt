Check that we've correct DHCPv4 pools:

  $ script --command "ssh -t root@$TARGET_LAN_IP 'ubus-cli DHCPv4.Server.Pool.*.Alias?'" | grep Alias= | sort
  DHCPv4.Server.Pool.1.Alias="lan"\r (esc)
  DHCPv4.Server.Pool.1.Client.1.Alias="client-??:??:??:??:??:??"\r (esc) (glob)
  DHCPv4.Server.Pool.2.Alias="guest"\r (esc)
  DHCPv4.Server.Pool.3.Alias="lcm"\r (esc)

Check that we've correct DHCPv6 pools:

  $ script --command "ssh -t root@$TARGET_LAN_IP 'ubus-cli DHCPv6.Server.Pool.*.Alias?'" | grep Alias= | sort
  DHCPv6.Server.Pool.1.Alias="lan"\r (esc)
  DHCPv6.Server.Pool.2.Alias="guest"\r (esc)
  DHCPv6.Server.Pool.3.Alias="lcm"\r (esc)
