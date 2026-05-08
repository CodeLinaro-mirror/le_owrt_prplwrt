## Setup test configuration
Set-up the test configuration:

If test is running on a Valyrian, skip the test due to PCF-2669:
  $ if echo "$CI_JOB_NAME" | grep -q -E "Valyrian"; then exit 80; fi

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ R logger -t cram Starting $TESTFILE
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh"
  $ C ${TESTDIR}/script_functions.sh root@${TARGET_LAN_IP}:/tmp/script_functions.sh 2>/dev/null

  $ UUID_FDSERVER="00000000-0000-5000-b000-000000000001"
  $ UUID_FDCLIENT="00000000-0000-5000-b000-000000000002"
  $ DUID_FDSERVER="917362a3-86e8-5332-bcfd-a4223f0e65e6"
  $ DUID_FDCLIENT="e61c304b-b5e4-5fdb-9836-60001e90a127"

  $ TEST_FILENAME="\tmp\testfile"

## Set-up ExecEnv configuration

  $ R "${S} && set_ee_roles --roles \"Full Access\"" > /dev/null
  $ R "${S} && check_available_roles --ee"
  Device.LocalAgent.ControllerTrust.Role.1.

### INSTALL onboarded containers ###
  $ R "${S} && install_ctr --url_arch image-sampleapp-usp-direct-connection-server --ee --uuid ${UUID_FDSERVER} --usprequired --privileged true" > /dev/null
  $ R "${S} && get_container_info --uuid ${UUID_FDSERVER}"
  Active
  latest
  prpl-foundation/prplos/prplos/lcm_tests/*_image-sampleapp-* (glob)
  $ R "${S} && install_ctr --url_arch image-sampleapp-usp-direct-connection-client --ee --uuid ${UUID_FDCLIENT} --usprequired --privileged true" > /dev/null
  $ R "${S} && get_container_info --uuid ${UUID_FDCLIENT}"
  Active
  latest
  prpl-foundation/prplos/prplos/lcm_tests/*_image-sampleapp* (glob)

## Make a raw socket connection between the client and the server ##
  $ R "usp-cli \"Device.LocalAgent.Subscription.+{ReferenceList='Device.FdClient.OpenSocket()', NotifType='OperationComplete', Enable='true'}\""
  ? Device.LocalAgent.Subscription.+{ReferenceList='Device.FdClient.OpenSocket()', NotifType='OperationComplete', Enable='true'} (glob)
  Device.LocalAgent.Subscription.*. (glob)
  Device.LocalAgent.Subscription.*.Alias="cpe-*" (glob)
  Device.LocalAgent.Subscription.*.ID="cpe-*" (glob)
  Device.LocalAgent.Subscription.*.Recipient="Device.LocalAgent.Controller.*" (glob)

  $ R "usp-cli \"Device.FdClient.OpenSocket()\""
  ? Device.FdClient.OpenSocket() (glob)
  Device.FdClient.OpenSocket() returned
  {
      executed_command = "Device.FdClient.OpenSocket()",
      req_obj_path = "Device.LocalAgent.Request.?" (glob)
  }

## Send data over socket from client to server
  $ R "usp-cli \"Device.FdClient.SendOverSocket(Data = \"ClientToServer\")\""
  ? Device.FdClient.SendOverSocket(Data = ClientToServer) (glob)
  Device.FdClient.SendOverSocket() returned
  [
      {
      }
  ]

## check logs
  $ R "tail -n 2 /var/log/lcm/${DUID_FDSERVER}/messages"
  * fdserver: fdserve - [x]Received 14 data: ClientToServer (glob)
  * (glob)

## Send data over socket from client to server
  $ R "usp-cli \"Device.FdServer.SendOverSocket(Data = \"ServerToClient\")\""
  ? Device.FdServer.SendOverSocket(Data = ServerToClient) (glob)
  Device.FdServer.SendOverSocket() returned
  [
      {
      }
  ]

## check logs
  $ R "tail -n 2 /var/log/lcm/${DUID_FDCLIENT}/messages"
  * fdclient: fdclien - [x]Received 14 data: ServerToClient (glob)
  * (glob)

## remove usp subscriptions
  $ R "usp-cli \"Device.LocalAgent.Subscription.[ReferenceList == \"Device.FdClient.OpenSocket\(\)\"].-\""
  ? Device.LocalAgent.Subscription.[ReferenceList == Device.FdClient.OpenSocket()].- (glob)
  Device.LocalAgent.Subscription.*. (glob)

## Test direct USP connection
  $ R "${S} && execute_in_container --uuid ${UUID_FDCLIENT} --cmd 'direct-connection-controller !amx variable connection' | sed '/^$/d'"
  ? !amx variable connection (glob)
  connection = "usp:/var/run/usp/uspdc.sock"

  $ R "${S} && execute_in_container --uuid ${UUID_FDCLIENT} --cmd 'direct-connection-controller Device.FdServer.?' | sed '/^$/d'"
  ? Device.FdServer.? (glob)
  Device.FdServer.
  Device.FdServer.Text="FdServer"

  $ R "${S} && execute_in_container --uuid ${UUID_FDCLIENT} --cmd 'direct-connection-controller Device.FdServer.GetText\(\)' | sed '/^$/d'"
  ? Device.FdServer.GetText() (glob)
  Device.FdServer.GetText() returned
  [
      "FdServer"
  ]

## test FdClient.WriteToFile
## add subscription
  $ R "usp-cli \"Device.LocalAgent.Subscription.+{ReferenceList='Device.FdClient.WriteToFile()', NotifType='OperationComplete', Enable='true'}\"" > /dev/null

  $ R "usp-cli \"Device.FdClient.WriteToFile(Filename=\"${TEST_FILENAME}\", Data = \"Data for file\")\""
  ? Device.FdClient.WriteToFile(Filename=tmptestfile, Data = Data for file) (glob)
  Device.FdClient.WriteToFile() returned
  {
      executed_command = "Device.FdClient.WriteToFile()",
      req_obj_path = "Device.LocalAgent.Request.*" (glob)
  }

## check content of file in server
  $ R "${S} && execute_in_container --uuid ${UUID_FDSERVER} --cmd 'cat ${TEST_FILENAME}'"
  Dataforfile (no-eol)

## remove subscription
  $ R "usp-cli \"Device.LocalAgent.Subscription.[ReferenceList == \"Device.FdClient.WriteToFile\(\)\"].-\"" > /dev/null

## test FdClient.ReadFromFile
## add subscription
  $ R "usp-cli \"Device.LocalAgent.Subscription.+{ReferenceList='Device.FdClient.ReadFromFile()', NotifType='OperationComplete', Enable='true'}\"" > /dev/null

  $ R "usp-cli \"Device.FdClient.ReadFromFile(Filename=\"${TEST_FILENAME}\")\""
  ? Device.FdClient.ReadFromFile(Filename=tmptestfile) (glob)
  Device.FdClient.ReadFromFile() returned
  {
      executed_command = "Device.FdClient.ReadFromFile()",
      req_obj_path = "Device.LocalAgent.Request.*" (glob)
  }

## remove subscription
  $ R "usp-cli \"Device.LocalAgent.Subscription.[ReferenceList == \"Device.FdClient.ReadFromFile\(\)\"].-\"" > /dev/null

## test FdClient.TestUspConnection
## add subscription
  $ R "usp-cli \"Device.LocalAgent.Subscription.+{Alias=\"uspdc\", ID=\"uspdc\", ReferenceList='Device.FdClient.TestUspConnection()', NotifType='OperationComplete', Enable='true'}\"" > /dev/null

  $ R "usp-cli \"Device.FdClient.TestUspConnection()\""
  ? Device.FdClient.TestUspConnection() (glob)
  Device.FdClient.TestUspConnection() returned
  {
      executed_command = "Device.FdClient.TestUspConnection()",
      req_obj_path = "Device.LocalAgent.Request.*" (glob)
  }

## remove subscription
  $ R "usp-cli \"Device.LocalAgent.Subscription.[ReferenceList == \"Device.FdClient.TestUspConnection\(\)\"].-\"" > /dev/null

## clean up all containers ##

  $ R "${S} && uninstall_ctr_and_check --uuid ${UUID_FDCLIENT}"
  [1]
  $ R "${S} && uninstall_ctr_and_check --uuid ${UUID_FDSERVER}"
  [1]

  $ R "${S} && set_ee_roles --roles \"\"" > /dev/null
  $ R logger -t cram Ended $TESTFILE

