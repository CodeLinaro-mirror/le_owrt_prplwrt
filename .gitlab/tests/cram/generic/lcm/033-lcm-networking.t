## Setup test configuration
Set-up the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh"
  $ C ${TESTDIR}/script_functions.sh root@${TARGET_LAN_IP}:/tmp/script_functions.sh 2>/dev/null


## Configure capabilities required by the test:
  $ R "${S} && add_user_role --rolename full_caps --capabilities \"CAP_AUDIT_CONTROL,CAP_AUDIT_READ,CAP_AUDIT_WRITE,CAP_BLOCK_SUSPEND,CAP_BPF,CAP_CHECKPOINT_RESTORE,CAP_CHOWN,CAP_DAC_OVERRIDE,CAP_DAC_READ_SEARCH,CAP_FOWNER,CAP_FSETID,CAP_IPC_LOCK,CAP_IPC_OWNER,CAP_KILL,CAP_LEASE,CAP_LINUX_IMMUTABLE,CAP_MAC_ADMIN,CAP_MAC_OVERRIDE,CAP_MKNOD,CAP_NET_ADMIN,CAP_NET_BIND_SERVICE,CAP_NET_BROADCAST,CAP_NET_RAW,CAP_PERFMON,CAP_SETFCAP,CAP_SETGID,CAP_SETPCAP,CAP_SETUID,CAP_SYS_ADMIN,CAP_SYS_BOOT,CAP_SYS_CHROOT,CAP_SYS_MODULE,CAP_SYS_NICE,CAP_SYS_PACCT,CAP_SYS_PTRACE,CAP_SYS_RAWIO,CAP_SYS_RESOURCE,CAP_SYS_TIME,CAP_SYS_TTY_CONFIG,CAP_SYSLOG,CAP_WAKE_ALARM\""
  
  {"Device.Users.Role.*.":{"Alias":"full_caps","RoleName":"full_caps"}} (glob)
  

  $ R "${S} && set_ee_roles --userroles \"full_caps\""
  
  SoftwareModules.ExecEnv.1.ModifyAvailableRoles() returned
  ["",{"err_code":0,"err_msg":""}]
  

### PRIVILEGED CONTAINER SECTION ###
Install the container and check its status:

  $ R "${S} && install_ctr --version prplos-v1 --ee --uuid --privileged true --network --userroles full_caps" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v1
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)

Check NetworkConfig correctly applied:

  $ sleep 30
  $ CTR_IP=$(R "${S} && get_ctr_ip --uuid")
  $ R "rm -f /root/.ssh/known_hosts > /dev/null; ssh -y root@${CTR_IP} 'cat /etc/container-version ; ip route show default | grep default' 2> /dev/null"
  1
  default via 192.168.*.1 dev lcm0* (glob)


Update to prplOS container to v2:

  $ R "${S} && update_ctr --version prplos-v2 --ee --uuid --privileged true --network --userroles full_caps" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v2
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)

Check NetworkConfig correctly applied:

  $ sleep 30
  $ CTR_IP=$(R "${S} && get_ctr_ip --uuid")
  $ R "rm -f /root/.ssh/known_hosts > /dev/null; ssh -y root@${CTR_IP} 'cat /etc/container-version ; ip route show default | grep default' 2> /dev/null"
  2
  default via 192.168.*.1 dev lcm0* (glob)

Uninstall the container and check everything is cleaned:

  $ R "${S} && uninstall_ctr_and_check --uuid"
  [1]


### UNPRIVILEGED CONTAINER SECTION ####
Install the container and check its status:

  $ R "${S} && install_ctr --version prplos-v1 --ee --uuid --privileged false --network --userroles full_caps" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v1
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)

### Network connectivity test can only be done unpriv container gets the capability in its own net ns to 
### bind to a system port (< 1024) or test container is modified to not use system ports for SSH
### Test only checks the attribution of IP address
Check NetworkConfig correctly applied:

  $ sleep 10
  $ R "${S} && get_ctr_ip --uuid"
  192.168.*.* (glob)
#  $ sleep 30 
#  $ R "rm -f /root/.ssh/known_hosts > /dev/null; ssh -y root@${CTR_IP} 'cat /etc/container-version ; ip route show default | grep default' 2> /dev/null"
#  1
#  default via 192.168.3.1 dev lcm0 

Update to prplOS container to v2:

  $ R "${S} && update_ctr --version prplos-v2 --ee --uuid --privileged false --network --userroles full_caps" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v2
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)

### Network connectivity test can only be done unpriv container gets the capability in its own net ns to 
### bind to a system port (< 1024) or test container is modified to not use system ports for SSH
### Test only checks the attribution of IP address
Check NetworkConfig correctly applied:

  $ R "${S} && get_ctr_ip --uuid"
  192.168.*.* (glob)
#  $ R "rm -f /root/.ssh/known_hosts > /dev/null; ssh -y root@${CTR_IP} 'cat /etc/container-version ; ip route show default | grep default' 2> /dev/null"
#  2
#  default via 192.168.3.1 dev lcm0 

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
