#!/bin/sh

# Inspect the USP notification, not the ubus return value or stored DM results.
set -eu

mode=${1:?Expected ready or check}
work=${2:?Expected capture directory}
marker=${3:?Expected log marker}
case "$mode" in
    ready)
        # Exclude old entries and confirm capture is running before the RPC.
        for attempt in 1 2 3 4 5; do
            logger -t cram "$marker"
            sleep 1
            if grep -q "$marker" "$work/trace"; then exit 0; fi
        done
        echo "Log reader did not capture the readiness marker" >&2
        cat "$work/trace" >&2
        exit 1
        ;;
    check) ;;
    *) echo "Expected ready or check" >&2; exit 1 ;;
esac

complete=0
for attempt in $(seq 1 30); do
    awk -v marker="$marker" '
        index($0, marker) { fresh=1 }
        !fresh { next }
        /oper_complete \{/ { block=""; depth=0; active=1 }
        active {
            block=block $0 "\n"
            if($0 !~ /value: "/) {
                line=$0; depth+=gsub(/\{/, "", line)
                line=$0; depth-=gsub(/\}/, "", line)
            }
            if(depth == 0) {
                if(index(block, "obj_path: \"Device.IP.Diagnostics.\"") &&
                   index(block, "command_name: \"IPPing()\"") &&
                   index(block, "command_key: \"CLI-initiated\"")) {
                    printf "%s", block
                    exit
                }
                active=0
            }
        }
    ' "$work/trace" > "$work/notification"
    if [ -s "$work/notification" ]; then complete=1; break; fi
    sleep 1
done
if [ "$complete" != 1 ]; then
    echo "Timed out waiting for IPPing OperationComplete" >&2
    cat "$work/trace" >&2
    exit 1
fi

# USP values are strings. Check types and stable values, not measured timings.
if ! awk '
    /key: "/ { key=$0; sub(/^.*key: "/, "", key); sub(/".*$/, "", key) }
    /value: "/ {
        if($0 !~ /"[[:space:]]*$/) {
            print "Incomplete logged value for " key > "/dev/stderr"
            bad=1
        }
        value=$0; sub(/^.*value: "/, "", value); sub(/"[[:space:]]*$/, "", value)
        if(key in args) bad=1
        args[key]=value
    }
    END {
        count=split("Status IPAddressUsed SuccessCount FailureCount AverageResponseTime MinimumResponseTime MaximumResponseTime AverageResponseTimeDetailed MinimumResponseTimeDetailed MaximumResponseTimeDetailed", expected, " ")
        for(i=1; i<=count; i++) {
            key=expected[i]
            if(!(key in args)) bad=1
            if(i>2 && args[key] !~ /^[0-9]+$/) bad=1
        }
        for(key in args) { found++; print key }
        if(found!=count || args["Status"]!="Complete" ||
           args["IPAddressUsed"]!="127.0.0.1" ||
           args["SuccessCount"]!=1 || args["FailureCount"]!=0) bad=1
        exit bad
    }
' "$work/notification" > "$work/keys"; then
    cat "$work/notification" >&2
    exit 1
fi
sort "$work/keys"
