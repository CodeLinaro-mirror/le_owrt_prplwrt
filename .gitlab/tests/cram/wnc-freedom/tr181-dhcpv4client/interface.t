Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Disable 4th dhcp client:

  $ R ba-cli 'Device.DHCPv4.Client.4.Enable=0' | grep -Ev '^>|^$'
  Device.DHCPv4.Client.4.
  Device.DHCPv4.Client.4.Enable=0

Set Interface value to incorrect object:

  $ R ba-cli 'Device.DHCPv4.Client.4.Interface=Device.Ethernet.Interface.1.' | grep -Ev '^>|^$'
  ERROR: set Device.DHCPv4.Client.4.Interface failed (10 - invalid value)

Set Interface value to path without Device prefix:

  $ R ba-cli 'Device.DHCPv4.Client.4.Interface=IP.Interface.11.' | grep -Ev '^>|^$'
  Device.DHCPv4.Client.4.
  Device.DHCPv4.Client.4.Interface="IP.Interface.11"

Set Interface value to path with Alias instead of index:

  $ R ba-cli 'Device.DHCPv4.Client.4.Interface=Device.IP.Interface.mgmt.' | grep -Ev '^>|^$'
  Device.DHCPv4.Client.4.
  Device.DHCPv4.Client.4.Interface="Device.IP.Interface.mgmt"

Set Interface value to path with Device prefix:

  $ R ba-cli 'Device.DHCPv4.Client.4.Interface=Device.IP.Interface.11.' | grep -Ev '^>|^$'
  Device.DHCPv4.Client.4.
  Device.DHCPv4.Client.4.Interface="Device.IP.Interface.11"

Enable 4th dhcp client:

  $ R ba-cli 'Device.DHCPv4.Client.4.Enable=1' | grep -Ev '^>|^$'
  Device.DHCPv4.Client.4.
  Device.DHCPv4.Client.4.Enable=1
