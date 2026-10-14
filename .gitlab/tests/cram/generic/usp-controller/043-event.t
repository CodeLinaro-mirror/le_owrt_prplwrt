SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation

USP Event notifications from the DUT agent to the controller over MQTT. The
controller subscribes to an event, the test makes the DUT send the event and
reads the notification that the controller received. The test deletes its
subscriptions and restores the value it changes:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/usp-controller.sh"
  $ boot='Device.LocalAgent.Subscription.[ID=="usp-sub-boot"].'
  $ periodic='Device.LocalAgent.Subscription.[ID=="usp-sub-periodic"].'

Remove the subscriptions that an interrupted earlier run can have left:

  $ testbed-qemu usp delete "${boot}" "${periodic}" >/dev/null 2>&1; true

Boot! of the device. A USP service sends it, and only when its protected
command Device.SendBootEvent() runs. The agent does not send it by itself when
it connects to a controller. The test runs the command locally on the DUT with
ba-cli. The cause of the boot depends on how the DUT started, so the test
checks only that it is one of the causes that the data model defines. The
test waits at most 10 s:

  $ testbed-qemu usp subscribe usp-sub-boot Event 'Device.Boot!' | grep '\.ID='
  Device\.LocalAgent\.Subscription\.[0-9]+\.ID="usp-sub-boot" (re)
  $ since=$(usp_now)
  $ R "ba-cli 'Device.SendBootEvent()'" >/dev/null
  $ usp_notify_wait "${since}" usp-sub-boot 10 > boot.txt
  $ cut -d ' ' -f 1-4 boot.txt
  event usp-sub-boot obj_path="Device." event_name="Boot!"
  $ grep -o -E 'params\.(Cause|FirmwareUpdated|ParameterMap)="[^"]*"' boot.txt
  params\.Cause="(LocalReboot|RemoteReboot|FactoryReset|LocalFactoryReset|RemoteFactoryReset)" (re)
  params.FirmwareUpdated="false"
  params.ParameterMap="{}"
  $ testbed-qemu usp delete "${boot}"
  Device\.LocalAgent\.Subscription\.[0-9]+\. (re)

Periodic! of the agent itself. The agent sends it to a controller at the
notification interval of the controller row of that controller. The test sets
the interval of this controller to 5 s and waits at most 15 s. Then it
restores the interval:

  $ ctl=$(usp_controller_id)
  $ row=$(testbed-qemu usp get "Device.LocalAgent.Controller.[EndpointID==\"${ctl}\"].EndpointID" | sed -n 's/EndpointID=.*$//p')
  $ old=$(testbed-qemu usp get "${row}PeriodicNotifInterval" | sed -n 's/^[^=]*="\(.*\)"$/\1/p')
  $ testbed-qemu usp subscribe usp-sub-periodic Event 'Device.LocalAgent.Periodic!' | grep '\.ID='
  Device\.LocalAgent\.Subscription\.[0-9]+\.ID="usp-sub-periodic" (re)
  $ since=$(usp_now)
  $ testbed-qemu usp set "${row}PeriodicNotifInterval=5" >/dev/null
  $ usp_notify_wait "${since}" usp-sub-periodic 15 | head -n 1
  event usp-sub-periodic obj_path="Device.LocalAgent." event_name="Periodic!"
  $ testbed-qemu usp set "${row}PeriodicNotifInterval=${old}" >/dev/null
  $ [ "$(testbed-qemu usp get "${row}PeriodicNotifInterval")" = "${row}PeriodicNotifInterval=\"${old}\"" ] && echo restored
  restored

Remove the subscriptions of this test:

  $ testbed-qemu usp delete "${periodic}" >/dev/null
  $ testbed-qemu usp get "${boot}ID" "${periodic}ID"
