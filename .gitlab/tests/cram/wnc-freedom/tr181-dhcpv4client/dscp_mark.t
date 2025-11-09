Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"


Set DSCPMark to negative value:

  $ R ba-cli 'Device.DHCPv4.Client.1.DSCPMark=-1' | grep -Ev '^>|^$'
  ERROR: set Device.DHCPv4.Client.1.DSCPMark failed (10 - invalid value)

Set DSCPMark to value bigger than 63:

  $ R ba-cli 'Device.DHCPv4.Client.1.DSCPMark=64' | grep -Ev '^>|^$'
  ERROR: set Device.DHCPv4.Client.1.DSCPMark failed (10 - invalid value)

Set DSCPMark to acceptable value:

  $ R ba-cli 'Device.DHCPv4.Client.1.DSCPMark=63' | grep -Ev '^>|^$'
  Device.DHCPv4.Client.1.
  Device.DHCPv4.Client.1.DSCPMark=63

Restore default value:

  $ R ba-cli 'Device.DHCPv4.Client.1.DSCPMark=48' | grep -Ev '^>|^$'
  Device.DHCPv4.Client.1.
  Device.DHCPv4.Client.1.DSCPMark=48
