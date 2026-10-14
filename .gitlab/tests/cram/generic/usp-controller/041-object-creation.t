SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation

USP ObjectCreation notifications from the DUT agent to the controller over
MQTT. The controller subscribes to a table, adds a row with an Add and reads
the notification that it received. The notification gives the path of the new
row and its unique keys. The agent sends it also when the subscribing
controller added the row. The test adds disabled rows with an Alias of this
test and deletes the rows and its subscriptions at the end. Instance numbers
depend on the rows that exist already, so the test does not check them:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/usp-controller.sh"
  $ map='Device.NAT.PortMapping.[Alias=="usp-sub-creation"].'
  $ sub='Device.LocalAgent.Subscription.[ID=="usp-sub-creation"].'
  $ ctl=$(usp_controller_id)
  $ row=$(testbed-qemu usp get "Device.LocalAgent.Controller.[EndpointID==\"${ctl}\"].EndpointID" | sed -n 's/EndpointID=.*$//p')
  $ param="${row}BootParameter.[Alias==\"usp-sub-creation\"]."
  $ subagent='Device.LocalAgent.Subscription.[ID=="usp-sub-creation-agent"].'

Remove the rows that an interrupted earlier run can have left:

  $ testbed-qemu usp delete "${sub}" "${subagent}" >/dev/null 2>&1; testbed-qemu usp delete "${map}" >/dev/null 2>&1; testbed-qemu usp delete "${param}" >/dev/null 2>&1; true

A table of a USP service, the port mappings. The test waits at most 10 s:

  $ testbed-qemu usp subscribe usp-sub-creation ObjectCreation Device.NAT.PortMapping. | grep '\.ID='
  Device\.LocalAgent\.Subscription\.[0-9]+\.ID="usp-sub-creation" (re)
  $ since=$(usp_now)
  $ testbed-qemu usp add Device.NAT.PortMapping. Alias=usp-sub-creation ExternalPort=50601 Enable=false | grep -c '^Device\.NAT\.PortMapping\.[0-9]*\.$'
  1
  $ usp_notify_wait "${since}" usp-sub-creation 10
  obj_creation usp-sub-creation obj_path="Device\.NAT\.PortMapping\.[0-9]+\." unique_keys\.Alias="usp-sub-creation" unique_keys\.ExternalPort="50601" unique_keys\.Protocol="TCP" unique_keys\.RemoteHost="" (re)

The notification names the row that the Add created:

  $ path=$(testbed-qemu usp get "${map}Alias" | sed -n 's/Alias=.*$//p')
  $ usp_notify_wait "${since}" usp-sub-creation 10 | grep -c "obj_path=\"${path}\""
  1

A table of the agent itself, the boot parameters of the controller row of
this controller. The test waits at most 10 s:

  $ testbed-qemu usp subscribe usp-sub-creation-agent ObjectCreation "${row}BootParameter." | grep '\.ID='
  Device\.LocalAgent\.Subscription\.[0-9]+\.ID="usp-sub-creation-agent" (re)
  $ since=$(usp_now)
  $ testbed-qemu usp add "${row}BootParameter." Alias=usp-sub-creation Enable=false ParameterName=Device.DeviceInfo.ProvisioningCode | grep -c 'BootParameter\.[0-9]*\.$'
  1
  $ usp_notify_wait "${since}" usp-sub-creation-agent 10
  obj_creation usp-sub-creation-agent obj_path="Device\.LocalAgent\.Controller\.[0-9]+\.BootParameter\.[0-9]+\." unique_keys\.Alias="usp-sub-creation" unique_keys\.ParameterName="Device\.DeviceInfo\.ProvisioningCode" (re)

Remove the rows and the subscriptions of this test:

  $ testbed-qemu usp delete "${sub}" "${subagent}" >/dev/null
  $ testbed-qemu usp delete "${map}" >/dev/null
  $ testbed-qemu usp delete "${param}" >/dev/null
  $ testbed-qemu usp get "${sub}ID" "${subagent}ID" "${map}Alias" "${param}Alias"
