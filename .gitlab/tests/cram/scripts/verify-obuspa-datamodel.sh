#!/bin/sh

set -eu

usage() {
    cat >&2 <<'EOF'
Usage:
  verify-obuspa-datamodel.sh --mode MODE --expected FILE --actual FILE [--diff FILE]
  verify-obuspa-datamodel.sh --mode MODE --expected FILE \
    --before-actual FILE [--before-diff FILE] \
    --after-actual FILE [--after-diff FILE]
EOF
    exit 2
}

mode=
expected=
actual=
diff_output=
before_actual=
before_diff=
after_actual=
after_diff=
remote_dump_script=/tmp/obuspa-datamodel-dump.sh
remote_diag_script=/tmp/obuspa-diagnostics.sh
remote_snapshot=
# Set by wait_device_up when the DUT never reports DeviceStatus Up, only
# reported in the .diag file (stderr is part of the cram test output)
device_up_warning=
# Maximum time to wait for DeviceInfo.DeviceStatus to become Up
device_up_timeout=${OBUSPA_DEVICE_UP_TIMEOUT:-180}
# Maximum time to wait for the obuspa datamodel to match the expected one,
# USP Services register asynchronously and may still be registering
datamodel_timeout=${OBUSPA_DATAMODEL_TIMEOUT:-90}
retry_interval=${OBUSPA_RETRY_INTERVAL:-5}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --mode)
            mode=$2
            shift 2
            ;;
        --expected)
            expected=$2
            shift 2
            ;;
        --actual)
            actual=$2
            shift 2
            ;;
        --diff)
            diff_output=$2
            shift 2
            ;;
        --before-actual)
            before_actual=$2
            shift 2
            ;;
        --before-diff)
            before_diff=$2
            shift 2
            ;;
        --after-actual)
            after_actual=$2
            shift 2
            ;;
        --after-diff)
            after_diff=$2
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

[ -n "$mode" ] || usage
[ -n "$expected" ] || usage
[ -f "$expected" ] || {
    printf '%s\n' "Missing expected fixture: $expected" >&2
    exit 1
}

if [ -n "$actual" ] && [ -n "$before_actual" ]; then
    usage
fi

if [ -n "$actual" ] && [ -z "$diff_output" ]; then
    diff_output="${actual%.*}.diff"
fi

if [ -n "$before_actual" ] && [ -z "$before_diff" ]; then
    before_diff="${before_actual%.*}.diff"
fi

if [ -n "$after_actual" ] && [ -z "$after_diff" ]; then
    after_diff="${after_actual%.*}.diff"
fi

if [ -n "$actual" ]; then
    :
elif [ -n "$before_actual" ] && [ -n "$after_actual" ]; then
    :
else
    usage
fi

R() { ${CRAM_REMOTE_COMMAND:-} "$@"; }
C() { ${CRAM_REMOTE_COPY:-scp} "$@"; }

remote_host=${TARGET_LAN_IP:-}
if [ -z "$remote_host" ] && [ -n "${CRAM_REMOTE_COMMAND:-}" ]; then
    remote_host=$(printf '%s\n' "${CRAM_REMOTE_COMMAND:-}" |
        sed -n 's/.*@\([^ ]*\).*/\1/p')
fi

[ -n "$remote_host" ] || {
    printf '%s\n' "TARGET_LAN_IP or CRAM_REMOTE_COMMAND is required" >&2
    exit 1
}

target_dir=$(CDPATH= cd -- "$(dirname -- "$0")/target" && pwd)
target_script=${target_dir}/obuspa-datamodel-dump.sh
diag_script=${target_dir}/obuspa-diagnostics.sh

cleanup() {
    if [ -n "$remote_snapshot" ]; then
        R "rm -f '${remote_snapshot}'" >/dev/null 2>&1 || true
    fi
    R "rm -f '${remote_dump_script}' '${remote_diag_script}'" >/dev/null 2>&1 || true
}

trap cleanup EXIT HUP INT TERM

C "$target_script" "root@${remote_host}:${remote_dump_script}" >/dev/null 2>&1 || {
    printf '%s\n' "Failed to copy ${target_script} to ${remote_host}" >&2
    exit 1
}

capture_actual() {
    tmp_actual=$(mktemp "${TMPDIR:-/tmp}/obuspa-datamodel.actual.XXXXXX")

    remote_snapshot=$(R "mktemp /tmp/obuspa-datamodel.${mode}.XXXXXX") || {
        rm -f "$tmp_actual"
        printf '%s\n' "Failed to allocate remote snapshot file" >&2
        return 1
    }

    R "sh '${remote_dump_script}' '${mode}' > '${remote_snapshot}'" >/dev/null || {
        rm -f "$tmp_actual"
        printf '%s\n' "Failed to capture ${mode} obuspa datamodel on DUT" >&2
        return 1
    }

    C "root@${remote_host}:${remote_snapshot}" "$tmp_actual" >/dev/null 2>&1 || {
        rm -f "$tmp_actual"
        printf '%s\n' "Failed to copy ${mode} obuspa datamodel from ${remote_host}" >&2
        return 1
    }

    R "rm -f '${remote_snapshot}'" >/dev/null 2>&1 || true
    remote_snapshot=
    printf '%s\n' "$tmp_actual"
}

wait_device_up() {
    deadline=$(($(date +%s) + device_up_timeout))

    while :; do
        status=$(R "ba-cli -l DeviceInfo.DeviceStatus?" 2>/dev/null | tr -d '\r\n"') || true
        [ "$status" = "Up" ] && return 0
        [ "$(date +%s)" -lt "$deadline" ] || break
        sleep "$retry_interval"
    done

    # Not fatal, the datamodel retry loop still covers late registrations
    device_up_warning="DeviceInfo.DeviceStatus not Up after ${device_up_timeout}s (last: '${status}')"
}

# Collect diagnostics from the DUT into a .diag file next to the actual
# snapshot, as mismatches are mostly seen in CI where the DUT can't be accessed
collect_diagnostics() {
    diff_file=$1
    diag_file=$2

    # USP Services owning the missing or unexpected elements
    endpoints=$(sed -n 's/^[-+]Device\..*[[:space:]]\(proto::[^[:space:]]*\)$/\1/p' "$diff_file" |
        sort -u | tr '\n' ' ')

    {
        printf 'Phase: %s\n' "$phase"
        [ -z "$device_up_warning" ] || printf '%s\n' "$device_up_warning"
        printf 'USP Services with mismatching elements: %s\n' "${endpoints:-none}"
        if C "$diag_script" "root@${remote_host}:${remote_diag_script}" >/dev/null 2>&1; then
            # shellcheck disable=SC2086
            R "sh '${remote_diag_script}' ${endpoints}" 2>&1
        else
            printf '%s\n' "Failed to copy ${diag_script} to ${remote_host}"
        fi
    } >"$diag_file"

    printf 'USP Services with mismatching elements: %s\n' "${endpoints:-none}" >&2
    printf '%s\n' "Saved diagnostics to $diag_file" >&2
}

verify_snapshot() {
    phase=$1
    actual_output=$2
    diff_file=$3
    label=$4
    capture_err=$(mktemp "${TMPDIR:-/tmp}/obuspa-datamodel.err.XXXXXX")
    deadline=$(($(date +%s) + datamodel_timeout))
    rc=2

    diag_output="${actual_output%.*}.diag"

    mkdir -p "$(dirname -- "$actual_output")" "$(dirname -- "$diff_file")"
    rm -f "$actual_output" "$diff_file" "$diag_output"

    # USP Services register asynchronously with obuspa (at boot or after an
    # obuspa restart), so retry until the datamodel matches or timeout expires
    while :; do
        rm -f "$actual_output"
        if tmp_actual=$(capture_actual 2>"$capture_err"); then
            if diff -u --label expected --label "$label" \
                "$expected" "$tmp_actual" >"$diff_file"; then
                rm -f "$tmp_actual" "$diff_file" "$capture_err"
                return 0
            fi
            mv "$tmp_actual" "$actual_output"
            rc=1
        else
            rc=2
        fi

        [ "$(date +%s)" -lt "$deadline" ] || break
        sleep "$retry_interval"
    done

    if [ "$rc" -eq 2 ]; then
        cat "$capture_err" >&2
        rm -f "$capture_err" "$diff_file"
        return 2
    fi

    rm -f "$capture_err"
    cat "$diff_file"
    printf '%s\n' "Saved actual snapshot to $actual_output" >&2
    printf '%s\n' "Saved diff to $diff_file" >&2
    collect_diagnostics "$diff_file" "$diag_output"
    return 1
}

wait_device_up

if [ -n "$actual" ]; then
    verify_snapshot single "$actual" "$diff_output" "${mode}_actual"
    exit "$?"
fi

failed=0
verify_snapshot before_restart "$before_actual" "$before_diff" "${mode}_before_restart" || failed=1

R "service obuspa restart" >/dev/null || {
    printf '%s\n' "Failed to restart obuspa on DUT" >&2
    exit 1
}

verify_snapshot after_restart "$after_actual" "$after_diff" "${mode}_after_restart" || failed=1
exit "$failed"
