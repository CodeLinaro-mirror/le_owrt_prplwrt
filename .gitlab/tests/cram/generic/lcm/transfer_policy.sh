#!/bin/sh

# Source after script_functions.sh. These event-subscription overrides and
# configuration changes are specific to the transfer-policy test.

POLICY_UUID="00000000-0000-5000-b000-000000000044"
POLICY_CONFIG=/etc/amx/rlyeh/rlyeh.odl
POLICY_BACKUP=/tmp/rlyeh.odl.orig
POLICY_START=/tmp/transfer_policy_start
POLICY_LOG=/tmp/transfer_policy_log

policy_restart() (
    # Follow the log because hardware can evict lines from the ring buffer.
    logread -f > "$POLICY_LOG" 2>&1 &
    policy_log_pid=$!
    trap '
        kill "$policy_log_pid" 2>/dev/null || true
        wait "$policy_log_pid" 2>/dev/null || true
        rm -f "$POLICY_LOG.pid"
    ' 0
    trap 'exit 1' HUP INT TERM
    echo "$policy_log_pid" > "$POLICY_LOG.pid" || return 1
    # Ignore configuration messages from before this restart.
    policy_marker="cram-transfer-config-$(date +%s)-$$"
    logger -t cram "$policy_marker" || return 1
    rm -f "$POLICY_START"

    service cthulhu stop >/dev/null 2>&1 || return 1
    service rlyeh stop >/dev/null 2>&1 || return 1
    service timingila stop >/dev/null 2>&1 || return 1
    service rlyeh start >/dev/null 2>&1 || return 1
    service cthulhu start >/dev/null 2>&1 || return 1
    # Let cthulhu settle before timingila starts.
    sleep 2
    service timingila start >/dev/null 2>&1 || return 1
    # Allow timingila to initialize before checking configuration and readiness.
    sleep 5

    policy_wait=0
    while :; do
        sed -n "/${policy_marker}/,\$p" "$POLICY_LOG" | grep -oE 'transfer config: low-speed-limit=[0-9]+ low-speed-time=[0-9]+ connect-timeout=[0-9]+ maximum-retry-count=[0-9]+ retry-minimum-wait-interval=[0-9]+ retry-maximum-wait-interval=[0-9]+ retry-interval-multiplier=[0-9]+' | tail -n 1 > "$POLICY_START"
        if [ -s "$POLICY_START" ]; then
            break
        fi
        if [ "$policy_wait" -ge 30 ]; then
            echo 'Transfer config START line missing after 30 seconds' >&2
            return 1
        fi
        sleep 1
        policy_wait=$((policy_wait + 1))
    done

    policy_wait=0
    while :; do
        if cli_cmd 'SoftwareModules.?' >/dev/null 2>&1; then
            return 0
        fi
        if [ "$policy_wait" -ge 120 ]; then
            echo 'SoftwareModules not ready after 120 seconds' >&2
            return 1
        fi
        sleep 1
        policy_wait=$((policy_wait + 1))
    done
)

policy_set() {
    if [ "$#" -eq 0 ] || [ $(( $# % 2 )) -ne 0 ]; then
        return 1
    fi

    policy_expected=""
    while [ "$#" -gt 0 ]; do
        policy_key="$1"
        policy_value="$2"
        shift 2

        case "$policy_key" in
            low-speed-limit|\
            low-speed-time|\
            connect-timeout|\
            maximum-retry-count|\
            retry-minimum-wait-interval|\
            retry-maximum-wait-interval|\
            retry-interval-multiplier)
                ;;
            *)
                echo "Unknown transfer key: $policy_key" >&2
                return 1
                ;;
        esac
        case "$policy_value" in
            ''|*[!0-9]*)
                echo 'Transfer values must be unsigned integers' >&2
                return 1
                ;;
        esac

        sed -n '/^[[:space:]]*transfer[[:space:]]*=[[:space:]]*{/,/^[[:space:]]*};/p' \
            "$POLICY_CONFIG" |
            grep -Eq "^[[:space:]]*${policy_key}[[:space:]]*=[[:space:]]*[0-9]+" || return 1
        sed -i "/^[[:space:]]*transfer[[:space:]]*=[[:space:]]*{/,/^[[:space:]]*};/\
s/^\([[:space:]]*${policy_key}[[:space:]]*=[[:space:]]*\)[0-9][0-9]*/\1${policy_value}/" \
            "$POLICY_CONFIG" || return 1
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

        # Give the subscriber time to register before issuing InstallDU.
        sleep 1
    else
        _DU_SUB_PID=""
    fi
}

wait_du_state_change_sub() {
    if [ -n "${_DU_SUB_PID}" ]; then
        event_wait=0
        while [ ! -s /tmp/du_state_change_out.txt ] &&
            [ "$event_wait" -lt "${POLICY_EVENT_WAIT:-1}" ]; do
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

# Keep the longer event wait and assertion variables local to this fault check.
policy_fault() (
    POLICY_EVENT_WAIT=15
    url="$1"

    install_result=$(install_ctr_no_wait --url "$url" --ee --uuid "$POLICY_UUID" 2>&1)

    # The fault comes back on the DUStateChange! event; the InstallDU call
    # itself fails and its return arguments are not printed on failure.
    fault_line=$(printf '%s\n' "$install_result" |
        sed -n 's/^DUStateChange! ERROR: operation=Install state=Failed //p')
    fault_code=$(printf '%s\n' "$fault_line" | sed -n 's/^FaultCode=\([0-9]*\) FaultString=.*/\1/p')
    fault_string=$(printf '%s\n' "$fault_line" | sed -n 's/^FaultCode=[0-9]* FaultString=//p')
    if [ "$fault_code" != "7002" ] || [ -z "$fault_string" ]; then
        printf '%s\n' "$install_result"
        echo 'InstallDU did not return the expected transfer fault'
        exit 1
    fi

    printf 'InstallDU FaultCode=%s FaultString=%s\n' "$fault_code" "$fault_string"
)

policy_cleanup() {
    if [ -f "$POLICY_LOG.pid" ]; then
        kill "$(cat "$POLICY_LOG.pid")" 2>/dev/null || true
    fi
    rm -f "$POLICY_LOG" "$POLICY_LOG.pid"

    iptables -D OUTPUT -d 192.0.2.1 -j DROP 2>/dev/null || true
    policy_restore || return 1

    uninstall_ctr --uuid "$POLICY_UUID" --retaindata false >/dev/null 2>&1
    rm -f "$POLICY_BACKUP" "$POLICY_START" "$POLICY_LOG" \
        /tmp/du_state_change.lua /tmp/du_state_change_out.txt \
        /tmp/transfer_policy.sh /tmp/script_functions.sh
}

# Keep scenario setup separate so configuration failures remain visible to cram.
configure_transfer_without_retries() {
    policy_set connect-timeout 1 maximum-retry-count 0
}

# Retain the one-second connect timeout configured by the first scenario.
configure_transfer_with_two_retries() {
    policy_set maximum-retry-count 2 retry-minimum-wait-interval 1 retry-maximum-wait-interval 1
}

policy_retry_lines() {
    policy_retry_marker="$1"
    policy_retry_wait=0
    while [ "$policy_retry_wait" -lt 10 ]; do
        policy_retries=$(logread | sed -n "/${policy_retry_marker}/,\$p" |
            grep -o 'transfer retry [12]/2' | sort -u)
        if [ "$(printf '%s\n' "$policy_retries" | grep -c .)" -eq 2 ]; then
            break
        fi
        sleep 1
        policy_retry_wait=$((policy_retry_wait + 1))
    done
    printf '%s\n' "$policy_retries"
}

# Always remove the failed deployment, but preserve the fault assertion status.
run_transfer_failure_scenario() (
    policy_fault "$1"
    policy_fault_status=$?
    uninstall_ctr --uuid "$POLICY_UUID" --retaindata false >/dev/null 2>&1 || true
    exit "$policy_fault_status"
)
