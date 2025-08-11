## Setup test configuration
Setup the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh"
  $ C ${TESTDIR}/script_functions.sh root@${TARGET_LAN_IP}:/tmp/script_functions.sh 2>/dev/null

Install simple the container in privileged mode without any external configuration and check its status and type:

  $ R "${S} && install_ctr --version prplos-v1 --ee --uuid --privileged true" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v1
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)
  $ R "${S} && get_ctr_type --uuid"
  Privileged container
  $ R "${S} && execute_in_container --uuid --cmd 'cat /etc/container-version'"
  1

Perform the backup process:

  $ R "ba-cli 'PersistentConfiguration.Backup()'" > /dev/null
  $ R "ls /cfg/pcm/cthulhu_Cthulhu.json"
  /cfg/pcm/cthulhu_Cthulhu.json

Save the data model before simulated firmware upgrade:

  $ R "ba-cli 'Cthulhu.?'" > ${TESTDIR}/cthulhu_before.dm
  $ R "ba-cli 'SoftwareModules.?'" > ${TESTDIR}/timingila_before.dm
  $ R "ba-cli 'Rlyeh.?'" > ${TESTDIR}/rlyeh_before.dm

Simulate firmware upgrade with manual configuration removal:

  $ R "${S} && fake_fw_upgrade"

Save the data model after simulated firmware upgrade:

  $ R "ba-cli 'Cthulhu.?'" > ${TESTDIR}/cthulhu_after.dm
  $ R "ba-cli 'SoftwareModules.?'" > ${TESTDIR}/timingila_after.dm
  $ R "ba-cli 'Rlyeh.?'" > ${TESTDIR}/rlyeh_after.dm

Compare the data models before and after the firmware upgrade:

  $ diff ${TESTDIR}/rlyeh_before.dm ${TESTDIR}/rlyeh_after.dm
  $ diff -n ${TESTDIR}/cthulhu_before.dm ${TESTDIR}/cthulhu_after.dm | grep '^Cthulhu'
  Cthulhu.Container.Instances.1.Pid=* (glob)
  Cthulhu.Container.Instances.1.StartTime=* (glob)
  Cthulhu.Container.Instances.1.AutoRestart.RunningSince=* (glob)
  Cthulhu.Container.Instances.1.Resources.Stats.Memory.Used=* (glob)
  Cthulhu.Sandbox.Instances.1.Pid=* (glob)
  Cthulhu.Sandbox.Instances.1.Stats.Memory.Used=* (glob)
  Cthulhu.Sandbox.Instances.2.Pid=* (glob)
  Cthulhu.Sandbox.Instances.2.Stats.Memory.Used=* (glob)
  $ diff -n ${TESTDIR}/timingila_before.dm ${TESTDIR}/timingila_after.dm | grep '^SoftwareModules'
  SoftwareModules.ExecutionUnit.1.MemoryInUse=* (glob)
  SoftwareModules.ExecutionUnit.1.Uptime=* (glob)

Update to prplOS container to v2:

  $ R "${S} && update_ctr --version prplos-v2 --ee --uuid --privileged true" > /dev/null
  $ sleep 20
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v2
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)
  $ R "${S} && get_ctr_type --uuid"
  Privileged container
  $ R "${S} && execute_in_container --uuid --cmd 'cat /etc/container-version'"
  2

Uninstall the testing container and check datamodel cleaned:

  $ R "${S} && uninstall_ctr_and_check --uuid --retaindata false"
  [1]

