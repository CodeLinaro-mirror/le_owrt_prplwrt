SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation

USP Delete from the controller to the DUT agent over MQTT, in an object of the
agent itself (subscriptions) and in an object of a USP service (port
mappings). The test deletes only rows that it adds itself, and selects them
by ID or Alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/usp-controller.sh"
  $ sub='Device.LocalAgent.Subscription.[ID=="usp-msg-delete"].'
  $ map_a='Device.NAT.PortMapping.[Alias=="usp-msg-delete-a"].'
  $ map_b='Device.NAT.PortMapping.[Alias=="usp-msg-delete-b"].'

Remove the rows that an interrupted earlier run can have left, then add the
rows of this test:

  $ for p in "${sub}" "${map_a}" "${map_b}"; do testbed-qemu usp delete "${p}" >/dev/null 2>&1; done; true
  $ testbed-qemu usp add Device.LocalAgent.Subscription. ID=usp-msg-delete NotifType=ValueChange ReferenceList=Device.DeviceInfo.ProvisioningCode Enable=false >/dev/null
  $ testbed-qemu usp add Device.NAT.PortMapping. Alias=usp-msg-delete-a ExternalPort=50521 Enable=false >/dev/null
  $ testbed-qemu usp add Device.NAT.PortMapping. Alias=usp-msg-delete-b ExternalPort=50522 Enable=false >/dev/null

Delete the subscription. The reply gives the deleted instance:

  $ testbed-qemu usp delete "${sub}"
  Device\.LocalAgent\.Subscription\.[0-9]+\. (re)
  $ testbed-qemu usp get "${sub}ID"

Delete both port mappings in one message:

  $ testbed-qemu usp delete "${map_a}" "${map_b}"
  Device\.NAT\.PortMapping\.[0-9]+\. (re)
  Device\.NAT\.PortMapping\.[0-9]+\. (re)
  $ testbed-qemu usp get "${map_a}Alias" "${map_b}Alias"

The delete of an instance that does not exist succeeds in an object of the
agent itself, by instance number and by search expression:

  $ testbed-qemu usp delete Device.LocalAgent.Subscription.9999.
  $ testbed-qemu usp delete "${sub}"

A path that is not in the data model, and a table without an instance:

  $ testbed-qemu usp delete Device.NoSuchObject.1.
  error: 7004 CheckPathProperties: Path (Device.NoSuchObject.1) does not exist in the schema
  error: 7026 Device.NoSuchObject.1.: CheckPathProperties: Path (Device.NoSuchObject.1) does not exist in the schema
  [1]
  $ testbed-qemu usp delete Device.LocalAgent.Subscription.
  error: 7004 CheckPathProperties: Path (Device.LocalAgent.Subscription) should contain instance number of object
  error: 7016 Device.LocalAgent.Subscription.: CheckPathProperties: Path (Device.LocalAgent.Subscription) should contain instance number of object
  [1]
