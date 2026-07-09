## Setup test configuration
Setup the test configuration:

If test is running on a Valyrian, skip the test due to PCF-2669:
  $ if echo "$CI_JOB_NAME" | grep -q -E "Valyrian"; then exit 80; fi

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh"
  $ C ${TESTDIR}/script_functions.sh root@${TARGET_LAN_IP}:/tmp/script_functions.sh 2>/dev/null
  $ R "${S} && setup_hostobjects"
  $ mkdir /tmp/lcm-pcm

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

  $ R "${S} && install_ctr --version prplos-v1 --ee --uuid --privileged true --network --hostobject --envvar --appdata --usprequired \"Full Access\" --userroles full_caps --uspregisterpaths \"Device.LCMSampleApp.\" --uspautomountipc \"USP_UDS_Authenticated\"" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v1
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)
  $ R "${S} && get_ctr_type --uuid"
  Privileged container
  $ R "${S} && execute_in_container --uuid --cmd 'cat /etc/container-version'"
  1

Perform the backup process:

  $ R "ba-cli 'PersistentConfiguration.Service.cthulhu_Cthulhu.ExportStatus=None'" > /dev/null
  $ R "ba-cli 'PersistentConfiguration.Service.cthulhu_Cthulhu.ImportStatus=None'" > /dev/null
  $ R "ba-cli 'PersistentConfiguration.Backup()'" > /dev/null
  $ R "ls /cfg/pcm/cthulhu_Cthulhu.json"
  /cfg/pcm/cthulhu_Cthulhu.json

Save the data model before simulated firmware upgrade:

  $ R "ba-cli 'Cthulhu.?'" > /tmp/lcm-pcm/cthulhu_before.dm
  $ R "ba-cli 'SoftwareModules.?'" > /tmp/lcm-pcm/timingila_before.dm
  $ R "ba-cli 'Rlyeh.?'" > /tmp/lcm-pcm/rlyeh_before.dm

