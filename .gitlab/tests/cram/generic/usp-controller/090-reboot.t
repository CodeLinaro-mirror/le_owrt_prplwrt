SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation

Reboot of the DUT through the controller. The controller runs Device.Reboot()
over MQTT, the DUT reboots, and the agent connects to the same controller
process again. The test checks the state after the reboot: the controller
knows the agent by the same EndpointID and agent ID, the DUT clock is
synchronized again, the MQTT client of the controller is connected, a
subscription with Persistent=false is gone and one with Persistent=true is
still there. The agent sends Boot! only when Device.SendBootEvent() runs, so
the test runs it. The test deletes its subscriptions.

The reboot gives the DUT a new boot ID, so the pre-flight result is stale
after this test. This test must run last in this directory:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/usp-controller.sh"
  $ np='Device.LocalAgent.Subscription.[ID=="usp-sub-reboot-np"].'
  $ p='Device.LocalAgent.Subscription.[ID=="usp-sub-reboot-p"].'
  $ ctl=$(usp_controller_id)
  $ endpoint=$(R "obuspa -c get Device.LocalAgent.EndpointID" | sed -n 's/^Device\.LocalAgent\.EndpointID => //p')
  $ agent_field() {
  >     testbed-qemu usp agents --json | python3 -c 'import json, sys
  > for agent in json.load(sys.stdin):
  >     if agent["endpoint_id"] == sys.argv[1]:
  >         print(agent[sys.argv[2]])' "${endpoint}" "$1"
  > }
  $ wait_until() {
  >     _end=$(($(date +%s) + $1))
  >     shift
  >     until "$@"; do
  >         [ "$(date +%s)" -lt "${_end}" ] || return 1
  >         sleep 1
  >     done
  > }

Remove the subscriptions that an interrupted earlier run can have left:

  $ testbed-qemu usp delete "${np}" "${p}" >/dev/null 2>&1; true

The state before the reboot. The DUT runs the boot of the pre-flight:

  $ boot=$(usp_boot_id)
  $ [ "${boot}" = "$(usp_result_field boot_id)" ] && echo "boot of the pre-flight"
  boot of the pre-flight
  $ agent=$(agent_field agent_id)
  $ connected=$(agent_field connected_at)

A subscription with Persistent=false, the default, and one with
Persistent=true for Boot!:

  $ testbed-qemu usp subscribe usp-sub-reboot-np ValueChange Device.DeviceInfo.ProvisioningCode | grep '\.ID='
  Device\.LocalAgent\.Subscription\.[0-9]+\.ID="usp-sub-reboot-np" (re)
  $ testbed-qemu usp add Device.LocalAgent.Subscription. ID=usp-sub-reboot-p NotifType=Event 'ReferenceList=Device.Boot!' Enable=true Persistent=true | grep '\.ID='
  Device\.LocalAgent\.Subscription\.[0-9]+\.ID="usp-sub-reboot-p" (re)
  $ testbed-qemu usp get "${np}Persistent" "${p}Persistent"
  Device\.LocalAgent\.Subscription\.[0-9]+\.Persistent="false" (re)
  Device\.LocalAgent\.Subscription\.[0-9]+\.Persistent="true" (re)

The controller receives a Boot! before the reboot. The controller keeps its
notifications in memory only, so this notification shows later that the
controller process is the same. The test waits at most 10 s:

  $ before=$(usp_now)
  $ R "ba-cli 'Device.SendBootEvent()'" >/dev/null
  $ usp_notify_wait "${before}" usp-sub-reboot-p 10 | cut -d ' ' -f 1-4
  event usp-sub-reboot-p obj_path="Device." event_name="Boot!"

The reboot. Device.Reboot() is a synchronous command without output
arguments:

  $ reboot=$(usp_now)
  $ testbed-qemu usp operate --command-key usp-reboot 'Device.Reboot()'
  Device.Reboot()

The DUT answers on SSH again with a new boot ID. On KVM this takes about
30 s, so the test waits at most 90 s:

  $ new_boot() {
  >     _boot=$(timeout 5 ${CRAM_REMOTE_COMMAND} cat /proc/sys/kernel/random/boot_id 2>/dev/null) &&
  >         [ -n "${_boot}" ] && [ "${_boot}" != "${boot}" ]
  > }
  $ wait_until 90 new_boot && echo "new boot"
  new boot

The DUT clock is synchronized to the controller time server again. This takes
about 30 s after SSH answers, so the test waits at most 60 s:

  $ synchronized() {
  >     [ "$(timeout 5 ${CRAM_REMOTE_COMMAND} "ba-cli -l 'Device.Time.Status?'" 2>/dev/null | sed '/^$/d')" = Synchronized ]
  > }
  $ wait_until 60 synchronized && echo "Device.Time.Status is Synchronized"
  Device.Time.Status is Synchronized

The agent connects to the controller again over MQTT. The agent connects only
when the DUT clock is synchronized, and this takes about 10 s more, so the
test waits at most 30 s. The connection is a new one:

  $ attached() {
  >     testbed-qemu usp agents 2>/dev/null | grep -qx "${endpoint} mqtt enabled=true connected=true tls=false" &&
  >         [ "$(agent_field connected_at)" != "${connected}" ]
  > }
  $ wait_until 30 attached && echo "agent connected over MQTT"
  agent connected over MQTT

The controller knows the agent with the same agent ID, has no other agent and
keeps its own EndpointID:

  $ [ "$(agent_field agent_id)" = "${agent}" ] && echo "same agent ID"
  same agent ID
  $ testbed-qemu usp health
  status="ok"
  controller_id="<controller-id>"
  agents_total=1
  agents_connected=1
  $ [ "$(usp_controller_id)" = "${ctl}" ] && echo "same controller EndpointID"
  same controller EndpointID

The Boot! from before the reboot is still in the memory of the controller, so
the controller process did not restart:

  $ testbed-qemu usp notifications --json --since "${before}" | python3 -c 'import json, sys
  > print(sum(1 for notification in json.load(sys.stdin)
  >           if notification["subscription_id"] == "usp-sub-reboot-p"
  >           and notification["received_at"] < float(sys.argv[1])))' "${reboot}"
  1

The MQTT client of the controller is connected on the DUT, and a Get over MQTT
returns the software version that the DUT reports locally:

  $ usp_dut_value "Device.MQTT.Client.[Alias==\"${ctl}-mqtt-client\"].Status"
  Connected
  $ version=$(R "ba-cli -l 'Device.DeviceInfo.SoftwareVersion?'" | sed '/^$/d')
  $ [ -n "${version}" ] && [ "$(testbed-qemu usp get Device.DeviceInfo.SoftwareVersion)" = "Device.DeviceInfo.SoftwareVersion=\"${version}\"" ] && echo "same software version"
  same software version

The pre-flight result is now stale, and a later test fails at once:

  $ (usp_controller_check)
  usp-controller: pre-flight result stale: DUT rebooted since the pre-flight
  [1]

The agent removed the subscription with Persistent=false when it restarted.
The subscription with Persistent=true is still there:

  $ testbed-qemu usp get "${np}ID"
  $ testbed-qemu usp get "${p}Enable" "${p}Persistent"
  Device\.LocalAgent\.Subscription\.[0-9]+\.Enable="true" (re)
  Device\.LocalAgent\.Subscription\.[0-9]+\.Persistent="true" (re)

Boot! after the reboot, through the subscription that is still there. The
test checks only that the cause is one that the data model defines. The test
waits at most 10 s:

  $ since=$(usp_now)
  $ R "ba-cli 'Device.SendBootEvent()'" >/dev/null
  $ usp_notify_wait "${since}" usp-sub-reboot-p 10 > boot.txt
  $ cut -d ' ' -f 1-4 boot.txt
  event usp-sub-reboot-p obj_path="Device." event_name="Boot!"
  $ grep -o -E 'params\.(Cause|FirmwareUpdated|ParameterMap)="[^"]*"' boot.txt
  params\.Cause="(LocalReboot|RemoteReboot|FactoryReset|LocalFactoryReset|RemoteFactoryReset)" (re)
  params.FirmwareUpdated="false"
  params.ParameterMap="{}"

Remove the subscription of this test:

  $ testbed-qemu usp delete "${p}"
  Device\.LocalAgent\.Subscription\.[0-9]+\. (re)
  $ testbed-qemu usp get "${np}ID" "${p}ID"
