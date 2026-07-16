## Setup test configuration
Set-up the test configuration:


  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh"
  $ C ${TESTDIR}/script_functions.sh root@${TARGET_LAN_IP}:/tmp/script_functions.sh 2>/dev/null

  $ USERROLE="lcm_netaccess"

C-1 Create user roles with capabilities
  $ R "${S} && add_user_role --rolename ${USERROLE} --capabilities \"CAP_NET_RAW,CAP_NET_BIND_SERVICE,CAP_KILL\" | sed '/^$/d'"
  {"Device.Users.Role.*.":{"Alias":"lcm_netaccess","RoleName":"lcm_netaccess"}} (glob)

C-2 Add user role to the ExecutionEnvironment
  $ R "${S} && set_ee_roles --userroles \"${USERROLE}\" | sed '/^$/d'"
  SoftwareModules.ExecEnv.1.ModifyAvailableRoles() returned
  ["",{"err_code":0,"err_msg":""}]

C-3 Create a container that opens a socket on port 90 EnableHostCapabilities=false
  $ R "${S} && install_ctr --url_arch listen-port-90 --wait-time 20 --ee --uuid --privileged false --enablehostcapabilities false --userroles ${USERROLE}" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Idle
  latest
  prpl-foundation/prplos/prplos/lcm_tests/*_listen-port-90 (glob)

Uninstall the container

  $ R "${S} && uninstall_ctr_and_check --uuid"
  [1]

C-4 Create a container that opens a socket on port 90 EnableHostCapabilities=true
  $ R "${S} && install_ctr --url_arch listen-port-90 --wait-time 20 --ee --uuid --privileged false --enablehostcapabilities true --userroles ${USERROLE}" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  latest
  prpl-foundation/prplos/prplos/lcm_tests/*_listen-port-90 (glob)

Check that process does not run as root
  $ CTR_ID=$(R "${S} && get_container_parameter --uuid --param EUID")
  $ PID=$(R "lxc-info ${CTR_ID} |  awk '/^PID:/ {print \$2}'")
  $ UID_CTR=$(R "grep Uid /proc/${PID}/status | awk '{print \$2}'")
  $ if [ "${UID_CTR}" = "0" ]; then echo "root"; else echo "not root"; fi
  not root

Check the permissions
  $ R "grep Cap /proc/${PID}/status"
  CapInh:\t0000000000002400 (esc)
  CapPrm:\t0000000000002400 (esc)
  CapEff:\t0000000000002400 (esc)
  CapBnd:\t0000000000002400 (esc)
  CapAmb:\t0000000000002400 (esc)

## CLEANUP

Uninstall the container

  $ R "${S} && uninstall_ctr_and_check --uuid"
  [1]

Remove the role again from the ExecutionEnvironment
  $ R "${S} && set_ee_roles --userroles \"\" | sed '/^$/d'"
  SoftwareModules.ExecEnv.1.ModifyAvailableRoles() returned
  ["",{"err_code":0,"err_msg":""}]

No user roles should be present
  $ R "${S} && check_available_user_roles | sed '/^$/d'"

Remove testrole1 from Devices.User.Role
  $ R "${S} && remove_user_role --rolename ${USERROLE} | sed '/^$/d'"
  ["Device.Users.Role.*."] (glob)