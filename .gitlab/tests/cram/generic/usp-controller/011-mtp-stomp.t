SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation

Onboarding over STOMP alone. The test removes the rows of every controller
from the DUT, onboards the DUT agent over STOMP without TLS, and checks that
STOMP is the only transport between the agent and the controller. Then it runs
the initial checks over STOMP: a Get of Device.DeviceInfo., a Set that is read
back and restored, and GetSupportedProtocol:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/usp-controller.sh"

Remove the rows of every controller from the DUT:

  $ usp_clean_slate

Onboard the DUT agent over STOMP without TLS:

  $ testbed-qemu usp onboard stomp --no-tls >/dev/null

The controller sees the agent connected over STOMP and over no other
transport:

  $ testbed-qemu usp agents | sed 's/ enabled=[a-z]*//'
  proto::agent-id connected=true
  proto::agent-id mqtt connected=false tls=false
  proto::agent-id stomp connected=true tls=false
  proto::agent-id websocket connected=false tls=false

The DUT has one MTP for this controller. It is a STOMP MTP, and it is enabled.
The agent MTP for STOMP is up, and the STOMP connection is enabled:

  $ ctl=$(usp_controller_id)
  $ usp_dut_value "Device.LocalAgent.Controller.[EndpointID==\"${ctl}\"].MTP.*.Protocol"
  STOMP
  $ usp_dut_value "Device.LocalAgent.Controller.[EndpointID==\"${ctl}\"].MTP.*.Enable"
  true
  $ usp_dut_value "Device.LocalAgent.MTP.[Alias==\"${ctl}-agent-stomp\"].Status"
  Up
  $ usp_dut_value "Device.STOMP.Connection.[Alias==\"${ctl}-stomp-connection\"].Status"
  Enabled

The DUT holds one TCP connection to the controller, and the controller reports
it as the STOMP connection:

  $ usp_connections
  stomp
  $ received=$(usp_received stomp)

A Get of Device.DeviceInfo. returns the identity of the QEMU machine and the
software version that the DUT reports locally:

  $ testbed-qemu usp get Device.DeviceInfo. > deviceinfo.txt
  $ grep -E '^Device\.DeviceInfo\.(Manufacturer|ManufacturerOUI|ModelName)=' deviceinfo.txt
  Device.DeviceInfo.Manufacturer="qemu-standard-pc-q35-ich9-2009"
  Device.DeviceInfo.ManufacturerOUI="525400"
  Device.DeviceInfo.ModelName="QEMU Standard PC (Q35 + ICH9, 2009)"
  $ version=$(R "ba-cli -l 'Device.DeviceInfo.SoftwareVersion?'" | sed '/^$/d')
  $ [ -n "${version}" ] && grep -cxF "Device.DeviceInfo.SoftwareVersion=\"${version}\"" deviceinfo.txt
  1

A Set of one parameter, read back, then the old value is put back:

  $ code=$(testbed-qemu usp get Device.DeviceInfo.ProvisioningCode | sed -n 's/^Device\.DeviceInfo\.ProvisioningCode="\(.*\)"$/\1/p')
  $ testbed-qemu usp set Device.DeviceInfo.ProvisioningCode=usp-mtp-check
  Device.DeviceInfo.ProvisioningCode="usp-mtp-check"
  $ testbed-qemu usp get Device.DeviceInfo.ProvisioningCode
  Device.DeviceInfo.ProvisioningCode="usp-mtp-check"
  $ testbed-qemu usp set "Device.DeviceInfo.ProvisioningCode=${code}" >/dev/null
  $ [ "$(testbed-qemu usp get Device.DeviceInfo.ProvisioningCode)" = "Device.DeviceInfo.ProvisioningCode=\"${code}\"" ]

GetSupportedProtocol gives the USP versions that the agent supports:

  $ testbed-qemu usp supported-protocol
  1.0,1.1,1.2,1.3

The checks went over STOMP: the STOMP connection is still the only connection
from the DUT, and the controller received more bytes on it:

  $ usp_connections
  stomp
  $ [ "$(usp_received stomp)" -gt "${received}" ]
