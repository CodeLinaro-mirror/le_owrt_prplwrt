Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Create ReqOption with even length and hexBinary value:

  $ R ba-cli 'Device.DHCPv4.Client.1.ReqOption.+ {Enable=0, Alias=TestReq1, Value=12ab}' | grep -Ev '^>|^$'
  Device.DHCPv4.Client.1.ReqOption.*. (re)
  Device.DHCPv4.Client.1.ReqOption.*.Alias="TestReq1" (re)

Try to set Value parameter

  $ R ba-cli 'Device.DHCPv4.Client.1.ReqOption.TestReq1.Value=12ba' | grep -Ev '^>|^$'
  Device.DHCPv4.Client.1.ReqOption.*. (re)
  Device.DHCPv4.Client.1.ReqOption.*.Value="12ba" (re)

Create ReqOption with odd length and hexBinary Value:

  $ R ba-cli 'Device.DHCPv4.Client.1.ReqOption.+ {Enable=0, Alias=TestReq2, Value=12abc}' | grep -Ev '^>|^$'
  ERROR: add Device.DHCPv4.Client.1.ReqOption. failed (10 - invalid value)

Create ReqOption with even length and non-hexBinary Value:

  $ R ba-cli 'Device.DHCPv4.Client.1.ReqOption.+ {Enable=0, Alias=TestReq2, Value=12ah}' | grep -Ev '^>|^$'
  ERROR: add Device.DHCPv4.Client.1.ReqOption. failed (10 - invalid value)

Remove test ReqOption:

  $ R ba-cli 'Device.DHCPv4.Client.1.ReqOption.TestReq1.-' | grep -Ev '^>|^$'
  Device.DHCPv4.Client.1.ReqOption.*. (re)
