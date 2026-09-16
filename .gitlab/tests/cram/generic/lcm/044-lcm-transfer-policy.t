Set up the transfer policy test:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh && . /tmp/transfer_policy.sh"
  $ C "${TESTDIR}/script_functions.sh" "root@${TARGET_LAN_IP}:/tmp/script_functions.sh" 2>/dev/null
  $ C "${TESTDIR}/transfer_policy.sh" "root@${TARGET_LAN_IP}:/tmp/transfer_policy.sh" 2>/dev/null
  $ R "${S} && { [ -f \"\${POLICY_BACKUP}\" ] || cp \"\${POLICY_CONFIG}\" \"\${POLICY_BACKUP}\"; }"
  $ BOARD_ARCH=$(R "${S} && get_true_arch_name")
  $ SERVICE_URL="docker://registry.gitlab.com/prpl-foundation/prplos/prplos/${BOARD_ARCH}/alpine:3.16"
  $ FAIL_URL="docker://192.0.2.1/lcmtest/alpine:latest"

  $ USERROLE="lcm_transfer"

Restart with the untouched ODL config and check all seven START defaults:

  $ R "${S} && policy_restart && grep -Fx 'transfer config: low-speed-limit=30 low-speed-time=30 connect-timeout=10 maximum-retry-count=3 retry-minimum-wait-interval=2 retry-maximum-wait-interval=8 retry-interval-multiplier=2' \"\${POLICY_START}\""
  transfer config: low-speed-limit=30 low-speed-time=30 connect-timeout=10 maximum-retry-count=3 retry-minimum-wait-interval=2 retry-maximum-wait-interval=8 retry-interval-multiplier=2

Force a connect timeout with no retry. Capture the matching UUID's
InstallDU fault and check both the fault code and curl diagnostic:

  $ R "${S} && configure_transfer_without_retries" >/dev/null
  $ R "${S} && run_transfer_failure_scenario '${FAIL_URL}'" > fault.txt 2>&1
  $ sed -n 's/^.* FaultCode=\([0-9]*\) FaultString=.*/FaultCode = \1/p' fault.txt
  FaultCode = 7002
  $ sed -n 's/^.* FaultString=\(.*\)$/FaultString = "\1"/p' fault.txt
  FaultString = "Pull image [*] failed [Curl download content error [Connection timed out after * milliseconds] URL [*]]" (glob)

Repeat with two retries and short wait windows. Use a fresh log marker so
retry messages from earlier tests cannot satisfy these assertions:

  $ R "${S} && configure_transfer_with_two_retries" >/dev/null
  $ RETRY_MARKER="cram-transfer-policy-$(date +%s)-$$"
  $ R "logger -t cram '${RETRY_MARKER}'"
  $ R "${S} && run_transfer_failure_scenario '${FAIL_URL}'" > fault.txt 2>&1
  $ sed -n 's/^.* FaultCode=\([0-9]*\) FaultString=.*/FaultCode = \1/p' fault.txt
  FaultCode = 7002
  $ sed -n 's/^.* FaultString=\(.*\)$/FaultString = "\1"/p' fault.txt
  FaultString = "Pull image [*] failed [Curl download content error [Connection timed out after * milliseconds] URL [*]]" (glob)
  $ R logread | sed -n "/${RETRY_MARKER}/,\$p" | grep -o 'transfer retry [12]/2' | sort -u
  transfer retry 1/2
  transfer retry 2/2

Restore the defaults and prove installation succeeds with the real alpine image:

  $ R "${S} && policy_restore && grep -Fx 'transfer config: low-speed-limit=30 low-speed-time=30 connect-timeout=10 maximum-retry-count=3 retry-minimum-wait-interval=2 retry-maximum-wait-interval=8 retry-interval-multiplier=2' \"\${POLICY_START}\""
  transfer config: low-speed-limit=30 low-speed-time=30 connect-timeout=10 maximum-retry-count=3 retry-minimum-wait-interval=2 retry-maximum-wait-interval=8 retry-interval-multiplier=2

## Test SETUP:

Create user roles with capabilities:

  $ R "${S} && add_user_role --rolename ${USERROLE} --capabilities \"CAP_NET_RAW,CAP_NET_BIND_SERVICE,CAP_KILL\" | sed '/^$/d'"
  {"Device.Users.Role.*.":{"Alias":"lcm_transfer","RoleName":"lcm_transfer"}} (glob)

Add user role to the ExecutionEnvironment:

  $ R "${S} && set_ee_roles --userroles \"${USERROLE}\" | sed '/^$/d'"
  SoftwareModules.ExecEnv.1.ModifyAvailableRoles() returned
  ["",{"err_code":0,"err_msg":""}]

  $ R "${S} && install_ctr --url '${SERVICE_URL}' --waittime 60 --ee --uuid \"\${POLICY_UUID}\" --privileged false --enablehostcapabilities false --userroles ${USERROLE}" >/dev/null
  $ R "${S} && get_container_info --uuid \"\${POLICY_UUID}\""
  3.16
  Active
  prpl-foundation/prplos/prplos/*/alpine (glob)
  $ R "${S} && uninstall_ctr_and_check --uuid \"\${POLICY_UUID}\" --retaindata false"
  [1]

Remove the role again from the ExecutionEnvironment:

  $ R "${S} && set_ee_roles --userroles \"\" | sed '/^$/d'"
  SoftwareModules.ExecEnv.1.ModifyAvailableRoles() returned
  ["",{"err_code":0,"err_msg":""}]

No user roles should be present:

  $ R "${S} && check_available_user_roles | sed '/^$/d'"

Remove ${USERROLE} from Device.Users.Role:

  $ R "${S} && remove_user_role --rolename ${USERROLE} | sed '/^$/d'"
  ["Device.Users.Role.*."] (glob)

Cleanup test environment:

  $ R "${S} && policy_cleanup" >/dev/null
  $ R "rm -f /tmp/script_functions.sh /tmp/transfer_policy.sh"
