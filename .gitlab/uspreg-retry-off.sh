#!/bin/bash
# Apply once, then reboot so all USP clients read the overlay before the loop.
set -euo pipefail
: "${CRAM_REMOTE_COMMAND:?missing DUT remote command}"
: "${CI_PROJECT_DIR:?missing project directory}"
mapfile -d '' -t remote < <(python3 -c 'import os,shlex,sys; sys.stdout.buffer.write(b"\0".join(s.encode() for s in shlex.split(os.environ["CRAM_REMOTE_COMMAND"]))+b"\0")')
R() { timeout 15s "${remote[@]}" "$1"; }
overlay=$(cat "$CI_PROJECT_DIR/.gitlab/uspreg-retry-off-dut.sh")
boot_id=$(R 'cat /proc/sys/kernel/random/boot_id')
[[ $boot_id =~ ^[0-9a-f-]{36}$ ]]
R "set -- apply; $overlay"
# Reboot runs in the foreground; require its success and an actual boot-ID change.
R 'reboot'
deadline=$((SECONDS + 240))
while :; do
    if next_boot_id=$(R 'cat /proc/sys/kernel/random/boot_id') &&
       [[ $next_boot_id =~ ^[0-9a-f-]{36}$ && $next_boot_id != "$boot_id" ]]; then
        break
    fi
    (( SECONDS < deadline )) || { echo 'retry-off: reboot did not complete' >&2; exit 2; }
    sleep 5
done
printf 'retry-off boot IDs: %s -> %s\n' "$boot_id" "$next_boot_id"
sleep "${DUT_SLEEP_AFTER_BOOT:-90}"
R "set -- check; $overlay"
echo 'retry-off: overlay persisted across reboot'
# The extra setup boot must retain the normal CI process-monitor policy.
bash "$CI_PROJECT_DIR/.gitlab/scripts/dut-init/dut-change-fail-action-to-restart.sh"
