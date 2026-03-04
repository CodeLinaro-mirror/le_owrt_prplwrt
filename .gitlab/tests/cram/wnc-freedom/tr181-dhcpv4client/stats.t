Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Disable Device.DHCPv4.Client.1.:

  $ R ba-cli 'Device.DHCPv4.Client.1.Enable=0' | grep -Ev '^>|^$'
  Device.DHCPv4.Client.1.
  Device.DHCPv4.Client.1.Enable=0

Wait 5 seconds to ensure the DHCP client is fully disabled:

  $ sleep 5

Reset Stats:

  $ R "ba-cli 'Device.DHCPv4.Client.1.Stats.Reset()' | grep -Ev '^>|^$'"
  Device.DHCPv4.Client.1.Stats.Reset() returned
  [
      ""
  ]

Dump Stats object:

  $ R "ba-cli 'dump -p Device.DHCPv4.Client.1.Stats.' | grep -Ev '^>|^$'"
  .R...... <public>      singleton Device.DHCPv4.Client.1.Stats.
  .R....V. <public>         uint32 Device.DHCPv4.Client.1.Stats.Inform=0
  .R....V. <public>         uint32 Device.DHCPv4.Client.1.Stats.FailedPackets=0
  .R....V. <public>         uint32 Device.DHCPv4.Client.1.Stats.Decline=0
  .R....V. <public>         uint32 Device.DHCPv4.Client.1.Stats.OtherMessageTypes=0
  .R....V. <public>         uint32 Device.DHCPv4.Client.1.Stats.NAK=0
  .R....V. <public>         uint32 Device.DHCPv4.Client.1.Stats.Offer=0
  .R....V. <public>         uint32 Device.DHCPv4.Client.1.Stats.CorruptPackets=0
  .R....V. <public>         uint32 Device.DHCPv4.Client.1.Stats.Request=0
  .R....V. <public>         uint32 Device.DHCPv4.Client.1.Stats.Release=0
  .R....V. <public>         uint32 Device.DHCPv4.Client.1.Stats.ForceRenew=0
  .R....V. <public>         uint32 Device.DHCPv4.Client.1.Stats.ACK=0
  .R....V. <public>         uint32 Device.DHCPv4.Client.1.Stats.Discover=0

Enable Device.DHCPv4.Client.1.:

  $ R "ba-cli 'Device.DHCPv4.Client.1.Enable=1' | grep -Ev '^>|^$'"
  Device.DHCPv4.Client.1.
  Device.DHCPv4.Client.1.Enable=1
