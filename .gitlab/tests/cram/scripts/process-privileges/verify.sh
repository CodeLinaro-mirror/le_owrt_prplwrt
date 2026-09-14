#!/usr/bin/env sh
set -e

script_dir="$(dirname $0)"
rules_file="${script_dir}/rules.yml"

while [ $# -gt 0 ]; do case "$1" in
*.yml)
    rules_file="$1"
    shift
    ;;
*)
    printf '%s\n' "Usage: $(basename $0) [<rules>.yml]" >&2
    exit 2
    ;;
esac; done


verify_process_privileges() {
    python3 "${script_dir}/verify.py" "$@"
}

"${script_dir}/collect.sh" "list" | verify_process_privileges "${rules_file}"
