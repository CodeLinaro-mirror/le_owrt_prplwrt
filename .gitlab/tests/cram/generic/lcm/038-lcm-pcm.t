## Setup test configuration
Setup the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh"
  $ C ${TESTDIR}/script_functions.sh root@${TARGET_LAN_IP}:/tmp/script_functions.sh 2>/dev/null
  $ R "${S} && setup_hostobjects"

Restart the LCM Agent so we start fresh with resetted indexes for ease of comparing the data models:
  $ R "service rlyeh stop"
  $ R "service cthulhu stop"
  $ R "service timingila stop"
  $ sleep 3
  $ R "service rlyeh start"
  $ R "service cthulhu start"
  $ R "service timingila start"
  $ sleep 10

Create a user role with capabilities:
  $ R "${S} && add_user_role --rolename full_caps --capabilities \"CAP_AUDIT_CONTROL,CAP_AUDIT_READ,CAP_AUDIT_WRITE,CAP_BLOCK_SUSPEND,CAP_BPF,CAP_CHECKPOINT_RESTORE,CAP_CHOWN,CAP_DAC_OVERRIDE,CAP_DAC_READ_SEARCH,CAP_FOWNER,CAP_FSETID,CAP_IPC_LOCK,CAP_IPC_OWNER,CAP_KILL,CAP_LEASE,CAP_LINUX_IMMUTABLE,CAP_MAC_ADMIN,CAP_MAC_OVERRIDE,CAP_MKNOD,CAP_NET_ADMIN,CAP_NET_BIND_SERVICE,CAP_NET_BROADCAST,CAP_NET_RAW,CAP_PERFMON,CAP_SETFCAP,CAP_SETGID,CAP_SETPCAP,CAP_SETUID,CAP_SYS_ADMIN,CAP_SYS_BOOT,CAP_SYS_CHROOT,CAP_SYS_MODULE,CAP_SYS_NICE,CAP_SYS_PACCT,CAP_SYS_PTRACE,CAP_SYS_RAWIO,CAP_SYS_RESOURCE,CAP_SYS_TIME,CAP_SYS_TTY_CONFIG,CAP_SYSLOG,CAP_WAKE_ALARM\"" > /dev/null
  $ R "${S} && set_ee_roles --roles \"Full Access\" --userroles \"full_caps\"" > /dev/null
  $ R "${S} && check_available_roles --ee"
  Device.LocalAgent.ControllerTrust.Role.1.
  $ R "${S} && check_available_user_roles"
  Device.Users.Role.[RoleName=="full_caps"]

Install the container in privileged mode with extra LCM features and check its status and type:

  $ R "${S} && install_ctr --version prplos-v1 --ee --uuid --privileged true --network --hostobject --envvar --appdata --usprequired \"Full Access\" --userroles full_caps" > /dev/null
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
  $ sleep 30

Save the data model after simulated firmware upgrade:

  $ R "ba-cli 'Cthulhu.?'" > ${TESTDIR}/cthulhu_after.dm
  $ R "ba-cli 'SoftwareModules.?'" > ${TESTDIR}/timingila_after.dm
  $ R "ba-cli 'Rlyeh.?'" > ${TESTDIR}/rlyeh_after.dm

Compare the data models before and after the firmware upgrade:

  $ diff ${TESTDIR}/rlyeh_before.dm ${TESTDIR}/rlyeh_after.dm
  $ sed -i -e "s/\(Sandbox\.Instances\)\.2/\1\.1/g" ${TESTDIR}/cthulhu_after.dm
  $ sed -i -e "s/\(Sandbox\.Instances\)\.3/\1\.2/g" ${TESTDIR}/cthulhu_after.dm
  $ cat > ${TESTDIR}/runtime_params << EOF
  > Cthulhu.Container.Instances.1.RootfsIsMounted
  > Cthulhu.Container.Instances.1.Pid
  > Cthulhu.Container.Instances.1.StartTime
  > Cthulhu.Container.Instances.1.AutoRestart.RunningSince
  > Cthulhu.Container.Instances.1.Interfaces.6.Addresses.1.Address
  > Cthulhu.Container.Instances.1.PluginsPrivate.NetworkConfig.FirewallRules.1.Path
  > Cthulhu.Container.Instances.1.PluginsPrivate.NetworkConfig.FirewallRules.2.Path
  > Cthulhu.Container.Instances.1.Resources.Stats.DiskSpace.Free
  > Cthulhu.Container.Instances.1.Resources.Stats.DiskSpace.Used
  > Cthulhu.Container.Instances.1.Resources.Stats.Memory.Used
  > Cthulhu.Sandbox.Instances.1.Pid
  > Cthulhu.Sandbox.Instances.1.Stats.DiskSpace.Free
  > Cthulhu.Sandbox.Instances.1.Stats.DiskSpace.Used
  > Cthulhu.Sandbox.Instances.1.Stats.Memory.Used
  > Cthulhu.Sandbox.Instances.2.Created
  > Cthulhu.Sandbox.Instances.2.Pid
  > Cthulhu.Sandbox.Instances.2.Stats.DiskSpace.Free
  > Cthulhu.Sandbox.Instances.2.Stats.DiskSpace.Used
  > Cthulhu.Sandbox.Instances.2.Stats.Memory.Used
  > SoftwareModules.ExecEnv.1.AvailableDiskSpace
  > SoftwareModules.ExecutionUnit.1.AvailableDiskSpace
  > SoftwareModules.ExecutionUnit.1.DiskSpaceInUse
  > SoftwareModules.ExecutionUnit.1.MemoryInUse
  > SoftwareModules.ExecutionUnit.1.Uptime
  > EOF
  $ cthulhu_diff_params=$(diff -n ${TESTDIR}/cthulhu_before.dm ${TESTDIR}/cthulhu_after.dm | grep -o '^Cthulhu[^=]\+')
  $ for param in ${cthulhu_diff_params}; do grep -Fxq "${param}" ${TESTDIR}/runtime_params || echo "ERROR: runtime parameter mismatch - ${param}"; done
  $ timingila_diff_params=$(diff -n ${TESTDIR}/timingila_before.dm ${TESTDIR}/timingila_after.dm | grep -o '^SoftwareModules[^=]\+')
  $ for param in ${timingila_diff_params}; do grep -Fxq "${param}" ${TESTDIR}/runtime_params || echo "ERROR: runtime parameter mismatch - ${param}"; done

Check that ApplicationData volumes are available inside the container and use them:

  $ R "${S} && execute_in_container --uuid --cmd 'ls -l /'" | grep volume | awk '{print $9}'
  volume1
  volume2
  $ R "${S} && execute_in_container --uuid --cmd 'echo volume1_content > /volume1/file_volume1'"
  $ R "${S} && execute_in_container --uuid --cmd 'cat /volume1/file_volume1'"
  volume1_content
  $ R "${S} && execute_in_container --uuid --cmd 'echo volume2_content > /volume2/file_volume2'"
  $ R "${S} && execute_in_container --uuid --cmd 'cat /volume2/file_volume2'"
  volume2_content

Verify share objects are available on container side:

  $ R "${S} && get_hostobjects"
  /testdir/:
  testfile
  test sharing file
  /dev/host_serial

Verify that the EnvVariables were properly restored:

  $ R "${S} && execute_in_container --uuid --cmd \"env\" | grep ENVVAR_KEY1"
  ENVVAR_KEY1=ENVVAR_VALUE1
  $ R "${S} && execute_in_container --uuid --cmd \"env\" | grep ENVVAR_KEY2"
  ENVVAR_KEY2=ENVVAR_VALUE2

Check that UDS sockets and the random USP_ENDPOINT_ID are shared with the container:

  $ R "${S} && execute_in_container --uuid --cmd \"env\" | grep USP_ENDPOINT_ID"
  USP_ENDPOINT_ID=uuid::* (glob)
  $ R "${S} && execute_in_container --uuid --cmd \"ls /run/usp/\""
  broker_agent_path
  broker_controller_path

Check that the container has the required capabilities:
  $ R "${S} && execute_in_container --uuid --cmd 'grep CapEff /proc/1/status'"
  CapEff:\t000001ffffffffff (esc)
  $ R "${S} && get_container_parameter --uuid --param RequiredUserRoles"
  Device.Users.Role.[RoleName=="full_caps"]
  $ R "${S} && get_container_parameter --uuid --param AvailableUserRoleCapabilities"
  CAP_AUDIT_CONTROL,CAP_AUDIT_READ,CAP_AUDIT_WRITE,CAP_BLOCK_SUSPEND,CAP_BPF,CAP_CHECKPOINT_RESTORE,CAP_CHOWN,CAP_DAC_OVERRIDE,CAP_DAC_READ_SEARCH,CAP_FOWNER,CAP_FSETID,CAP_IPC_LOCK,CAP_IPC_OWNER,CAP_KILL,CAP_LEASE,CAP_LINUX_IMMUTABLE,CAP_MAC_ADMIN,CAP_MAC_OVERRIDE,CAP_MKNOD,CAP_NET_ADMIN,CAP_NET_BIND_SERVICE,CAP_NET_BROADCAST,CAP_NET_RAW,CAP_PERFMON,CAP_SETFCAP,CAP_SETGID,CAP_SETPCAP,CAP_SETUID,CAP_SYS_ADMIN,CAP_SYS_BOOT,CAP_SYS_CHROOT,CAP_SYS_MODULE,CAP_SYS_NICE,CAP_SYS_PACCT,CAP_SYS_PTRACE,CAP_SYS_RAWIO,CAP_SYS_RESOURCE,CAP_SYS_TIME,CAP_SYS_TTY_CONFIG,CAP_SYSLOG,CAP_WAKE_ALARM

Check NetworkConfig correctly applied:

  $ CTR_IP=$(R "${S} && get_ctr_ip --uuid")
  $ R "rm -f /root/.ssh/known_hosts > /dev/null; ssh -y root@${CTR_IP} 'cat /etc/container-version ; ip route show default | grep default' 2> /dev/null"
  1
  default via 192.168.*.1 dev lcm0* (glob)

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

Cleanup test environment:

  $ R "${S} && remove_user_role --rolename full_caps" > /dev/null
  $ R "${S} && set_ee_roles --userroles \"\" --roles \"\"" > /dev/null
  $ R "${S} && check_available_user_roles"
  
  $ R "${S} && cleanup_hostobjects"
  $ R "rm -f /tmp/script_functions.sh"
  $ rm ${TESTDIR}/*_before.dm ${TESTDIR}/*_after.dm
  $ rm ${TESTDIR}/runtime_params
