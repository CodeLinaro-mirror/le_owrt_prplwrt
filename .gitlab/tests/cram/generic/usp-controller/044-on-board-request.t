SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation

USP OnBoardRequest from the DUT agent to the controller over MQTT.
OnBoardRequest is not a type of subscription: no subscription asks for it.
The agent sends it to a controller when the synchronous command
SendOnBoardRequest() of the controller row of that controller runs. The test
runs the command with an Operate on the row of this controller, found by its
EndpointID, and reads the notification that the controller received. The
notification has no subscription ID, and it identifies the device with the
values that the DUT reports in Device.DeviceInfo. The test shows them by
name. The test adds nothing:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/usp-controller.sh"
  $ ctl=$(usp_controller_id)

The Operate is synchronous and its reply has no output arguments:

  $ since=$(usp_now)
  $ testbed-qemu usp operate "Device.LocalAgent.Controller.[EndpointID==\"${ctl}\"].SendOnBoardRequest()"
  Device\.LocalAgent\.Controller\.[0-9]+\.SendOnBoardRequest\(\) (re)

The controller receives the OnBoardRequest. The test waits at most 10 s. The
subscription ID is empty:

  $ testbed-qemu usp notifications --since "${since}" --wait on_board_req --timeout 10 --json | grep -o '"subscription_id": "[^"]*"'
  "subscription_id": ""
  $ oui=$(testbed-qemu usp get Device.DeviceInfo.ManufacturerOUI | sed -n 's/^[^=]*="\(.*\)"$/\1/p')
  $ class=$(testbed-qemu usp get Device.DeviceInfo.ProductClass | sed -n 's/^[^=]*="\(.*\)"$/\1/p')
  $ serial=$(testbed-qemu usp get Device.DeviceInfo.SerialNumber | sed -n 's/^[^=]*="\(.*\)"$/\1/p')
  $ testbed-qemu usp notifications --since "${since}" --wait on_board_req --timeout 10 | sed -e "s/ oui=\"${oui}\"/ oui=<ManufacturerOUI>/" -e "s/ product_class=\"${class}\"/ product_class=<ProductClass>/" -e "s/ serial_number=\"${serial}\"/ serial_number=<SerialNumber>/"
  on_board_req  oui=<ManufacturerOUI> product_class=<ProductClass> serial_number=<SerialNumber>
