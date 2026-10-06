#!/usr/bin/env sh
set -e

script_dir="$(dirname $0)"
collect_type=tree
lua_bin=lua

print_help() {
cat << EOF
Usage: $(basename $0) [-l|list] [-t|tree] [-h] [lua*] [<remote command>]

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
    <remote command>    The command to use to execute commands on the remote hgw. (default="ssh root@192.168.1.1")
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
"")
    :
    ;;
*)
    if [ -z "${remote_command}" ]; then
        remote_command="$1"
    else
        break
    fi
    ;;
esac; shift; done

if [ -z "${remote_command}" ]; then
    remote_command="${CRAM_REMOTE_COMMAND:-ssh root@192.168.1.1}"
fi

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
