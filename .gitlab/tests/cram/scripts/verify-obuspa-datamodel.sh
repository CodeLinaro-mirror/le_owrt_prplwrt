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
remote_snapshot=

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

target_script=$(CDPATH= cd -- "$(dirname -- "$0")/target" && pwd)/
target_script=${target_script}obuspa-datamodel-dump.sh

cleanup() {
    if [ -n "$remote_snapshot" ]; then
        R "rm -f '${remote_snapshot}'" >/dev/null 2>&1 || true
    fi
    R "rm -f '${remote_dump_script}'" >/dev/null 2>&1 || true
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

verify_snapshot() {
    phase=$1
    actual_output=$2
    diff_file=$3
    label=$4

    mkdir -p "$(dirname -- "$actual_output")" "$(dirname -- "$diff_file")"
    rm -f "$actual_output" "$diff_file"

    tmp_actual=$(capture_actual) || return 2

    if diff -u --label expected --label "$label" \
        "$expected" "$tmp_actual" >"$diff_file"; then
        rm -f "$tmp_actual" "$diff_file"
        return 0
    fi

    mv "$tmp_actual" "$actual_output"
    cat "$diff_file"
    printf '%s\n' "Saved actual snapshot to $actual_output" >&2
    printf '%s\n' "Saved diff to $diff_file" >&2
    return 1
}

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
sleep 20

verify_snapshot after_restart "$after_actual" "$after_diff" "${mode}_after_restart" || failed=1
exit "$failed"
