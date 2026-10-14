SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation

USP Set of two parameters that belong to two USP services. On prplOS each amx
component is a USP service of its own, behind the agent. The agent cannot
apply such a Set as one unit, so without allow_partial it rejects the
message with error 7005:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/usp-controller.sh"

The two parameters belong to two different services:

  $ testbed-qemu usp get 'Device.USPServices.USPService.[EndpointID=="proto::deviceinfo-manager"].DataModelPaths' | sed 's/^[^"]*"//; s/"$//' | tr ',' '\n' | sed 's/^ *//' | grep -x 'Device\.DeviceInfo\.ProvisioningCode'
  Device.DeviceInfo.ProvisioningCode
  $ testbed-qemu usp get 'Device.USPServices.USPService.[EndpointID=="proto::time-manager"].DataModelPaths'
  Device\.USPServices\.USPService\.[0-9]+\.DataModelPaths="Device\.Time\." (re)

Without allow_partial the agent rejects the Set and changes nothing:

  $ before=$(testbed-qemu usp get Device.DeviceInfo.ProvisioningCode Device.Time.LocalTimeZone)
  $ testbed-qemu usp set Device.DeviceInfo.ProvisioningCode=usp-msg-services Device.Time.LocalTimeZone=UTC0
  error: 7005 ProcessSet_AllowPartialFalse: Allow partial=false not supported across more than one USP Service
  [1]
  $ [ "$(testbed-qemu usp get Device.DeviceInfo.ProvisioningCode Device.Time.LocalTimeZone)" = "${before}" ]

With allow_partial the agent applies both parameters:

  $ testbed-qemu usp set --allow-partial Device.DeviceInfo.ProvisioningCode=usp-msg-services Device.Time.LocalTimeZone=UTC0
  Device.DeviceInfo.ProvisioningCode="usp-msg-services"
  Device.Time.LocalTimeZone="UTC0"

Put the values back:

  $ code=$(printf '%s\n' "${before}" | sed -n 's/^Device\.DeviceInfo\.ProvisioningCode="\(.*\)"$/\1/p')
  $ zone=$(printf '%s\n' "${before}" | sed -n 's/^Device\.Time\.LocalTimeZone="\(.*\)"$/\1/p')
  $ testbed-qemu usp set --allow-partial "Device.DeviceInfo.ProvisioningCode=${code}" "Device.Time.LocalTimeZone=${zone}" >/dev/null
  $ [ "$(testbed-qemu usp get Device.DeviceInfo.ProvisioningCode Device.Time.LocalTimeZone)" = "${before}" ]
