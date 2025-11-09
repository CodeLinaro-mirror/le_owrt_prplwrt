Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Create disabled SentOption:

  $ R ba-cli 'Device.DHCPv4.Client.1.SentOption.+ {Enable=0}' | grep -Ev '^>|^$'
  Device.DHCPv4.Client.1.SentOption.4.
  Device.DHCPv4.Client.1.SentOption.4.Alias="cpe-SentOption-4"

Set Value to hexbinary string with even length:

  $ R ba-cli 'Device.DHCPv4.Client.1.SentOption.4.Value=12ab' | grep -Ev '^>|^$'
  Device.DHCPv4.Client.1.SentOption.4.
  Device.DHCPv4.Client.1.SentOption.4.Value="12ab"

Set Value to hexbinary string with odd length:

  $ R ba-cli 'Device.DHCPv4.Client.1.SentOption.4.Value=12abc' | grep -Ev '^>|^$'
  ERROR: set Device.DHCPv4.Client.1.SentOption.4.Value failed (10 - invalid value)

Set Value to hexbinary string with incorrect char:

  $ R ba-cli 'Device.DHCPv4.Client.1.SentOption.4.Value=12ah' | grep -Ev '^>|^$'
  ERROR: set Device.DHCPv4.Client.1.SentOption.4.Value failed (10 - invalid value)

Remove test ReqOption:

  $ R ba-cli 'Device.DHCPv4.Client.1.SentOption.4.-' | grep -Ev '^>|^$'
  Device.DHCPv4.Client.1.SentOption.4.
