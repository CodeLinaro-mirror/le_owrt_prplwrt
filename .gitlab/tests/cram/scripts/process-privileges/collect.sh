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

${remote_command} "${lua_bin}" - "${collect_type}" < "${script_dir}/target/process-privileges.lua"
