Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Create disabled SentOption:

  $ R ba-cli 'Device.DHCPv4.Client.1.SentOption.+ {Enable=0, Alias=TestSent1}' | grep -Ev '^>|^$'
  Device.DHCPv4.Client.1.SentOption.*. (re)
  Device.DHCPv4.Client.1.SentOption.*.Alias="TestSent1" (re)

Set Value to hexbinary string with even length:

  $ R ba-cli 'Device.DHCPv4.Client.1.SentOption.TestSent1.Value=12ab' | grep -Ev '^>|^$'
  Device.DHCPv4.Client.1.SentOption.*. (re)
  Device.DHCPv4.Client.1.SentOption.*.Value="12ab" (re)

Set Value to hexbinary string with odd length:

  $ R ba-cli 'Device.DHCPv4.Client.1.SentOption.TestSent1.Value=12abc' | grep -Ev '^>|^$'
  ERROR: set Device.DHCPv4.Client.1.SentOption.TestSent1.Value failed (10 - invalid value)

Set Value to hexbinary string with incorrect char:

  $ R ba-cli 'Device.DHCPv4.Client.1.SentOption.TestSent1.Value=12ah' | grep -Ev '^>|^$'
  ERROR: set Device.DHCPv4.Client.1.SentOption.TestSent1.Value failed (10 - invalid value)

Remove test ReqOption:

  $ R ba-cli 'Device.DHCPv4.Client.1.SentOption.TestSent1.-' | grep -Ev '^>|^$'
  Device.DHCPv4.Client.1.SentOption.*. (re)
