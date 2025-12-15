## Setup test configuration

Setup the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh"
  $ C ${TESTDIR}/../lcm/script_functions.sh root@${TARGET_LAN_IP}:/tmp/script_functions.sh 2>/dev/null

This cthulhu restart is needed because LCM currently does not handle restart of USP broker (LCM-835):

  $ R "/etc/init.d/cthulhu restart"; sleep 10

Prepare roles

  $ R "${S} && set_ee_roles --roles \"Full Access\"" > /dev/null

Install file descriptor server container (priviledged)

  $ R "${S} && install_ctr --url docker://registry.gitlab.com/prpl-foundation/prplos/prplos/prplos/lcmfdserverapp-\$(get_board_arch):fd-pass-server-v1 --ee --uuid 7de135ba-1c5e-52f9-8b05-5284c544386f --privileged true --usprequired \"Full Access\"" > /dev/null
  $ R "${S} && get_container_info --uuid 7de135ba-1c5e-52f9-8b05-5284c544386f"
  Active
  fd-pass-server-v1
  image-lcm-container-server

Check if server model is present

  $ R "obuspa -c dump datamodel | grep LCMFDServerApp | cut -d ' ' -f 1"
  Device.LCMFDServerApp.
  Device.LCMFDServerApp.FilesAmount
  Device.LCMFDServerApp.LastFile!
  Device.LCMFDServerApp.Logs.{i}.
  Device.LCMFDServerApp.Logs.{i}.Name
  Device.LCMFDServerApp.Logs.{i}.getAsyncFd()
  Device.LCMFDServerApp.Logs.{i}.getAsyncFd()
  Device.LCMFDServerApp.Logs.{i}.getAsyncFd()
  Device.LCMFDServerApp.Logs.{i}.getFd()
  Device.LCMFDServerApp.Logs.{i}.getFd()
  Device.LCMFDServerApp.Logs.{i}.getFd()
  Device.LCMFDServerApp.getAllFdLogsAsync()
  Device.LCMFDServerApp.getAllFdLogsAsync()
  Device.LCMFDServerApp.getAllFdLogsAsync()
  Device.LCMFDServerApp.getAllFdLogsAsync()
  Device.LCMFDServerApp.getAllFdLogsAsync()
  Device.LCMFDServerApp.getAllFdLogsAsync()
  Device.LCMFDServerApp.getAllFdLogsAsync()
  Device.LCMFDServerApp.getAllFdLogsAsync()
  Device.LCMFDServerApp.getAllFdLogsAsync()
  Device.LCMFDServerApp.getAllFdLogsSync()
  Device.LCMFDServerApp.getAllFdLogsSync()
  Device.LCMFDServerApp.getAllFdLogsSync()
  Device.LCMFDServerApp.getAllFdLogsSync()
  Device.LCMFDServerApp.getAllFdLogsSync()
  Device.LCMFDServerApp.getAllFdLogsSync()
  Device.LCMFDServerApp.getAllFdLogsSync()
  Device.LCMFDServerApp.getAllFdLogsSync()
  Device.LCMFDServerApp.getAllFdLogsSync()
  Device.LCMFDServerApp.getAsyncFD()
  Device.LCMFDServerApp.getAsyncFD()
  Device.LCMFDServerApp.getAsyncFD()
  Device.LCMFDServerApp.getAsyncFD()
  Device.LCMFDServerApp.getFD()
  Device.LCMFDServerApp.getFD()
  Device.LCMFDServerApp.getFD()
  Device.LCMFDServerApp.getFD()
  Device.LCMFDServerApp.requestNotify()

Install file descriptor client container (unpriviledged)

  $ R "${S} && install_ctr --url docker://registry.gitlab.com/prpl-foundation/prplos/prplos/prplos/lcmfdclientapp-\$(get_board_arch):fd-pass-client-v1 --ee --uuid 4c39eee8-b0e7-5fa3-8cb3-ddeba7a3a052 --privileged false --usprequired \"Full Access\"" > /dev/null
  $ R "${S} && get_container_info --uuid 4c39eee8-b0e7-5fa3-8cb3-ddeba7a3a052"
  Active
  fd-pass-client-v1
  image-lcm-container-client

Check if client model is present

  $ R "obuspa -c dump datamodel | grep LCMFDClientApp | cut -d ' ' -f 1"
  Device.LCMFDClientApp.
  Device.LCMFDClientApp.LastFile!
  Device.LCMFDClientApp.getAsyncRPCWithMultipleOutputFD()
  Device.LCMFDClientApp.getAsyncRPCWithMultipleOutputFD()
  Device.LCMFDClientApp.getFDsViaAsyncRpcWithSearchExpression()
  Device.LCMFDClientApp.getFDsViaAsyncRpcWithSearchExpression()
  Device.LCMFDClientApp.getFDsViaAsyncRpcWithSearchExpression()
  Device.LCMFDClientApp.getFDsViaSyncRpcWithSearchExpression()
  Device.LCMFDClientApp.getFDsViaSyncRpcWithSearchExpression()
  Device.LCMFDClientApp.getFDsViaSyncRpcWithSearchExpression()
  Device.LCMFDClientApp.getSyncRPCWithMultipleOutputFD()
  Device.LCMFDClientApp.getSyncRPCWithMultipleOutputFD()
  Device.LCMFDClientApp.requestSendLastFileEvent()
  Device.LCMFDClientApp.writeToFileRequestedByAsyncRPC()
  Device.LCMFDClientApp.writeToFileRequestedByAsyncRPC()
  Device.LCMFDClientApp.writeToFileRequestedByAsyncRPC()
  Device.LCMFDClientApp.writeToFileRequestedByAsyncRPC()
  Device.LCMFDClientApp.writeToFileRequestedByAsyncRPC()
  Device.LCMFDClientApp.writeToFileRequestedByAsyncRPC()
  Device.LCMFDClientApp.writeToFileRequestedBySyncRPC()
  Device.LCMFDClientApp.writeToFileRequestedBySyncRPC()
  Device.LCMFDClientApp.writeToFileRequestedBySyncRPC()
  Device.LCMFDClientApp.writeToFileRequestedBySyncRPC()
  Device.LCMFDClientApp.writeToFileRequestedBySyncRPC()
  Device.LCMFDClientApp.writeToFileRequestedBySyncRPC()

Write file by call to unpriviledged container via sync RPC

  $ R "obuspa -c operate \"Device.LCMFDClientApp.writeToFileRequestedBySyncRPC(Path='/tmp/sync_write_example_file',Content='Example string written using unpriviledged container with sync RPC')\"" > /dev/null

Check file content from priviledged container written via sync RPC ("echo" adds EOL for correct comparison)

  $ R "${S} && execute_in_container --uuid 7de135ba-1c5e-52f9-8b05-5284c544386f --cmd 'sleep 10 && cat /tmp/sync_write_example_file && echo'"
  Example string written using unpriviledged container with sync RPC

Write file by call to unpriviledged container via async RPC

  $ R "obuspa -c operate \"Device.LCMFDClientApp.writeToFileRequestedByAsyncRPC(Path='/tmp/async_write_example_file',Content='Example string written using unpriviledged container with async RPC')\"" > /dev/null

Check file content from priviledged container written via async RPC ("echo" adds EOL for correct comparison)

  $ R "${S} && execute_in_container --uuid 7de135ba-1c5e-52f9-8b05-5284c544386f --cmd 'sleep 10 && cat /tmp/async_write_example_file && echo'"
  Example string written using unpriviledged container with async RPC

Uninstall priviledged

  $ R "${S} && uninstall_ctr_and_check --uuid 7de135ba-1c5e-52f9-8b05-5284c544386f"
  [1]

Uninstall unpriviledged

  $ R "${S} && uninstall_ctr_and_check --uuid 4c39eee8-b0e7-5fa3-8cb3-ddeba7a3a052"
  [1]
