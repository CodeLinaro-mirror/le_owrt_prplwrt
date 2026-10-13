#!/bin/sh

# Collect obuspa/USP Services diagnostics on the DUT, to debug datamodel
# mismatches that are only seen in CI.
#
# Usage: obuspa-diagnostics.sh [endpoint_id...]
#   endpoint_id: USP Service endpoints owning missing/unexpected elements,
#                e.g. proto::deviceinfo-manager

TRACE_FILE=/tmp/obuspa_plugin_trace.log

section() {
    printf '\n===== %s =====\n' "$*"
}

# Don't let a stuck obuspa or plugin block the collection
t() {
    if command -v timeout >/dev/null 2>&1; then
        timeout 30 "$@"
    else
        "$@"
    fi
}

# Print processes whose executable name (argv[0] basename) is $1
proc_info() {
    for pid in $(pgrep -f "$1"); do
        [ -r "/proc/$pid/stat" ] || continue
        # Skip processes only having the name in their arguments (e.g. this script)
        argv0=$(tr '\0' '\n' <"/proc/$pid/cmdline" | head -n 1)
        [ "${argv0##*/}" = "$1" ] || continue
        # starttime is in clock ticks since boot (USER_HZ is 100 on Linux)
        start=$(awk '{ printf "%d", $22 / 100 }' "/proc/$pid/stat")
        printf 'pid=%s started_at_uptime=%ss cmd=%s\n' "$pid" "$start" \
            "$(tr '\0' ' ' <"/proc/$pid/cmdline")"
    done
}

section "General"
date
printf 'uptime: %s\n' "$(cat /proc/uptime)"
printf 'DeviceInfo.DeviceStatus: %s\n' "$(t ba-cli -l DeviceInfo.DeviceStatus? 2>&1)"

section "obuspa processes"
proc_info obuspa

section "Device.USPServices.USPService.*."
t obuspa -c get "Device.USPServices.USPService.*." 2>&1

for endpoint in "$@"; do
    name=${endpoint#proto::}

    section "USP Service ${endpoint}: processes"
    proc_info "$name"

    section "USP Service ${endpoint}: obuspa plugin trace"
    grep -F "'${endpoint}'" "$TRACE_FILE" 2>&1 | tail -n 50

    section "USP Service ${endpoint}: manual GSDM (first 40 lines)"
    paths=$(t obuspa -c get "Device.USPServices.USPService.*.EndpointID" 2>/dev/null |
        sed -n "s/^\(Device\.USPServices\.USPService\.[0-9]*\.\)EndpointID => ${endpoint}\$/\1DataModelPaths/p")
    if [ -n "$paths" ]; then
        root=$(t obuspa -c get "$paths" 2>/dev/null | sed -n 's/.* => \(Device\.[^.,]*\.\).*/\1/p')
        root=${root:-Device.}
        printf 'GSDM path: %s\n' "$root"
        t obuspa -c service "$endpoint" gsdm "$root" 2>&1 | head -n 40
        # The Broker requests the common ancestor, which is Device. when a
        # service registers paths in several root objects
        if [ "$root" != "Device." ]; then
            printf '\nGSDM path: Device. (%s lines)\n' \
                "$(t obuspa -c service "$endpoint" gsdm Device. 2>&1 | tee /tmp/obuspa-diag-gsdm.$$ | wc -l)"
            head -n 20 /tmp/obuspa-diag-gsdm.$$
            rm -f /tmp/obuspa-diag-gsdm.$$
        fi
    else
        printf '%s is not registered in Device.USPServices.USPService\n' "$endpoint"
    fi

    section "USP Service ${endpoint}: syslog"
    logread 2>/dev/null | grep -F "$name" | tail -n 100
done

section "ProcessMonitor.Test."
t ba-cli -l "ProcessMonitor.Test.*.?" 2>&1 | head -n 300

section "DeviceInfo.ProcessFaults.ProcessFault."
t ba-cli -l "DeviceInfo.ProcessFaults.ProcessFault.*.?" 2>&1 | head -n 200

section "obuspa plugin trace (last 300 lines)"
tail -n 300 "$TRACE_FILE" 2>&1

section "syslog: obuspa"
logread 2>/dev/null | grep -F obuspa | tail -n 300

section "syslog: crashes / restarts"
logread 2>/dev/null | grep -i -E "segfault|respawn|crash|killed|ProcessMonitor|process_monitor|core dump" |
    tail -n 100

exit 0
