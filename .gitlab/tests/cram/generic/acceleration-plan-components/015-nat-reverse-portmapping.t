Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh"
  $ C ${TESTDIR}/../lcm/script_functions.sh root@${TARGET_LAN_IP}:/tmp/script_functions.sh 2>/dev/null


## Configure capabilities required by the test:
Prepare the test setup
  $ R "${S} && add_user_role --rolename full_caps --capabilities \"CAP_AUDIT_CONTROL,CAP_AUDIT_READ,CAP_AUDIT_WRITE,CAP_BLOCK_SUSPEND,CAP_BPF,CAP_CHECKPOINT_RESTORE,CAP_CHOWN,CAP_DAC_OVERRIDE,CAP_DAC_READ_SEARCH,CAP_FOWNER,CAP_FSETID,CAP_IPC_LOCK,CAP_IPC_OWNER,CAP_KILL,CAP_LEASE,CAP_LINUX_IMMUTABLE,CAP_MAC_ADMIN,CAP_MAC_OVERRIDE,CAP_MKNOD,CAP_NET_ADMIN,CAP_NET_BIND_SERVICE,CAP_NET_BROADCAST,CAP_NET_RAW,CAP_PERFMON,CAP_SETFCAP,CAP_SETGID,CAP_SETPCAP,CAP_SETUID,CAP_SYS_ADMIN,CAP_SYS_BOOT,CAP_SYS_CHROOT,CAP_SYS_MODULE,CAP_SYS_NICE,CAP_SYS_PACCT,CAP_SYS_PTRACE,CAP_SYS_RAWIO,CAP_SYS_RESOURCE,CAP_SYS_TIME,CAP_SYS_TTY_CONFIG,CAP_SYSLOG,CAP_WAKE_ALARM\""
  
  {"Device.Users.Role.*.":{"Alias":"full_caps","RoleName":"full_caps"}} (glob)
  

  $ R "${S} && set_ee_roles --userroles \"full_caps\""
  
  SoftwareModules.ExecEnv.1.ModifyAvailableRoles() returned
  ["",{"err_code":0,"err_msg":""}]
  

Install test container:

  $ R "${S} && install_ctr --name alpine --ee --uuid --privileged true --network '{PortForwarding = [{Interface = Lan, ExternalPort = 22222, InternalPort = 11111, Protocol = TCP}]}' --userroles full_caps" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  latest
  prpl-foundation/prplos/prplos/* (glob)

Check NetworkConfig correctly applied:

  $ sleep 30
  $ container_ip=$(R "${S} && get_ctr_ip --uuid")


Check iptables rule:

  $ R "iptables -t nat -S | grep ${container_ip}:11111"
  -A PREROUTING_PortForwarding_* -d */32 -p tcp -m tcp --dport 22222 -j DNAT --to-destination *:11111 (glob)


Listen for TCP packet inside container on port 11111:

  $ R "${S} && execute_in_container --uuid --cmd 'nc -k -l -w 5 -p 11111 > /tmp/netcat_output.txt' &"

Send TCP packet on port 22222 from LAN host:

  $ sleep 1
  $ (echo 'hello from lan host' | nc -w 1 ${TARGET_LAN_IP} 22222)

Check that packet has been received:

  $ R "${S} && execute_in_container --uuid --cmd 'cat /tmp/netcat_output.txt'"
  hello from lan host


Remove the container and check everything is cleaned:

  $ R "${S} && uninstall_ctr_and_check --uuid"
  [1]


Remove the role from the ExecutionEnvironment

  $ R "${S} && set_ee_roles --userroles \"\""
  
  SoftwareModules.ExecEnv.1.ModifyAvailableRoles() returned
  ["",{"err_code":0,"err_msg":""}]
  

Remove full_caps from Devices.User.Role

  $ R "${S} && remove_user_role --rolename full_caps"
  
  ["Device.Users.Role.*."] (glob)
  

Cleanup test environment:

  $ R "rm -f /tmp/script_functions.sh"
