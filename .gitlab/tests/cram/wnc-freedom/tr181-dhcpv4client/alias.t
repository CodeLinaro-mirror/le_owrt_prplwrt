Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"


Create DHCPv4.Client.{i}. with Alias value of appropriate length:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ R ba-cli 'Device.DHCPv4.Client.+ { Alias='AliasLenTest' }' | grep -Ev '^>|^$'
  Device.DHCPv4.Client.5.
  Device.DHCPv4.Client.5.Alias="AliasLenTest"

Set DHCPv4.Client.{i}.Alias value with len > 64:

  $ R ba-cli 'Device.DHCPv4.Client.5.Alias=wanclient1wanclient1wanclient1wanclient1wanclient1wanclient1wanclient1' | grep -Ev '^>|^$'
  ERROR: set Device.DHCPv4.Client.5.Alias failed (10 - invalid value)

Create ReqOption.{i}.Alias value of appropriate length:

  $ R ba-cli 'Device.DHCPv4.Client.5.ReqOption.+ { Alias=TestReqOptAliasLen }' | grep -Ev '^>|^$'
  Device.DHCPv4.Client.5.ReqOption.1.
  Device.DHCPv4.Client.5.ReqOption.1.Alias="TestReqOptAliasLen"

Set ReqOption.{i}.Alias value with len > 64:

  $ R ba-cli 'Device.DHCPv4.Client.5.ReqOption.1.Alias=ReqOptReqOptReqOptReqOptReqOptReqOptReqOptReqOptReqOptReqOptReqOpt' | grep -Ev '^>|^$'
  ERROR: set Device.DHCPv4.Client.5.ReqOption.1.Alias failed (10 - invalid value)

Set SentOption.{i}.Alias value of appropriate length:

  $ R ba-cli 'DHCPv4Client.Client.5.SentOption.+ { Alias=TestSentOptAliasLen }' | grep -Ev '^>|^$'
  DHCPv4Client.Client.5.SentOption.1.
  DHCPv4Client.Client.5.SentOption.1.Alias="TestSentOptAliasLen"

Set SentOption.{i}.Alias value with len > 64:

  $ R ba-cli 'Device.DHCPv4.Client.5.SentOption.1.Alias=SentOptSentOptSentOptSentOptSentOptSentOptSentOptSentOptSentOptSentOpt' | grep -Ev '^>|^$'
  ERROR: set Device.DHCPv4.Client.5.SentOption.1.Alias failed (10 - invalid value)

Cleanup:

  $ R ba-cli 'Device.DHCPv4.Client.5.-' | grep -Ev '^>|^$'
  Device.DHCPv4.Client.5.
  Device.DHCPv4.Client.5.SentOption.
  Device.DHCPv4.Client.5.SentOption.1.
  Device.DHCPv4.Client.5.ReqOption.
  Device.DHCPv4.Client.5.ReqOption.1.
  Device.DHCPv4.Client.5.Stats.
