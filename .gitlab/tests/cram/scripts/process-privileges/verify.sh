#!/usr/bin/env sh
set -e

script_dir="$(dirname $0)"
rules_file="${script_dir}/rules.yml"
timeout="${VERIFY_TIMEOUT:-0}"
interval="${VERIFY_INTERVAL:-2}"
verbose=0

print_help() {
cat << EOF
Usage: $(basename $0) [-t|--timeout <s>] [-i|--interval <s>] [-v] [-h] [<rules>.yml]

Collect the process tree from the remote hgw and verify it against <rules>.yml.
(default: ${script_dir}/rules.yml)

Short-lived processes (a helper started by a plugin, a service restarting before
it dropped its privileges) can make a single snapshot fail. With a timeout, the
tree is collected and verified again until it matches or the timeout expires;
only the result of the last attempt is reported.

Options:
    -t, --timeout <s>   Retry until this many seconds have passed. (default=0: a single attempt)
    -i, --interval <s>  Seconds to wait between attempts. (default=2)
    -v, --verbose       Print the errors of every failed attempt to stderr, also
                        when a later attempt succeeds.
    -h                  Print this help

Environment:
    VERIFY_TIMEOUT      Default for --timeout
    VERIFY_INTERVAL     Default for --interval
    See collect.sh -h for the variables selecting the remote hgw.
EOF
}

is_number() {
    case "$1" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
    esac
}

while [ $# -gt 0 ]; do case "$1" in
-t|--timeout)
    [ $# -ge 2 ] || { print_help >&2; exit 2; }
    timeout="$2"
    shift 2
    ;;
-i|--interval)
    [ $# -ge 2 ] || { print_help >&2; exit 2; }
    interval="$2"
    shift 2
    ;;
-v|--verbose)
    verbose=1
    shift
    ;;
-h)
    print_help
    exit 0
    ;;
*.yml)
    rules_file="$1"
    shift
    ;;
*)
    print_help >&2
    exit 2
    ;;
esac; done

if ! is_number "${timeout}" || ! is_number "${interval}"; then
    printf '%s\n' "timeout and interval must be a whole number of seconds" >&2
    exit 2
fi

collect() {
    "${script_dir}/collect.sh" "$@"
}

work_dir="$(mktemp -d)"
out_file="${work_dir}/out"
err_file="${work_dir}/err"
copied=0

cleanup() {
    if [ "${copied}" -eq 1 ]; then
        collect --stage cleanup || true
    fi
    rm -rf "${work_dir}"
}

trap cleanup EXIT
trap 'exit 130' HUP INT TERM

# Copy the collector, unless an earlier attempt already did, and verify one
# snapshot. Output goes to out_file and err_file.
attempt() {
    : > "${out_file}"
    : > "${err_file}"

    if [ "${copied}" -eq 0 ]; then
        collect --stage copy 2> "${err_file}" || return 1
        copied=1
    fi

    collect list --stage run 2> "${err_file}" > "${work_dir}/list" || {
        printf '%s\n' "ERROR: failed to collect the process list" >> "${err_file}"
        return 1
    }

    python3 "${script_dir}/verify.py" "${rules_file}" \
        < "${work_dir}/list" > "${out_file}" 2>> "${err_file}"
}

start=$(date +%s)
attempts=0

while :; do
    attempts=$((attempts + 1))

    if attempt; then
        cat "${out_file}"
        exit 0
    fi

    elapsed=$(( $(date +%s) - start ))
    if [ "${elapsed}" -ge "${timeout}" ]; then
        break
    fi

    if [ "${verbose}" -eq 1 ]; then
        printf '%s\n' "attempt ${attempts} failed after ${elapsed}s:" >&2
        cat "${err_file}" >&2
    fi

    sleep "${interval}"
done

cat "${out_file}"
cat "${err_file}" >&2
if [ "${timeout}" -gt 0 ]; then
    printf '%s\n' "ERROR: process privileges did not match after ${attempts} attempts in ${elapsed}s" >&2
fi
exit 1
