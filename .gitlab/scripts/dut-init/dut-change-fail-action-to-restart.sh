#!/bin/bash

source ${CI_PROJECT_DIR}/.gitlab/scripts/helpers.sh

set -eu         # exit on error and undefined variables
set -o pipefail # catch errors in pipes

# Execute provided command using ba-cli --less --json
ba_cli_json() {
        # shellcheck disable=SC2029
        ssh "root@$TARGET_LAN_IP" "ba-cli --less --json '$1'"
}

# Execute provided command using ba-cli --less
ba_cli() {
        # shellcheck disable=SC2029
        ssh "root@$TARGET_LAN_IP" "ba-cli '$1'"
}

# Waits for ProcessMonitor.Test.i to become available after booting of CPE
wait_till_dm_ready() {
        local diff=0
        local start_time
        local current_time
        local timeout=180
        local process_monitor_path=""

        start_time=$(cut -d. -f1 /proc/uptime)

        log_info "Checking if ProcessMonitor.Test.i datamodel is available..."

        while [ -z "$process_monitor_path" ]; do
                process_monitor_path=$(ba_cli_json "ProcessMonitor.Test.?" \
                        | jq -r '.[0] | keys[]' 2>/dev/null | sed 's/\.$//') \
                        || true
                current_time=$(cut -d. -f1 /proc/uptime)
                diff=$((current_time - start_time))

                if [ $diff -ge $timeout ]; then
                        log_error "Timeout waiting for ProcessMonitor.Test.i \
                                to be available!"
                        exit 1
                fi

                if [ -z "$process_monitor_path" ]; then
                        log_info "Waiting for ProcesMonitor.Test.i datamodel \
                                to be available ($diff s)"
                        sleep 5
                fi
        done

        log_success "ProcessMonitor.Test.i datamodel is available"
}

# Check ProcessMonitor.Test.i.FailAction for all process and if set as REBOOT
# change it to RESTART CI cram and CDRouter tests
change_fail_action_to_restart() {
        for id in $(ba_cli 'ProcessMonitor.Test.[FailAction == "REBOOT"].?' | \
            grep Name | \
            sed -n 's/.*Test\.\([0-9]\+\).*/\1/p'); do
                ba_cli \
                "ProcessMonitor.Test.$id.FailAction=\"RESTART\"" \
                > /dev/null
                log_info "Modified ProcessMonitor.Test.$id" \
                        "FailAction from REBOOT to RESTART"
        done
        log_info "Completed with ProcessMonitor FailAction update"
}

main() {
        wait_till_dm_ready
        change_fail_action_to_restart
}

main
