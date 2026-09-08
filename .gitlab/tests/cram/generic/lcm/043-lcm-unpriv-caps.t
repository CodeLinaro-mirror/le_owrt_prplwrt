Set-up the test configuration

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh"
  $ C ${TESTDIR}/script_functions.sh root@${TARGET_LAN_IP}:/tmp/script_functions.sh 2>/dev/null
  $ BOARD_ARCH=$(R "${S} && get_true_arch_name")
  $ SERVICE_URL="docker://registry.gitlab.com/prpl-foundation/prplos/prplos/${BOARD_ARCH}/alpine:3.16"

  $ USERROLE="lcm_netaccess"

## Test SETUP
Create user roles with capabilities
  $ R "${S} && add_user_role --rolename ${USERROLE} --capabilities \"CAP_NET_RAW,CAP_NET_BIND_SERVICE,CAP_KILL\" | sed '/^$/d'"
  {"Device.Users.Role.*.":{"Alias":"lcm_netaccess","RoleName":"lcm_netaccess"}} (glob)

Add user role to the ExecutionEnvironment
  $ R "${S} && set_ee_roles --userroles \"${USERROLE}\" | sed '/^$/d'"
  SoftwareModules.ExecEnv.1.ModifyAvailableRoles() returned
  ["",{"err_code":0,"err_msg":""}]

Test running a container with EnableHostNSCapabilities=false
  $ R "${S} && install_ctr --url ${SERVICE_URL} --waittime 20 --ee --uuid --privileged false --enablehostnscapabilities false --userroles ${USERROLE}" > /dev/null
  $ R "${S} && get_container_info --uuid"
  3.16
  Active
  prpl-foundation/prplos/prplos/*/alpine (glob)

C-1 Run a service on port 90 (system port) and check that it is not allowed:

  $ R "${S} && execute_in_container --uuid --cmd 'nc -l -p 90 localhost -w 1'"
  nc: bind: Permission denied
  [1]

Check that the EnableHostNSCapabilities parameter is false
  $ R "${S} && get_container_parameter --uuid --param EnableHostNSCapabilities"
  0

Uninstall the container

  $ R "${S} && uninstall_ctr_and_check --uuid"
  [1]

C-2 Test running a container with EnableHostNSCapabilities=true
  $ R "${S} && install_ctr --url ${SERVICE_URL} --waittime 20 --ee --uuid --privileged false --enablehostnscapabilities true --userroles ${USERROLE}" > /dev/null
  $ R "${S} && get_container_info --uuid"
  3.16
  Active
  prpl-foundation/prplos/prplos/*/alpine (glob)

Run a service on port 90 (system port) and check that it is allowed (it will timeout):

  $ R "${S} && execute_in_container --uuid --cmd 'nc -l -p 90 localhost -w 1'"
  nc: timeout
  [1]

Check that process does not run as root
  $ CTR_ID=$(R "${S} && get_container_parameter --uuid --param EUID")
  $ PID=$(R "lxc-info ${CTR_ID} |  awk '/^PID:/ {print \$2}'")
  $ UID_CTR=$(R "grep Uid /proc/${PID}/status | awk '{print \$2}'")
  $ if [ "${UID_CTR}" = "0" ]; then echo "root"; else echo "not root"; fi
  not root

Check the permissions (CAP_KILL is filtered out by the blacklist, only CAP_NET_RAW and CAP_NET_BIND_SERVICE remain)
  $ R "grep Cap /proc/${PID}/status"
  CapInh:\t0000000000002400 (esc)
  CapPrm:\t0000000000002400 (esc)
  CapEff:\t0000000000002400 (esc)
  CapBnd:\t0000000000002400 (esc)
  CapAmb:\t0000000000002400 (esc)

Check the NoNewPriv setting
  $ R "grep NoNewPriv /proc/${PID}/status"
  NoNewPrivs:\t1 (esc)

Check that the user namespace is the same as the host
  $ NS_HOST=$(R "readlink /proc/1/ns/user")
  $ NS_CTR=$(R "readlink /proc/${PID}/ns/user")
  $ if [ "${NS_HOST}" = "${NS_CTR}" ]; then echo "equal"; else echo "not equal"; fi
  equal

Check that the EnableHostNSCapabilities parameter is true
  $ R "${S} && get_container_parameter --uuid --param EnableHostNSCapabilities"
  1

## CLEANUP

Uninstall the container

  $ R "${S} && uninstall_ctr_and_check --uuid"
  [1]

C-3 Test a container with Privileged=true and EnableHostNSCapabilities=true
  $ R "${S} && install_ctr --url ${SERVICE_URL} --waittime 20 --ee --uuid --privileged true --enablehostnscapabilities true --userroles ${USERROLE}" > /dev/null
  $ R "${S} && get_container_info --uuid"
  3.16
  Active
  prpl-foundation/prplos/prplos/*/alpine (glob)

Check that process runs as root
  $ CTR_ID=$(R "${S} && get_container_parameter --uuid --param EUID")
  $ PID=$(R "lxc-info ${CTR_ID} |  awk '/^PID:/ {print \$2}'")
  $ UID_CTR=$(R "grep Uid /proc/${PID}/status | awk '{print \$2}'")
  $ if [ "${UID_CTR}" = "0" ]; then echo "root"; else echo "not root"; fi
  root

CHeck the log message
  $ R "grep -F 'Settings [EnableHostNSCapabilities] and [Privileged] are both set. [EnableHostNSCapabilities] will be ignored.' /var/log/messages /var/log/messages.1 2>/dev/null | tail -1"
  *Settings [EnableHostNSCapabilities] and [Privileged] are both set. [EnableHostNSCapabilities] will be ignored.* (glob)
## CLEANUP

Uninstall the container

  $ R "${S} && uninstall_ctr_and_check --uuid"
  [1]

C-4 Test a container without EnableHostNSCapabilities parameter. The setting should be false.
  $ R "${S} && install_ctr --url ${SERVICE_URL} --waittime 20 --ee --uuid --privileged false --userroles ${USERROLE}" > /dev/null
  $ R "${S} && get_container_info --uuid"
  3.16
  Active
  prpl-foundation/prplos/prplos/*/alpine (glob)

Check that the EnableHostNSCapabilities parameter is false
  $ R "${S} && get_container_parameter --uuid --param EnableHostNSCapabilities"
  0

Uninstall the container

  $ R "${S} && uninstall_ctr_and_check --uuid"
  [1]

Remove the role again from the ExecutionEnvironment
  $ R "${S} && set_ee_roles --userroles \"\" | sed '/^$/d'"
  SoftwareModules.ExecEnv.1.ModifyAvailableRoles() returned
  ["",{"err_code":0,"err_msg":""}]

No user roles should be present
  $ R "${S} && check_available_user_roles | sed '/^$/d'"

Remove ${USERROLE} from Device.Users.Role
  $ R "${S} && remove_user_role --rolename ${USERROLE} | sed '/^$/d'"
  ["Device.Users.Role.*."] (glob)

Cleanup test environment:

  $ R "rm -f /tmp/script_functions.sh"
