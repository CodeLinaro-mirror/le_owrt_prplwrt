SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation

USP Add from the controller to the DUT agent over MQTT, in an object of the
agent itself (a subscription) and in an object of a USP service (a port
mapping). The new rows are disabled, carry an ID or Alias of this test and
are deleted at the end. Instance numbers depend on the rows that exist
already, so the test does not check them:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/usp-controller.sh"
  $ sub='Device.LocalAgent.Subscription.[ID=="usp-msg-add"].'
  $ map='Device.NAT.PortMapping.[Alias=="usp-msg-add"].'

Remove the rows that an interrupted earlier run can have left:

  $ testbed-qemu usp delete "${sub}" >/dev/null 2>&1; testbed-qemu usp delete "${map}" >/dev/null 2>&1; true

Add a subscription. The reply gives the new instance and its unique keys:

  $ testbed-qemu usp add Device.LocalAgent.Subscription. ID=usp-msg-add NotifType=ValueChange ReferenceList=Device.DeviceInfo.ProvisioningCode Enable=false
  Device\.LocalAgent\.Subscription\.[0-9]+\. (re)
  Device\.LocalAgent\.Subscription\.[0-9]+\.Alias="cpe-[0-9]+" (re)
  Device\.LocalAgent\.Subscription\.[0-9]+\.ID="usp-msg-add" (re)
  Device\.LocalAgent\.Subscription\.[0-9]+\.Recipient="Device\.LocalAgent\.Controller\.[0-9]+" (re)
  $ testbed-qemu usp get "${sub}" | grep -v -e '\.Alias=' -e '\.CreationDate=' -e '\.Recipient='
  Device\.LocalAgent\.Subscription\.[0-9]+\.Enable="false" (re)
  Device\.LocalAgent\.Subscription\.[0-9]+\.ID="usp-msg-add" (re)
  Device\.LocalAgent\.Subscription\.[0-9]+\.NotifExpiration="0" (re)
  Device\.LocalAgent\.Subscription\.[0-9]+\.NotifRetry="false" (re)
  Device\.LocalAgent\.Subscription\.[0-9]+\.NotifType="ValueChange" (re)
  Device\.LocalAgent\.Subscription\.[0-9]+\.Persistent="false" (re)
  Device\.LocalAgent\.Subscription\.[0-9]+\.ReferenceList="Device\.DeviceInfo\.ProvisioningCode" (re)
  Device\.LocalAgent\.Subscription\.[0-9]+\.TimeToLive="0" (re)

The recipient is the controller row that the onboarding added for this
controller. Its EndpointID is the EndpointID of the controller:

  $ recipient=$(testbed-qemu usp get "${sub}Recipient" | sed -n 's/^[^=]*="\(.*\)"$/\1/p')
  $ ctl=$(usp_controller_id)
  $ [ -n "${ctl}" ] && testbed-qemu usp get "${recipient}.EndpointID" | grep -cxF "${recipient}.EndpointID=\"${ctl}\""
  1

The ID of a subscription must be unique for its recipient:

  $ testbed-qemu usp add Device.LocalAgent.Subscription. ID=usp-msg-add NotifType=ValueChange ReferenceList=Device.DeviceInfo.ProvisioningCode Enable=false
  error: 7004 Validate_SubsID: Subscription ID \(usp-msg-add\) is already in use by Device\.LocalAgent\.Subscription\.[0-9]+ \(subs instance=[0-9]+\) (re)
  error: 7025 Device\.LocalAgent\.Subscription\.\{i\}\.ID: Validate_SubsID: Subscription ID \(usp-msg-add\) is already in use by Device\.LocalAgent\.Subscription\.[0-9]+ \(subs instance=[0-9]+\) (re)
  [1]

A value that the parameter does not accept:

  $ testbed-qemu usp add Device.LocalAgent.Subscription. ID=usp-msg-add-bad NotifType=NoSuchType Enable=false
  error: 7004 Validate_SubsNotifType: Invalid notification type \(NoSuchType\) for Device\.LocalAgent\.Subscription\.[0-9]+\.NotifType\. (re)
  error: 7012 Device\.LocalAgent\.Subscription\.\{i\}\.NotifType: Validate_SubsNotifType: Invalid notification type \(NoSuchType\) for Device\.LocalAgent\.Subscription\.[0-9]+\.NotifType\. (re)
  [1]

A parameter that is not in the data model, without and with allow_partial.
Neither request adds a row:

  $ testbed-qemu usp add Device.LocalAgent.Subscription. ID=usp-msg-add-bad NoSuchParameter=1
  error: 7004 DM_PRIV_GetNodeFromPath: Path is invalid: Device\.LocalAgent\.Subscription\.[0-9]+\.NoSuchParameter (re)
  error: 7010 Device\.LocalAgent\.Subscription\.\{i\}\.NoSuchParameter: DM_PRIV_GetNodeFromPath: Path is invalid: Device\.LocalAgent\.Subscription\.[0-9]+\.NoSuchParameter (re)
  [1]
  $ testbed-qemu usp add --allow-partial Device.LocalAgent.Subscription. ID=usp-msg-add-bad NoSuchParameter=1
  error: 7010 Device\.LocalAgent\.Subscription\.: DM_PRIV_GetNodeFromPath: Path is invalid: Device\.LocalAgent\.Subscription\.[0-9]+\.NoSuchParameter (re)
  [1]
  $ testbed-qemu usp get 'Device.LocalAgent.Subscription.[ID=="usp-msg-add-bad"].ID'

An object that is not a table:

  $ testbed-qemu usp add Device.DeviceInfo.
  error: 7004 CheckPathProperties: Path (Device.DeviceInfo) is not a multi-instance object
  error: 7018 Device.DeviceInfo.: CheckPathProperties: Path (Device.DeviceInfo) is not a multi-instance object
  [1]

Add a port mapping. The service records the controller as the origin:

  $ testbed-qemu usp add Device.NAT.PortMapping. Alias=usp-msg-add ExternalPort=50511 Enable=false
  Device\.NAT\.PortMapping\.[0-9]+\. (re)
  Device\.NAT\.PortMapping\.[0-9]+\.Alias="usp-msg-add" (re)
  Device\.NAT\.PortMapping\.[0-9]+\.ExternalPort="50511" (re)
  Device\.NAT\.PortMapping\.[0-9]+\.Protocol="TCP" (re)
  Device\.NAT\.PortMapping\.[0-9]+\.RemoteHost="" (re)
  $ testbed-qemu usp get "${map}Enable" "${map}Origin" "${map}Status"
  Device\.NAT\.PortMapping\.[0-9]+\.Enable="false" (re)
  Device\.NAT\.PortMapping\.[0-9]+\.Origin="Controller" (re)
  Device\.NAT\.PortMapping\.[0-9]+\.Status="Disabled" (re)

Remove the rows of this test:

  $ testbed-qemu usp delete "${sub}" "${map}" >/dev/null
  $ testbed-qemu usp get "${sub}ID" "${map}Alias"
