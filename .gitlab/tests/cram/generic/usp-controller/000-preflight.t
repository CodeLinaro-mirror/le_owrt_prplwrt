SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation

Pre-flight for the USP controller tests in this directory. It onboards the DUT
agent to the controller over MQTT without TLS and checks the controller path
end to end. A failed check prints one line with the reason. The result goes to
a file in the run artifacts, and the later tests fail at once when it is not a
pass for this run and this DUT boot:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/usp-controller.sh"

The controller answers on its REST API:

  $ usp_preflight_check "controller not reachable" testbed-qemu usp health

Onboard the DUT agent over MQTT without TLS. This also adds the controller name
to the DUT hosts file and makes the controller the DUT time server:

  $ usp_preflight_check "onboarding over MQTT failed" testbed-qemu usp onboard mqtt --no-tls

The controller name resolves on the DUT to the controller address:

  $ address=${USP_CONTROLLER_URL#*://}; address=${address%%[:/]*}
  $ resolved=$(R "ping -c 1 -W 1 ${USP_CONTROLLER_HOST}" 2>&1 | sed -n 's/^PING [^ ]* (\([^)]*\)).*/\1/p')
  $ [ "${resolved}" = "${address}" ] || usp_preflight_fail "${USP_CONTROLLER_HOST} resolves to '${resolved}' on the DUT, expected ${address}"

The DUT clock is synchronized to the controller time server:

  $ for i in $(seq 60); do status=$(R "ba-cli -l 'Device.Time.Status?' | sed '/^$/d'"); [ "${status}" = Synchronized ] && break; sleep 1; done
  $ [ "${status}" = Synchronized ] || usp_preflight_fail "Device.Time.Status is '${status}' on the DUT after 60 s, expected Synchronized"

The controller sees the DUT agent connected over MQTT without TLS:

  $ testbed-qemu usp health 2>&1 | grep -qx 'agents_connected=1' || usp_preflight_fail "controller health does not show one connected agent"
  $ endpoint=$(R "obuspa -c get Device.LocalAgent.EndpointID" | sed -n 's/^Device\.LocalAgent\.EndpointID => //p')
  $ testbed-qemu usp agents 2>&1 | grep -qx "${endpoint} mqtt enabled=true connected=true tls=false" || usp_preflight_fail "agent '${endpoint}' not connected over MQTT"

A Get over MQTT returns the software version that the DUT reports locally:

  $ version=$(R "ba-cli -l 'Device.DeviceInfo.SoftwareVersion?' | sed '/^$/d'")
  $ [ -n "${version}" ] && [ "$(testbed-qemu usp get Device.DeviceInfo.SoftwareVersion 2>&1)" = "Device.DeviceInfo.SoftwareVersion=\"${version}\"" ] || usp_preflight_fail "Get of Device.DeviceInfo.SoftwareVersion over MQTT does not return '${version}'"

All checks passed. Record it for the later tests:

  $ usp_preflight_pass
  $ usp_result_field result
  pass
