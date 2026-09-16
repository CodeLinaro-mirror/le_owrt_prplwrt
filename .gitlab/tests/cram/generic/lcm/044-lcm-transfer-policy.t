Set up the transfer policy test.

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh && . /tmp/transfer_policy.sh"
  $ C "${TESTDIR}/script_functions.sh" "root@${TARGET_LAN_IP}:/tmp/script_functions.sh" 2>/dev/null
  $ cat > transfer_policy.sh <<'SH'
  > POLICY_UUID="00000000-0000-5000-b000-000000000044"
  > POLICY_CONFIG=/etc/amx/rlyeh/rlyeh.odl
  > POLICY_BACKUP=/tmp/rlyeh.odl.orig
  > POLICY_START=/tmp/transfer_policy_start
  > policy_restart() {
  >     policy_marker="cram-transfer-config-$(date +%s)-$$"
  >     logger -t cram "$policy_marker" || return 1
  >     rm -f "$POLICY_START"
  >     service cthulhu stop >/dev/null 2>&1 || return 1
  >     service rlyeh stop >/dev/null 2>&1 || return 1
  >     service timingila stop >/dev/null 2>&1 || return 1
  >     service rlyeh start >/dev/null 2>&1 || return 1
  >     service cthulhu start >/dev/null 2>&1 || return 1
  >     sleep 2
  >     service timingila start >/dev/null 2>&1 || return 1
  >     sleep 5
  >     policy_wait=0
  >     while :; do
  >         logread | sed -n "/${policy_marker}/,\$p" | grep -oE 'transfer config: low-speed-limit=[0-9]+ low-speed-time=[0-9]+ connect-timeout=[0-9]+ maximum-retry-count=[0-9]+ retry-minimum-wait-interval=[0-9]+ retry-maximum-wait-interval=[0-9]+ retry-interval-multiplier=[0-9]+' | tail -n 1 > "$POLICY_START"
  >         if [ -s "$POLICY_START" ] && cli_cmd 'SoftwareModules.?' >/dev/null 2>&1; then
  >             return 0
  >         fi
  >         if [ "$policy_wait" -ge 30 ]; then
  >             echo 'Transfer config START line or SoftwareModules readiness missing after 30 seconds' >&2
  >             return 1
  >         fi
  >         sleep 1
  >         policy_wait=$((policy_wait + 1))
  >     done
  > }
  > policy_set() {
  >     [ "$#" -gt 0 ] && [ $(( $# % 2 )) -eq 0 ] || return 1
  >     policy_expected=""
  >     while [ "$#" -gt 0 ]; do
  >         policy_key="$1"
  >         policy_value="$2"
  >         shift 2
  >         case "$policy_key" in
  >             low-speed-limit|low-speed-time|connect-timeout|maximum-retry-count|retry-minimum-wait-interval|retry-maximum-wait-interval|retry-interval-multiplier) ;;
  >             *) echo "Unknown transfer key: $policy_key" >&2; return 1 ;;
  >         esac
  >         case "$policy_value" in
  >             ''|*[!0-9]*) echo 'Transfer values must be unsigned integers' >&2; return 1 ;;
  >         esac
  >         sed -n '/^[[:space:]]*transfer[[:space:]]*=[[:space:]]*{/,/^[[:space:]]*};/p' "$POLICY_CONFIG" | grep -Eq "^[[:space:]]*${policy_key}[[:space:]]*=[[:space:]]*[0-9]+" || return 1
  >         sed -i "/^[[:space:]]*transfer[[:space:]]*=[[:space:]]*{/,/^[[:space:]]*};/s/^\([[:space:]]*${policy_key}[[:space:]]*=[[:space:]]*\)[0-9][0-9]*/\1${policy_value}/" "$POLICY_CONFIG" || return 1
  >         policy_expected="$policy_expected $policy_key=$policy_value"
  >     done
  >     policy_restart || return 1
  >     for policy_pair in $policy_expected; do
  >         grep -Eq "(^| )${policy_pair}( |$)" "$POLICY_START" || return 1
  >     done
  > }
  > policy_restore() {
  >     [ -f "$POLICY_BACKUP" ] || return 0
  >     policy_backup_md5=$(md5sum < "$POLICY_BACKUP") || return 1
  >     policy_config_md5=$(md5sum < "$POLICY_CONFIG") || return 1
  >     if [ "$policy_backup_md5" != "$policy_config_md5" ]; then
  >         cp "$POLICY_BACKUP" "$POLICY_CONFIG" || return 1
  >         policy_restart || return 1
  >     fi
  > }
  > start_du_state_change_sub() {
  >     _du_sub_uuid="$1"
  >     _du_sub_script="/tmp/du_state_change.lua"
  >     if [ -f "${_du_sub_script}" ]; then
  >         rm -f /tmp/du_state_change_out.txt
  >         lua "${_du_sub_script}" "${_du_sub_uuid}" > /tmp/du_state_change_out.txt 2>&1 &
  >         _DU_SUB_PID=$!
  >         sleep 1
  >     else
  >         _DU_SUB_PID=""
  >     fi
  > }
  > wait_du_state_change_sub() {
  >     if [ -n "${_DU_SUB_PID}" ]; then
  >         event_wait=0
  >         while [ ! -s /tmp/du_state_change_out.txt ] && [ "$event_wait" -lt "${POLICY_EVENT_WAIT:-1}" ]; do
  >             sleep 1
  >             event_wait=$((event_wait + 1))
  >         done
  >         kill "${_DU_SUB_PID}" 2>/dev/null
  >         wait "${_DU_SUB_PID}" 2>/dev/null
  >         if [ -s /tmp/du_state_change_out.txt ]; then
  >             cat /tmp/du_state_change_out.txt >&2
  >         fi
  >         rm -f /tmp/du_state_change_out.txt
  >         _DU_SUB_PID=""
  >     fi
  > }
  > policy_fault() (
  >     POLICY_EVENT_WAIT=15
  >     url="$1"
  >     install_result=$(install_ctr_no_wait --url "$url" --ee --uuid "$POLICY_UUID" 2>&1)
  >     install_json=$(printf '%s\n' "$install_result" | sed -n '/^\[/p')
  >     fault_code=$(printf '%s\n' "$install_json" | jsonfilter -e '@[1].err_code')
  >     fault_string=$(printf '%s\n' "$install_json" | jsonfilter -e '@[1].err_msg')
  >     if [ "$fault_code" != "7002" ] || [ -z "$fault_string" ]; then
  >         printf '%s\n' "$install_result"
  >         echo 'InstallDU did not return the expected transfer fault'
  >         exit 1
  >     fi
  >     printf '%s\n' "$install_result" | grep -q '^DUStateChange! ERROR: operation=Install state=Failed FaultCode=7002 ' || {
  >         printf '%s\n' "$install_result"
  >         echo 'no matching DUStateChange event'
  >         exit 1
  >     }
  >     printf 'InstallDU FaultCode=%s FaultString=%s\n' "$fault_code" "$fault_string"
  > )
  > policy_cleanup() {
  >     policy_restore || return 1
  >     uninstall_ctr --uuid "$POLICY_UUID" --retaindata false >/dev/null 2>&1
  >     rm -f "$POLICY_BACKUP" "$POLICY_START" /tmp/du_state_change.lua /tmp/du_state_change_out.txt /tmp/transfer_policy.sh /tmp/script_functions.sh
  > }
  > SH
  $ C transfer_policy.sh "root@${TARGET_LAN_IP}:/tmp/transfer_policy.sh" 2>/dev/null
  $ R "${S} && { [ -f \"\${POLICY_BACKUP}\" ] || cp \"\${POLICY_CONFIG}\" \"\${POLICY_BACKUP}\"; }"
  $ BOARD_ARCH=$(R "${S} && get_true_arch_name")
  $ SERVICE_URL="docker://registry.gitlab.com/prpl-foundation/prplos/prplos/${BOARD_ARCH}/alpine:3.16"
  $ FAIL_URL="docker://192.0.2.1/lcmtest/alpine:latest"

  $ USERROLE="lcm_transfer"

Restart with the untouched ODL config and check all seven START defaults.

  $ R "${S} && policy_restart && grep -Fx 'transfer config: low-speed-limit=30 low-speed-time=30 connect-timeout=10 maximum-retry-count=3 retry-minimum-wait-interval=2 retry-maximum-wait-interval=8 retry-interval-multiplier=2' \"\${POLICY_START}\""
  transfer config: low-speed-limit=30 low-speed-time=30 connect-timeout=10 maximum-retry-count=3 retry-minimum-wait-interval=2 retry-maximum-wait-interval=8 retry-interval-multiplier=2

Force a connect timeout with no retry. Capture the matching UUID's
InstallDU fault and check both the fault code and curl diagnostic.

  $ R "${S} && policy_set connect-timeout 1 maximum-retry-count 0" >/dev/null
  $ R "${S} && policy_fault '${FAIL_URL}'" > fault.txt 2>&1
  $ R "${S} && uninstall_ctr --uuid \"\${POLICY_UUID}\" --retaindata false" >/dev/null 2>&1 || true
  $ sed -n 's/^.* FaultCode=\([0-9]*\) FaultString=.*/FaultCode = \1/p' fault.txt
  FaultCode = 7002
  $ sed -n 's/^.* FaultString=\(.*\)$/FaultString = "\1"/p' fault.txt
  FaultString = "Pull image [*] failed [Curl download content error [Connection timed out after * milliseconds] URL [*]]" (glob)

Repeat with two retries and short wait windows. Use a fresh log marker so
retry messages from earlier tests cannot satisfy these assertions.

  $ R "${S} && policy_set maximum-retry-count 2 retry-minimum-wait-interval 1 retry-maximum-wait-interval 1" >/dev/null
  $ RETRY_MARKER="cram-transfer-policy-$(date +%s)-$$"
  $ R "logger -t cram '${RETRY_MARKER}'"
  $ R "${S} && policy_fault '${FAIL_URL}'" > fault.txt 2>&1
  $ R "${S} && uninstall_ctr --uuid \"\${POLICY_UUID}\" --retaindata false" >/dev/null 2>&1 || true
  $ sed -n 's/^.* FaultCode=\([0-9]*\) FaultString=.*/FaultCode = \1/p' fault.txt
  FaultCode = 7002
  $ sed -n 's/^.* FaultString=\(.*\)$/FaultString = "\1"/p' fault.txt
  FaultString = "Pull image [*] failed [Curl download content error [Connection timed out after * milliseconds] URL [*]]" (glob)
  $ R logread | sed -n "/${RETRY_MARKER}/,\$p" | grep -o 'transfer retry [12]/2' | sort -u
  transfer retry 1/2
  transfer retry 2/2

Restore the defaults and prove installation succeeds with the real alpine image.

  $ R "${S} && policy_restore && grep -Fx 'transfer config: low-speed-limit=30 low-speed-time=30 connect-timeout=10 maximum-retry-count=3 retry-minimum-wait-interval=2 retry-maximum-wait-interval=8 retry-interval-multiplier=2' \"\${POLICY_START}\""
  transfer config: low-speed-limit=30 low-speed-time=30 connect-timeout=10 maximum-retry-count=3 retry-minimum-wait-interval=2 retry-maximum-wait-interval=8 retry-interval-multiplier=2

## Test SETUP
Create user roles with capabilities
  $ R "${S} && add_user_role --rolename ${USERROLE} --capabilities \"CAP_NET_RAW,CAP_NET_BIND_SERVICE,CAP_KILL\" | sed '/^$/d'"
  {"Device.Users.Role.*.":{"Alias":"lcm_transfer","RoleName":"lcm_transfer"}} (glob)

Add user role to the ExecutionEnvironment
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

  $ R "${S} && policy_cleanup" >/dev/null
  $ R "rm -f /tmp/script_functions.sh /tmp/transfer_policy.sh"
