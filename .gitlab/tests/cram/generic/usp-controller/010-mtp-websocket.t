SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation

Onboarding over WebSocket alone. The test removes the rows of every controller
from the DUT, onboards the DUT agent over WebSocket without TLS, and checks
that WebSocket is the only transport between the agent and the controller.
Then it runs the initial checks over WebSocket: a Get of Device.DeviceInfo., a
Set that is read back and restored, and GetSupportedProtocol:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/usp-controller.sh"

Remove the rows of every controller from the DUT:

  $ usp_clean_slate

Onboard the DUT agent over WebSocket without TLS:

  $ testbed-qemu usp onboard websocket --no-tls >/dev/null

The controller sees the agent connected over WebSocket and over no other
transport:

  $ testbed-qemu usp agents | sed 's/ enabled=[a-z]*//'
  proto::agent-id connected=true
  proto::agent-id mqtt connected=false tls=false
  proto::agent-id stomp connected=false tls=false
  proto::agent-id websocket connected=true tls=false

The DUT has one MTP for this controller. It is a WebSocket MTP, and it is
enabled:

  $ ctl=$(usp_controller_id)
  $ usp_dut_value "Device.LocalAgent.Controller.[EndpointID==\"${ctl}\"].MTP.*.Protocol"
  WebSocket
  $ usp_dut_value "Device.LocalAgent.Controller.[EndpointID==\"${ctl}\"].MTP.*.Enable"
  true

The DUT holds one TCP connection to the controller, and the controller reports
it as the WebSocket connection:

  $ usp_connections
  websocket
  $ received=$(usp_received websocket)

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

The checks went over WebSocket: the WebSocket connection is still the only
connection from the DUT, and the controller received more bytes on it:

  $ usp_connections
  websocket
  $ [ "$(usp_received websocket)" -gt "${received}" ]
