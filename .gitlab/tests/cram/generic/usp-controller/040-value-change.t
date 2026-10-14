SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation

USP ValueChange notifications from the DUT agent to the controller over MQTT.
The controller adds a subscription, changes the parameter with a Set and reads
the notification that it received. The agent sends a ValueChange also when the
subscribing controller made the change.

A new subscription is not persistent: the agent removes it when it restarts,
so this test never restarts the agent while its subscriptions exist. It does
not ask for retries either, so the agent does not wait for a response to its
notifications. The test deletes its subscriptions and restores the values it
changes:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/usp-controller.sh"
  $ fast='Device.LocalAgent.Subscription.[ID=="usp-sub-value"].'
  $ slow='Device.LocalAgent.Subscription.[ID=="usp-sub-value-agent"].'

Remove the subscriptions that an interrupted earlier run can have left:

  $ testbed-qemu usp delete "${fast}" "${slow}" >/dev/null 2>&1; true

A parameter of a USP service. The service reports the change to the agent at
once, so the notification arrives within a few seconds. The test waits at most
10 s:

  $ old=$(testbed-qemu usp get Device.DeviceInfo.ProvisioningCode | sed -n 's/^[^=]*="\(.*\)"$/\1/p')
  $ testbed-qemu usp subscribe usp-sub-value ValueChange Device.DeviceInfo.ProvisioningCode
  Device\.LocalAgent\.Subscription\.[0-9]+\. (re)
  Device\.LocalAgent\.Subscription\.[0-9]+\.Alias="cpe-[0-9]+" (re)
  Device\.LocalAgent\.Subscription\.[0-9]+\.ID="usp-sub-value" (re)
  Device\.LocalAgent\.Subscription\.[0-9]+\.Recipient="Device\.LocalAgent\.Controller\.[0-9]+" (re)
  $ testbed-qemu usp get "${fast}Enable" "${fast}NotifRetry" "${fast}Persistent"
  Device\.LocalAgent\.Subscription\.[0-9]+\.Enable="true" (re)
  Device\.LocalAgent\.Subscription\.[0-9]+\.NotifRetry="false" (re)
  Device\.LocalAgent\.Subscription\.[0-9]+\.Persistent="false" (re)
  $ since=$(usp_now)
  $ testbed-qemu usp set Device.DeviceInfo.ProvisioningCode=usp-sub-value
  Device.DeviceInfo.ProvisioningCode="usp-sub-value"
  $ usp_notify_wait "${since}" usp-sub-value 10
  value_change usp-sub-value param_path="Device.DeviceInfo.ProvisioningCode" param_value="usp-sub-value"

After the subscription is deleted, a change sends no notification. The
original value comes back:

  $ testbed-qemu usp delete "${fast}"
  Device\.LocalAgent\.Subscription\.[0-9]+\. (re)
  $ since=$(usp_now)
  $ testbed-qemu usp set "Device.DeviceInfo.ProvisioningCode=${old}" >/dev/null
  $ usp_notify_wait "${since}" usp-sub-value 3
  usp-controller: no notification for subscription usp-sub-value within 3 s
  [1]
  $ [ "$(testbed-qemu usp get Device.DeviceInfo.ProvisioningCode)" = "Device.DeviceInfo.ProvisioningCode=\"${old}\"" ] && echo restored
  restored

A parameter of the agent itself: the notification interval of the controller
row of this controller, found by its EndpointID. The agent checks its own
parameters for changes every 15 s, so the notification can take up to 15 s
after the change. The test waits at most 25 s:

  $ ctl=$(usp_controller_id)
  $ row=$(testbed-qemu usp get "Device.LocalAgent.Controller.[EndpointID==\"${ctl}\"].EndpointID" | sed -n 's/EndpointID=.*$//p')
  $ old=$(testbed-qemu usp get "${row}PeriodicNotifInterval" | sed -n 's/^[^=]*="\(.*\)"$/\1/p')
  $ testbed-qemu usp subscribe usp-sub-value-agent ValueChange "${row}PeriodicNotifInterval" | grep '\.ID='
  Device\.LocalAgent\.Subscription\.[0-9]+\.ID="usp-sub-value-agent" (re)
  $ since=$(usp_now)
  $ testbed-qemu usp set "${row}PeriodicNotifInterval=86399"
  Device\.LocalAgent\.Controller\.[0-9]+\.PeriodicNotifInterval="86399" (re)
  $ usp_notify_wait "${since}" usp-sub-value-agent 25
  value_change usp-sub-value-agent param_path="Device\.LocalAgent\.Controller\.[0-9]+\.PeriodicNotifInterval" param_value="86399" (re)

Delete the subscription, then restore the value:

  $ testbed-qemu usp delete "${slow}"
  Device\.LocalAgent\.Subscription\.[0-9]+\. (re)
  $ testbed-qemu usp set "${row}PeriodicNotifInterval=${old}" >/dev/null
  $ [ "$(testbed-qemu usp get "${row}PeriodicNotifInterval")" = "${row}PeriodicNotifInterval=\"${old}\"" ] && echo restored
  restored
  $ testbed-qemu usp get "${fast}ID" "${slow}ID"
