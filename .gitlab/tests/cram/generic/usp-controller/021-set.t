SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation

USP Set from the controller to the DUT agent over MQTT: one parameter, two
parameters of one object, and two objects in one message, with and without
allow_partial. All parameters in this test belong to one USP service. The test
puts back every value that it changes. It adds two disabled port mappings of
its own, selects them by Alias and deletes them at the end:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/usp-controller.sh"
  $ a='Device.NAT.PortMapping.[Alias=="usp-msg-set-a"].'
  $ b='Device.NAT.PortMapping.[Alias=="usp-msg-set-b"].'

Remove the rows that an interrupted earlier run can have left:

  $ testbed-qemu usp delete "${a}" >/dev/null 2>&1; testbed-qemu usp delete "${b}" >/dev/null 2>&1; true

One parameter. The DUT reads the new value locally:

  $ code=$(testbed-qemu usp get Device.DeviceInfo.ProvisioningCode | sed -n 's/^Device\.DeviceInfo\.ProvisioningCode="\(.*\)"$/\1/p')
  $ testbed-qemu usp set Device.DeviceInfo.ProvisioningCode=usp-msg-single
  Device.DeviceInfo.ProvisioningCode="usp-msg-single"
  $ R "ba-cli -l 'Device.DeviceInfo.ProvisioningCode?'" | sed '/^$/d'
  usp-msg-single
  $ testbed-qemu usp set "Device.DeviceInfo.ProvisioningCode=${code}" >/dev/null
  $ [ "$(testbed-qemu usp get Device.DeviceInfo.ProvisioningCode)" = "Device.DeviceInfo.ProvisioningCode=\"${code}\"" ]

A read-only parameter in the same object makes the Set fail. Without
allow_partial the agent sends an error message, and the writable parameter
keeps its value:

  $ testbed-qemu usp set Device.DeviceInfo.ProvisioningCode=usp-msg-ro Device.DeviceInfo.SoftwareVersion=x
  error: 7004 GROUP_SET_VECTOR_Add: Trying to perform a parameter set on read-only parameter Device.DeviceInfo.SoftwareVersion
  error: 7013 Device.DeviceInfo.SoftwareVersion: GROUP_SET_VECTOR_Add: Trying to perform a parameter set on read-only parameter Device.DeviceInfo.SoftwareVersion
  [1]
  $ [ "$(testbed-qemu usp get Device.DeviceInfo.ProvisioningCode)" = "Device.DeviceInfo.ProvisioningCode=\"${code}\"" ]

With allow_partial the object fails as a whole, because the read-only
parameter is required, and the writable parameter keeps its value:

  $ testbed-qemu usp set --allow-partial Device.DeviceInfo.ProvisioningCode=usp-msg-ro Device.DeviceInfo.SoftwareVersion=x
  error: 7013 Device.DeviceInfo.SoftwareVersion: GROUP_SET_VECTOR_Add: Trying to perform a parameter set on read-only parameter Device.DeviceInfo.SoftwareVersion
  error: 7021 Device.DeviceInfo.: Failed to set required parameters
  [1]
  $ [ "$(testbed-qemu usp get Device.DeviceInfo.ProvisioningCode)" = "Device.DeviceInfo.ProvisioningCode=\"${code}\"" ]

A parameter that is not in the data model:

  $ testbed-qemu usp set Device.DeviceInfo.NoSuchParameter=x
  error: 7004 DM_PRIV_GetNodeFromPath: Path is invalid: Device.DeviceInfo.NoSuchParameter
  error: 7010 Device.DeviceInfo.NoSuchParameter: DM_PRIV_GetNodeFromPath: Path is invalid: Device.DeviceInfo.NoSuchParameter
  [1]

An instance that does not exist:

  $ testbed-qemu usp set Device.NAT.PortMapping.9999.Description=x
  error: 7016 Device.NAT.PortMapping.9999.: Object does not exist
  [1]

Two parameters of one object and one parameter of a second object, in one
message:

  $ testbed-qemu usp add Device.NAT.PortMapping. Alias=usp-msg-set-a ExternalPort=50501 Enable=false >/dev/null
  $ testbed-qemu usp add Device.NAT.PortMapping. Alias=usp-msg-set-b ExternalPort=50502 Enable=false >/dev/null
  $ testbed-qemu usp set "${a}Description=first" "${a}InternalPort=8080" "${b}Description=second"
  Device\.NAT\.PortMapping\.[0-9]+\.Description="first" (re)
  Device\.NAT\.PortMapping\.[0-9]+\.InternalPort="8080" (re)
  Device\.NAT\.PortMapping\.[0-9]+\.Description="second" (re)
  $ testbed-qemu usp get "${a}Description" "${a}InternalPort" "${b}Description"
  Device\.NAT\.PortMapping\.[0-9]+\.Description="first" (re)
  Device\.NAT\.PortMapping\.[0-9]+\.InternalPort="8080" (re)
  Device\.NAT\.PortMapping\.[0-9]+\.Description="second" (re)

With allow_partial, the first object changes and the second object fails
because of its read-only parameter:

  $ testbed-qemu usp set --allow-partial "${a}Description=third" "${b}Status=Enabled"
  Device\.NAT\.PortMapping\.[0-9]+\.Description="third" (re)
  error: 7013 Device.NAT.PortMapping.[Alias=="usp-msg-set-b"].: Parameter read only
  [1]
  $ testbed-qemu usp get "${a}Description" "${b}Description"
  Device\.NAT\.PortMapping\.[0-9]+\.Description="third" (re)
  Device\.NAT\.PortMapping\.[0-9]+\.Description="second" (re)

Remove the rows of this test:

  $ testbed-qemu usp delete "${a}" "${b}" >/dev/null
  $ testbed-qemu usp get 'Device.NAT.PortMapping.*.Alias' | grep -c usp-msg-set
  0
  [1]
