## Setup test configuration
Setup the test configuration:

If test is running on a Valyrian, skip the test due to PCF-2669:
  $ if echo "$CI_JOB_NAME" | grep -q -E "Valyrian"; then exit 80; fi

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ T="/tmp/lcm-pcm"
  $ S=". /tmp/script_functions.sh"
  $ . ${TESTDIR}/script_functions.sh
  $ C ${TESTDIR}/script_functions.sh root@${TARGET_LAN_IP}:/tmp/script_functions.sh 2>/dev/null

Simulate firmware upgrade with manual configuration removal:

  $ R "${S} && fake_fw_upgrade"

Save the data model after simulated firmware upgrade:

  $ R "ba-cli 'Cthulhu.?'" > ${T}/cthulhu_after.dm
  $ R "ba-cli 'SoftwareModules.?'" > ${T}/timingila_after.dm
  $ R "ba-cli 'Rlyeh.?'" > ${T}/rlyeh_after.dm

Compare the data models before and after the firmware upgrade:

  $ diff ${T}/rlyeh_before.dm ${T}/rlyeh_after.dm
  $ normalize_dump ${T}/cthulhu_before.dm
  $ normalize_dump ${T}/cthulhu_after.dm
  $ cp ${TESTDIR}/lcm-pcm_runtime_params ${T}/runtime_params
  $ cthulhu_diff_params=$(diff -n ${T}/cthulhu_before.dm ${T}/cthulhu_after.dm | grep -o '^Cthulhu[^=]\+')
  $ for param in ${cthulhu_diff_params}; do grep -Fxq "${param}" ${T}/runtime_params || echo "ERROR: runtime parameter mismatch - ${param}"; done
  $ normalize_dump ${T}/timingila_before.dm
  $ normalize_dump ${T}/timingila_after.dm
  $ timingila_diff_params=$(diff -n ${T}/timingila_before.dm ${T}/timingila_after.dm | grep -o '^SoftwareModules[^=]\+')
  $ for param in ${timingila_diff_params}; do grep -Fxq "${param}" ${T}/runtime_params || echo "ERROR: runtime parameter mismatch - ${param}"; done

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

Check that UDS sockets and the random USP_ENDPOINT_ID with USP_PASSWORD are shared with the container:

  $ R "${S} && execute_in_container --uuid --cmd \"env\" | grep USP_ENDPOINT_ID"
  USP_ENDPOINT_ID=uuid::* (glob)
  $ R "${S} && execute_in_container --uuid --cmd \"env\" | grep USP_PASSWORD"
  USP_PASSWORD=* (glob)
  $ R "${S} && execute_in_container --uuid --cmd 'mount | grep usp'"
  tmpfs on /run/usp/sockets/authenticated/broker_controller* (glob)
  tmpfs on /run/usp/sockets/authenticated/broker_agent* (glob)

Check that the container has the required capabilities:
  $ R "${S} && execute_in_container --uuid --cmd 'grep CapEff /proc/1/status'"
  CapEff:\t000001ffffffffff (esc)
  $ R "${S} && get_container_parameter --uuid --param RequiredUserRoles"
  Device.Users.Role.[RoleName=="full_caps"]
  $ R "${S} && get_container_parameter --uuid --param AvailableUserRoleCapabilities"
  CAP_AUDIT_CONTROL,CAP_AUDIT_READ,CAP_AUDIT_WRITE,CAP_BLOCK_SUSPEND,CAP_BPF,CAP_CHECKPOINT_RESTORE,CAP_CHOWN,CAP_DAC_OVERRIDE,CAP_DAC_READ_SEARCH,CAP_FOWNER,CAP_FSETID,CAP_IPC_LOCK,CAP_IPC_OWNER,CAP_KILL,CAP_LEASE,CAP_LINUX_IMMUTABLE,CAP_MAC_ADMIN,CAP_MAC_OVERRIDE,CAP_MKNOD,CAP_NET_ADMIN,CAP_NET_BIND_SERVICE,CAP_NET_BROADCAST,CAP_NET_RAW,CAP_PERFMON,CAP_SETFCAP,CAP_SETGID,CAP_SETPCAP,CAP_SETUID,CAP_SYS_ADMIN,CAP_SYS_BOOT,CAP_SYS_CHROOT,CAP_SYS_MODULE,CAP_SYS_NICE,CAP_SYS_PACCT,CAP_SYS_PTRACE,CAP_SYS_RAWIO,CAP_SYS_RESOURCE,CAP_SYS_TIME,CAP_SYS_TTY_CONFIG,CAP_SYSLOG,CAP_WAKE_ALARM

Check NetworkConfig correctly applied:

  $ sleep 10
  $ CTR_IP=$(R "${S} && get_ctr_ip --uuid")
  $ R "rm -f /root/.ssh/known_hosts > /dev/null; ssh -y root@${CTR_IP} 'cat /etc/container-version ; ip route show default | grep default' 2> /dev/null"
  1
  default via 192.168.*.1 dev lcm0* (glob)

Check that the container has the expected EndpointID, AutoMountIPC and RegisterTrustPaths values:

  $ CTR_ID=$(R "${S} && get_container_parameter --uuid --param EUID")
  $ CTR_ENDPOINTID=$(R "ba-cli -l 'Cthulhu.Container.Instances.[ContainerId==\"${CTR_ID}\"].EndpointID?' | sed '/^$/d'")
  $ R "ba-cli -l 'Cthulhu.Container.Instances.[ContainerId==\"${CTR_ID}\"].EndpointID?' | sed '/^$/d'"
  uuid::* (glob)
  $ R "ba-cli -l 'Cthulhu.Container.Instances.[ContainerId==\"${CTR_ID}\"].AutoMountIPC?' | sed '/^$/d'"
  USP_UDS_Authenticated
  $ R "ba-cli -l 'Cthulhu.Container.Instances.[ContainerId==\"${CTR_ID}\"].RegisterTrustPaths?' | sed '/^$/d'"
  Device.LCMSampleApp.
  $ R "ba-cli -l 'Device.SoftwareModules.ExecutionUnit.[EUID==\"$CTR_ID\"].X_PRPLWARE-COM_AutoMountIPC?' | sed '/^$/d'"
  USP_UDS_Authenticated
  $ R "ba-cli -l 'Device.SoftwareModules.ExecutionUnit.[EUID==\"$CTR_ID\"].RegisterTrustPaths?' | sed '/^$/d'"
  Device.LCMSampleApp.

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

  $ R "${S} && cleanup_pcm_test"
  Done
