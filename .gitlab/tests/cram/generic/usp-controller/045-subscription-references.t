SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation

Path forms in the ReferenceList of a subscription that the DUT agent does not
accept. Each case has a name and checks the error that the agent gives today.
When the agent accepts the form, this test fails and the case moves to the
test of its notification type. The test deletes every subscription that it
adds:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/usp-controller.sh"
  $ sub='Device.LocalAgent.Subscription.[ID=="usp-sub-reference"].'
  $ base='Device.LocalAgent.Subscription.[ID=="usp-sub-reference-base"].'

Remove the subscriptions that an interrupted earlier run can have left:

  $ testbed-qemu usp delete "${sub}" "${base}" >/dev/null 2>&1; true

Reference following "+" for Event and OperationComplete. The agent accepts
"+" in a ValueChange subscription, here to the name of the lower layer of the
LAN interface (see 020-get.t for a Get):

  $ testbed-qemu usp subscribe --disable usp-sub-reference ValueChange 'Device.IP.Interface.[Alias=="lan"].LowerLayers+.Name' | grep '\.ID='
  Device\.LocalAgent\.Subscription\.[0-9]+\.ID="usp-sub-reference" (re)
  $ testbed-qemu usp delete "${sub}" >/dev/null

It does not accept "+" in an Event or an OperationComplete subscription. It
gives error 7005 and adds no subscription. The event is the MAC event of the
bridge port below the lower layer of the LAN interface:

  $ testbed-qemu usp subscribe --disable usp-sub-reference Event 'Device.IP.Interface.[Alias=="lan"].LowerLayers+.LowerLayers+.MACEvent!'
  error: 7005 Device.LocalAgent.Subscription.{i}.ReferenceList: ValidatePathSegment: Reference following in 'Device.IP.Interface.[Alias=="lan"].LowerLayers+.LowerLayers+.MACEvent!' is not supported for NotifType=Event
  error: 7005 ValidatePathSegment: Reference following in 'Device.IP.Interface.[Alias=="lan"].LowerLayers+.LowerLayers+.MACEvent!' is not supported for NotifType=Event
  [1]
  $ testbed-qemu usp get "${sub}ID"

The command is SendOnBoardRequest() of the controller row that a disabled
subscription of this test names as its recipient:

  $ testbed-qemu usp subscribe --disable usp-sub-reference-base ValueChange Device.DeviceInfo.ProvisioningCode >/dev/null
  $ testbed-qemu usp subscribe --disable usp-sub-reference OperationComplete 'Device.LocalAgent.Subscription.[ID=="usp-sub-reference-base"].Recipient+.SendOnBoardRequest()'
  error: 7005 Device.LocalAgent.Subscription.{i}.ReferenceList: ValidatePathSegment: Reference following in 'Device.LocalAgent.Subscription.[ID=="usp-sub-reference-base"].Recipient+.SendOnBoardRequest()' is not supported for NotifType=OperationComplete
  error: 7005 ValidatePathSegment: Reference following in 'Device.LocalAgent.Subscription.[ID=="usp-sub-reference-base"].Recipient+.SendOnBoardRequest()' is not supported for NotifType=OperationComplete
  [1]
  $ testbed-qemu usp get "${sub}ID"

Without "+", the same event and command are accepted:

  $ port=$(testbed-qemu usp get 'Device.IP.Interface.[Alias=="lan"].LowerLayers+.LowerLayers' | sed -n 's/^[^=]*="\(.*\)"$/\1/p')
  $ testbed-qemu usp subscribe --disable usp-sub-reference Event "${port}.MACEvent!" | grep '\.ID='
  Device\.LocalAgent\.Subscription\.[0-9]+\.ID="usp-sub-reference" (re)
  $ testbed-qemu usp delete "${sub}" >/dev/null
  $ recipient=$(testbed-qemu usp get "${base}Recipient" | sed -n 's/^[^=]*="\(.*\)"$/\1/p')
  $ testbed-qemu usp subscribe --disable usp-sub-reference OperationComplete "${recipient}.SendOnBoardRequest()" | grep '\.ID='
  Device\.LocalAgent\.Subscription\.[0-9]+\.ID="usp-sub-reference" (re)
  $ testbed-qemu usp delete "${sub}" "${base}" >/dev/null

Reference list index "#" (see 030-unsupported.t for a Get). The agent gives
error 7026 and adds no subscription:

  $ testbed-qemu usp subscribe --disable usp-sub-reference ValueChange 'Device.IP.Interface.[Alias=="lan"].LowerLayers#1+.Name'
  error: 7004 ValidatePathSegment: Unexpected character '#' in ReferenceList 'Device.IP.Interface.[Alias=="lan"].LowerLayers#1+.Name'
  error: 7026 Device.LocalAgent.Subscription.{i}.ReferenceList: ValidatePathSegment: Unexpected character '#' in ReferenceList 'Device.IP.Interface.[Alias=="lan"].LowerLayers#1+.Name'
  [1]
  $ testbed-qemu usp get "${sub}ID"
