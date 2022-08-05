Check that we've correct DHCPv4 pools:

  $ script --command "ssh -t root@$TARGET_LAN_IP 'ubus-cli DHCPv4.Server.Pool.*.Alias?'" | grep Alias= | sort
  \x1b[32;1mDHCPv4.Server.Pool.1.\x1b[0mAlias="lan"\r (esc)
  \x1b[32;1mDHCPv4.Server.Pool.1.Client.1.\x1b[0mAlias="client-??:??:??:??:??:??"\r (esc) (glob)
  \x1b[32;1mDHCPv4.Server.Pool.2.\x1b[0mAlias="guest"\r (esc)

Check that we've correct DHCPv6 pools:

  $ script --command "ssh -t root@$TARGET_LAN_IP 'ubus-cli DHCPv6.Server.Pool.*.Alias?'" | grep Alias= | sort
  \x1b[32;1mDHCPv6.Server.Pool.1.\x1b[0mAlias="lan"\r (esc)
  \x1b[32;1mDHCPv6.Server.Pool.2.\x1b[0mAlias="guest"\r (esc)
