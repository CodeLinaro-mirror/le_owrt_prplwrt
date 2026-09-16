#!/bin/sh

# Source after script_functions.sh. These event-subscription overrides and
# configuration changes are specific to the transfer-policy test.

POLICY_UUID="00000000-0000-5000-b000-000000000044"
POLICY_CONFIG=/etc/amx/rlyeh/rlyeh.odl
POLICY_BACKUP=/tmp/rlyeh.odl.orig
POLICY_START=/tmp/transfer_policy_start
policy_restart() {
    policy_marker="cram-transfer-config-$(date +%s)-$$"
    logger -t cram "$policy_marker" || return 1
    rm -f "$POLICY_START"
    service cthulhu stop >/dev/null 2>&1 || return 1
    service rlyeh stop >/dev/null 2>&1 || return 1
    service timingila stop >/dev/null 2>&1 || return 1
    service rlyeh start >/dev/null 2>&1 || return 1
    service cthulhu start >/dev/null 2>&1 || return 1
    sleep 2
    service timingila start >/dev/null 2>&1 || return 1
    sleep 5
    policy_wait=0
    while :; do
        logread | sed -n "/${policy_marker}/,\$p" | grep -oE 'transfer config: low-speed-limit=[0-9]+ low-speed-time=[0-9]+ connect-timeout=[0-9]+ maximum-retry-count=[0-9]+ retry-minimum-wait-interval=[0-9]+ retry-maximum-wait-interval=[0-9]+ retry-interval-multiplier=[0-9]+' | tail -n 1 > "$POLICY_START"
        if [ -s "$POLICY_START" ] && cli_cmd 'SoftwareModules.?' >/dev/null 2>&1; then
            return 0
        fi
        if [ "$policy_wait" -ge 30 ]; then
            echo 'Transfer config START line or SoftwareModules readiness missing after 30 seconds' >&2
            return 1
        fi
        sleep 1
        policy_wait=$((policy_wait + 1))
    done
}
policy_set() {
    [ "$#" -gt 0 ] && [ $(( $# % 2 )) -eq 0 ] || return 1
    policy_expected=""
    while [ "$#" -gt 0 ]; do
        policy_key="$1"
        policy_value="$2"
        shift 2
        case "$policy_key" in
            low-speed-limit|low-speed-time|connect-timeout|maximum-retry-count|retry-minimum-wait-interval|retry-maximum-wait-interval|retry-interval-multiplier) ;;
            *) echo "Unknown transfer key: $policy_key" >&2; return 1 ;;
        esac
        case "$policy_value" in
            ''|*[!0-9]*) echo 'Transfer values must be unsigned integers' >&2; return 1 ;;
        esac
        sed -n '/^[[:space:]]*transfer[[:space:]]*=[[:space:]]*{/,/^[[:space:]]*};/p' "$POLICY_CONFIG" | grep -Eq "^[[:space:]]*${policy_key}[[:space:]]*=[[:space:]]*[0-9]+" || return 1
        sed -i "/^[[:space:]]*transfer[[:space:]]*=[[:space:]]*{/,/^[[:space:]]*};/s/^\([[:space:]]*${policy_key}[[:space:]]*=[[:space:]]*\)[0-9][0-9]*/\1${policy_value}/" "$POLICY_CONFIG" || return 1
        policy_expected="$policy_expected $policy_key=$policy_value"
    done
    policy_restart || return 1
    for policy_pair in $policy_expected; do
        grep -Eq "(^| )${policy_pair}( |$)" "$POLICY_START" || return 1
    done
}
policy_restore() {
    [ -f "$POLICY_BACKUP" ] || return 0
    policy_backup_md5=$(md5sum < "$POLICY_BACKUP") || return 1
    policy_config_md5=$(md5sum < "$POLICY_CONFIG") || return 1
    if [ "$policy_backup_md5" != "$policy_config_md5" ]; then
        cp "$POLICY_BACKUP" "$POLICY_CONFIG" || return 1
        policy_restart || return 1
    fi
}
start_du_state_change_sub() {
    _du_sub_uuid="$1"
    _du_sub_script="/tmp/du_state_change.lua"
    if [ -f "${_du_sub_script}" ]; then
        rm -f /tmp/du_state_change_out.txt
        lua "${_du_sub_script}" "${_du_sub_uuid}" > /tmp/du_state_change_out.txt 2>&1 &
        _DU_SUB_PID=$!
        sleep 1
    else
        _DU_SUB_PID=""
    fi
}
wait_du_state_change_sub() {
    if [ -n "${_DU_SUB_PID}" ]; then
        event_wait=0
        while [ ! -s /tmp/du_state_change_out.txt ] && [ "$event_wait" -lt "${POLICY_EVENT_WAIT:-1}" ]; do
            sleep 1
            event_wait=$((event_wait + 1))
        done
        kill "${_DU_SUB_PID}" 2>/dev/null
        wait "${_DU_SUB_PID}" 2>/dev/null
        if [ -s /tmp/du_state_change_out.txt ]; then
            cat /tmp/du_state_change_out.txt >&2
        fi
        rm -f /tmp/du_state_change_out.txt
        _DU_SUB_PID=""
    fi
}
policy_fault() (
    POLICY_EVENT_WAIT=15
    url="$1"
    install_result=$(install_ctr_no_wait --url "$url" --ee --uuid "$POLICY_UUID" 2>&1)
    install_json=$(printf '%s\n' "$install_result" | sed -n '/^\[/p')
    fault_code=$(printf '%s\n' "$install_json" | jsonfilter -e '@[1].err_code')
    fault_string=$(printf '%s\n' "$install_json" | jsonfilter -e '@[1].err_msg')
    if [ "$fault_code" != "7002" ] || [ -z "$fault_string" ]; then
        printf '%s\n' "$install_result"
        echo 'InstallDU did not return the expected transfer fault'
        exit 1
    fi
    printf '%s\n' "$install_result" | grep -q '^DUStateChange! ERROR: operation=Install state=Failed FaultCode=7002 ' || {
        printf '%s\n' "$install_result"
        echo 'no matching DUStateChange event'
        exit 1
    }
    printf 'InstallDU FaultCode=%s FaultString=%s\n' "$fault_code" "$fault_string"
)
policy_cleanup() {
    policy_restore || return 1
    uninstall_ctr --uuid "$POLICY_UUID" --retaindata false >/dev/null 2>&1
    rm -f "$POLICY_BACKUP" "$POLICY_START" /tmp/du_state_change.lua /tmp/du_state_change_out.txt /tmp/transfer_policy.sh /tmp/script_functions.sh
}

# Keep scenario setup separate so configuration failures remain visible to cram.
configure_transfer_without_retries() {
    policy_set connect-timeout 1 maximum-retry-count 0
}

# Retain the one-second connect timeout configured by the first scenario.
configure_transfer_with_two_retries() {
    policy_set maximum-retry-count 2 retry-minimum-wait-interval 1 retry-maximum-wait-interval 1
}

# Always remove the failed deployment, but preserve the fault assertion status.
run_transfer_failure_scenario() (
    policy_fault "$1"
    policy_fault_status=$?
    uninstall_ctr --uuid "$POLICY_UUID" --retaindata false >/dev/null 2>&1 || true
    exit "$policy_fault_status"
)
