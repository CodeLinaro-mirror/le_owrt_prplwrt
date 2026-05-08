## Setup test configuration
Setup the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ R logger -t cram Starting $TESTFILE
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh"
  $ C ${TESTDIR}/script_functions.sh root@${TARGET_LAN_IP}:/tmp/script_functions.sh 2>/dev/null
  $ C ${TESTDIR}/event.lua root@${TARGET_LAN_IP}:/tmp/event.lua 2>/dev/null
  $ C ${TESTDIR}/usp-cli/usp-cli.conf root@${TARGET_LAN_IP}:/etc/amx/cli/usp-test-cli.conf 2>/dev/null
  $ C ${TESTDIR}/usp-cli/usp-cli.init root@${TARGET_LAN_IP}:/etc/amx/cli/usp-test-cli.init 2>/dev/null
  $ R "ln -s amx-cli /usr/bin/usp-test-cli"

### DUSTATECHANGE SECTION ###

Subscribe to the DUStateChange event

  $ R "usp-test-cli 'Device.LocalAgent.Subscription.+{Alias=\"DUStateChange\", ID=\"DUStateChange\", ReferenceList=\"Device.SoftwareModules.DUStateChange!\", Enable=1, NotifType=\"Event\"}'" > /dev/null

Listen to the event

  $ R "lua /tmp/event.lua \"Device.SoftwareModules.\" \"DUStateChange!\" > /tmp/captured_event &"

Install a container, and check the event

  $ R "${S} && install_ctr --version prplos-v1 --ee --uuid --privileged true" > /dev/null

check the event

  $ R "cat /tmp/captured_event"
  Event DUStateChange!
  {
      CompleteTime = <amxc_ts_t>:20\d{2}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{1,9}Z, (re)
      CurrentState = "Installed",
      DeploymentUnitRef = "Device.SoftwareModules.DeploymentUnit.[Alias == "cpe-917362a3-86e8-5332-bcfd-a4223f0e65e6"]",
      ExecutionUnitRefList = "Device.SoftwareModules.ExecutionUnit.[Alias == "cpe-917362a3-86e8-5332-bcfd-a4223f0e65e6"]",
      Fault = {
          FaultCode = 0,
          FaultString = ""
      },
      OperationPerformed = "Install",
      Resolved = true,
      StartTime = <amxc_ts_t>:20\d{2}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{1,9}Z, (re)
      UUID = "00000000-0000-5000-b000-000000000001",
      Version = "prplos-v1",
      path = "Device.SoftwareModules."
  }

Listen to the event

  $ R "lua /tmp/event.lua \"Device.SoftwareModules.\" \"DUStateChange!\" > /tmp/captured_event &"

Update the container

  $ R "${S} && update_ctr --version prplos-v2 --ee --uuid --privileged true" > /dev/null

check the event

  $ R "cat /tmp/captured_event"
  Event DUStateChange!
  {
      CompleteTime = <amxc_ts_t>:20\d{2}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{1,9}Z, (re)
      CurrentState = "Installed",
      DeploymentUnitRef = "Device.SoftwareModules.DeploymentUnit.[Alias == "cpe-917362a3-86e8-5332-bcfd-a4223f0e65e6"]",
      ExecutionUnitRefList = "Device.SoftwareModules.ExecutionUnit.[Alias == "cpe-917362a3-86e8-5332-bcfd-a4223f0e65e6"]",
      Fault = {
          FaultCode = 0,
          FaultString = ""
      },
      OperationPerformed = "Update",
      Resolved = true,
      StartTime = <amxc_ts_t>:20\d{2}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{1,9}Z, (re)
      UUID = "00000000-0000-5000-b000-000000000001",
      Version = "prplos-v2",
      path = "Device.SoftwareModules."
  }

Listen to the event

  $ R "lua /tmp/event.lua \"Device.SoftwareModules.\" \"DUStateChange!\" > /tmp/captured_event &"

Uninstall the container

  $ R "${S} && uninstall_ctr_and_check --uuid" > /dev/null
  [1]

check the event

  $ R "cat /tmp/captured_event"
  Event DUStateChange!
  {
      CompleteTime = <amxc_ts_t>:20\d{2}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{1,9}Z, (re)
      CurrentState = "Uninstalled",
      DeploymentUnitRef = "Device.SoftwareModules.DeploymentUnit.[Alias == "cpe-917362a3-86e8-5332-bcfd-a4223f0e65e6"]",
      ExecutionUnitRefList = "Device.SoftwareModules.ExecutionUnit.[Alias == "cpe-917362a3-86e8-5332-bcfd-a4223f0e65e6"]",
      Fault = {
          FaultCode = 0,
          FaultString = ""
      },
      OperationPerformed = "Uninstall",
      Resolved = true,
      StartTime = <amxc_ts_t>:20\d{2}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{1,9}Z, (re)
      UUID = "00000000-0000-5000-b000-000000000001",
      Version = "prplos-v2",
      path = "Device.SoftwareModules."
  }

remove the subscription

  $ R "usp-test-cli 'Device.LocalAgent.Subscription.[ Alias==\"DUStateChange\"]-'" > /dev/null

  $ R logger -t cram Ended $TESTFILE
