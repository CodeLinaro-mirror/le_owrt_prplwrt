#!/usr/bin/env sh
set -e

script_dir="$(dirname $0)"
collect_type=tree
lua_bin=lua

print_help() {
cat << EOF
Usage: $(basename $0) [-l|list] [-t|tree] [-h] [lua*]

Print the running processes and their privileges:
- Process name
- User
- Group
- Capabilities

Options:
    -h                  Print this help
    -l, list            Print the list of all processes. Additionally prints pid and ppid
    -t, tree            Print the all processes in a hierarchical tree. (default)
                        With all processes in the same branch alphabetically ordered.
    lua*                To specify the lua binary to use to run the lua script. (default="lua", e.g. lua5.3)

Environment:
    CRAM_REMOTE_COMMAND The command to use to execute commands on the remote hgw. (default="ssh root@192.168.1.1")
    CRAM_REMOTE_COPY    The command to use to copy files to the remote hgw. (default="scp")
    TARGET_LAN_IP       The remote hgw address, when it cannot be derived from CRAM_REMOTE_COMMAND
EOF
}

while [ $# -gt 0 ]; do case "$1" in
-h)
    print_help
    exit 0
    ;;
-l|list)
    collect_type=list
    ;;
-t|tree)
    collect_type=tree
    ;;
-c|ctree|color|color_tree)
    collect_type=color_tree
    ;;
lua*)
    lua_bin="$1"
    ;;
*)
    print_help >&2
    exit 2
    ;;
esac; shift; done

remote_command="${CRAM_REMOTE_COMMAND:-ssh root@192.168.1.1}"

R() { ${remote_command} "$@"; }
C() { ${CRAM_REMOTE_COPY:-scp} "$@"; }

remote_host="${TARGET_LAN_IP:-}"
if [ -z "${remote_host}" ]; then
    remote_host=$(printf '%s\n' "${remote_command}" | sed -n 's/.*@\([^ ]*\).*/\1/p')
fi

if [ -z "${remote_host}" ]; then
    printf '%s\n' "TARGET_LAN_IP or a remote command naming the host is required" >&2
    exit 1
fi

local_script="${script_dir}/target/process-privileges.lua"
remote_script=/tmp/process-privileges.lua

cleanup() {
    R "rm -f '${remote_script}'" >/dev/null 2>&1 || true
}

trap cleanup EXIT HUP INT TERM

C "${local_script}" "root@${remote_host}:${remote_script}" >/dev/null 2>&1 || {
    printf '%s\n' "Failed to copy ${local_script} to ${remote_host}" >&2
    exit 1
}

R "${lua_bin}" "${remote_script}" "${collect_type}"
