Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Set one IPv4 as WINSServers:

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.lan.WINSServers=\"192.168.1.1\"'" | grep -Ev '^>|^$'
  Device.DHCPv4.Server.Pool.1.
  Device.DHCPv4.Server.Pool.1.WINSServers="192.168.1.1"

Set several IPv4 as WINSServers:

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.lan.WINSServers=\"192.168.1.1,192.168.1.56,192.168.1.20\"'" | grep -Ev '^>|^$'
  Device.DHCPv4.Server.Pool.1.
  Device.DHCPv4.Server.Pool.1.WINSServers="192.168.1.1,192.168.1.56,192.168.1.20"

Clean up WINSServers:

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.lan.WINSServers=\"\"'" | grep -Ev '^>|^$'
  Device.DHCPv4.Server.Pool.1.
  Device.DHCPv4.Server.Pool.1.WINSServers=""
