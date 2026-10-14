SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation

USP ObjectDeletion notifications from the DUT agent to the controller over
MQTT. The test adds a disabled row with an Alias of this test, subscribes to
the deletion of rows of its table, deletes the row with a Delete and reads the
notification that the controller received. The notification gives the path of
the deleted row. The agent sends it also when the subscribing controller
deleted the row. The test deletes its subscriptions at the end. Instance
numbers depend on the rows that exist already, so the test does not check
them:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/usp-controller.sh"
  $ map='Device.NAT.PortMapping.[Alias=="usp-sub-deletion"].'
  $ sub='Device.LocalAgent.Subscription.[ID=="usp-sub-deletion"].'
  $ ctl=$(usp_controller_id)
  $ row=$(testbed-qemu usp get "Device.LocalAgent.Controller.[EndpointID==\"${ctl}\"].EndpointID" | sed -n 's/EndpointID=.*$//p')
  $ param="${row}BootParameter.[Alias==\"usp-sub-deletion\"]."
  $ subagent='Device.LocalAgent.Subscription.[ID=="usp-sub-deletion-agent"].'

Remove the rows that an interrupted earlier run can have left:

  $ testbed-qemu usp delete "${sub}" "${subagent}" >/dev/null 2>&1; testbed-qemu usp delete "${map}" >/dev/null 2>&1; testbed-qemu usp delete "${param}" >/dev/null 2>&1; true

A row of a USP service, a port mapping. The test waits at most 10 s:

  $ testbed-qemu usp add Device.NAT.PortMapping. Alias=usp-sub-deletion ExternalPort=50602 Enable=false >/dev/null
  $ path=$(testbed-qemu usp get "${map}Alias" | sed -n 's/Alias=.*$//p')
  $ testbed-qemu usp subscribe usp-sub-deletion ObjectDeletion Device.NAT.PortMapping. | grep '\.ID='
  Device\.LocalAgent\.Subscription\.[0-9]+\.ID="usp-sub-deletion" (re)
  $ since=$(usp_now)
  $ [ "$(testbed-qemu usp delete "${map}")" = "${path}" ] && echo deleted
  deleted
  $ usp_notify_wait "${since}" usp-sub-deletion 10 | sed "s/obj_path=\"${path}\"/obj_path=\"<deleted row>\"/"
  obj_deletion usp-sub-deletion obj_path="<deleted row>"

A row of the agent itself, a boot parameter of the controller row of this
controller. The test waits at most 10 s:

  $ testbed-qemu usp add "${row}BootParameter." Alias=usp-sub-deletion Enable=false ParameterName=Device.DeviceInfo.ProvisioningCode >/dev/null
  $ path=$(testbed-qemu usp get "${param}Alias" | sed -n 's/Alias=.*$//p')
  $ testbed-qemu usp subscribe usp-sub-deletion-agent ObjectDeletion "${row}BootParameter." | grep '\.ID='
  Device\.LocalAgent\.Subscription\.[0-9]+\.ID="usp-sub-deletion-agent" (re)
  $ since=$(usp_now)
  $ [ "$(testbed-qemu usp delete "${param}")" = "${path}" ] && echo deleted
  deleted
  $ usp_notify_wait "${since}" usp-sub-deletion-agent 10 | sed "s/obj_path=\"${path}\"/obj_path=\"<deleted row>\"/"
  obj_deletion usp-sub-deletion-agent obj_path="<deleted row>"

Remove the subscriptions of this test:

  $ testbed-qemu usp delete "${sub}" "${subagent}" >/dev/null
  $ testbed-qemu usp get "${sub}ID" "${subagent}ID" "${map}Alias" "${param}Alias"
