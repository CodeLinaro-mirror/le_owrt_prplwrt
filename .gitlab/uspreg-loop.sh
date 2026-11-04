#!/bin/bash
# Run both broker restart triggers, N observations each (default 50).
# results.tsv has the QEMU harness's seven columns, without a header:
# run, trigger, param, service, connected, raw verdict, missing owners.
# FAIL/INVALID are measurements; command or baseline failures exit nonzero.
set -euo pipefail
export LC_ALL=C
runs=${N:-50}
service=tr181-routeradvertisement
peer_services=(tr181-neighbordiscovery)
param=-
[[ $runs =~ ^[1-9][0-9]*$ ]] || { echo 'N must be a positive integer' >&2; exit 2; }
: "${CRAM_REMOTE_COMMAND:?missing DUT remote command}"
: "${CRAM_REMOTE_COPY:?missing DUT copy command}"
: "${CI_PROJECT_DIR:?missing project directory}"
out=$CI_PROJECT_DIR/uspreg-results
mkdir -p "$out"
[[ -z $(find "$out" -mindepth 1 -maxdepth 1 -print -quit) ]] || {
    echo 'results directory must be empty' >&2; exit 2;
}
mapfile -d '' -t remote < <(python3 -c 'import os,shlex,sys; sys.stdout.buffer.write(b"\0".join(s.encode() for s in shlex.split(os.environ["CRAM_REMOTE_COMMAND"]))+b"\0")')
mapfile -d '' -t copy < <(python3 -c 'import os,shlex,sys; sys.stdout.buffer.write(b"\0".join(s.encode() for s in shlex.split(os.environ["CRAM_REMOTE_COPY"]))+b"\0")')
R() { timeout 10s "${remote[@]}" "$1"; }
for peer_service in "$service" "${peer_services[@]}"; do
    R "test -x /etc/init.d/$peer_service && pidof '$peer_service' >/dev/null"
done
R 'mkdir -p /run/usp-harness'
timeout 10s "${copy[@]}" "$CI_PROJECT_DIR/.gitlab/uspreg-socket-peer" "${remote[-1]}:/run/usp-harness/socket-peer"
R 'test -s /run/usp-harness/socket-peer && chmod 700 /run/usp-harness/socket-peer'
{
    date -u +%FT%TZ
    printf 'revision=%s\nfirmware_job=%s\nN=%s\n' "${CI_COMMIT_SHA:-unknown}" "${PREBUILT_FIRMWARE_JOB_ID:-unknown}" "$runs"
} >"$out/config.txt"
owners() {
    # Keep command failure distinct from an empty (but successful) model dump.
    R 'obuspa -f /etc/obuspa.db -c dump datamodel' >"$1.datamodel"
    { grep '^Device\.' "$1.datamodel" | grep -o 'proto::[^ ]*' || true; } | sort -u >"$1"
}
connected() {
    # Every record is an established service-owned Unix stream inode. ss can
    # supply the peer inode; the proc fallback asks SO_PEERCRED on a duplicate FD.
    R "service='${2:-$service}'; broker='$broker';
        pids=\$(pidof \"\$service\" 2>/dev/null || true)
        cat /proc/net/unix
        if command -v ss >/dev/null 2>&1; then ss -xnpH; fi
        for pid in \$pids; do
            for f in /proc/\$pid/fd/*; do
                link=\$(readlink \"\$f\" 2>/dev/null || true)
                case \"\$link\" in socket:\\[*\\]) ;; *) continue ;; esac
                inode=\${link#socket:[}; inode=\${inode%]}
                awk -v i=\"\$inode\" '\$7==i && \$5==\"0001\" && \$6==\"03\" {found=1} END {exit !found}' /proc/net/unix || continue
                echo \"service_pid=\$pid fd=\${f##*/} inode=\$inode state=03\"
                confirmation=\$(/run/usp-harness/socket-peer \"\$pid\" \"\${f##*/}\" \"\$broker\")
                if [ \"\$confirmation\" = peer-confirmed ]; then
                    echo \"CONNECTED peer_pid=\$broker inode=\$inode\"
                fi
            done
        done" >"$1"
    if grep -q '^CONNECTED ' "$1"; then echo 1; else echo 0; fi
}
wait_baseline() {
    local base=$1 deadline=$((SECONDS + 40))
    while :; do
        owners "$base"
        if grep -Fxq "proto::$service" "$base" && [[ -s $base ]]; then
            if [[ ! -f $out/initial.owners ]] || [[ -z $(comm -23 "$out/initial.owners" "$base") ]]; then
                return
            fi
        fi
        (( SECONDS < deadline )) || { echo 'baseline owners unavailable' >&2; return 2; }
        sleep 2
    done
}
: >"$CI_PROJECT_DIR/results.tsv"
previous_missing=''
for kind in ci-order dutinit; do
for (( run=1; run<=runs; run++ )); do
    dir=$out/$kind/run-$(printf '%03d' "$run")
    mkdir -p "$dir"
    # Restore missing owners before the next observation, including across triggers.
    if [[ -n $previous_missing && -s $previous_missing ]]; then
        R "/etc/init.d/$service restart" >"$dir/restore.log" 2>&1
        while IFS= read -r owner; do
            restore_service=${owner#proto::}
            # This endpoint belongs to beerocks_controller, managed by
            # /etc/init.d/prplmesh rather than an identically named init.
            if [[ $restore_service == prplmesh-controller ]]; then
                restore_service=prplmesh
            fi
            [[ $restore_service =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] || exit 2
            R "test -x /etc/init.d/$restore_service && /etc/init.d/$restore_service restart" >>"$dir/restore.log" 2>&1
        done <"$previous_missing"
    fi
    wait_baseline "$dir/expected.owners"
    if [[ ! -f $out/initial.owners ]]; then cp "$dir/expected.owners" "$out/initial.owners"; fi
    date -u +%FT%TZ >"$dir/start.txt"
    if [[ $kind == ci-order ]]; then
        R 'service obuspa restart' >"$dir/trigger.log" 2>&1
    else
        R 'service obuspa stop' >"$dir/trigger.log" 2>&1
        R 'rm -f /etc/obuspa.db' >>"$dir/trigger.log" 2>&1
        R 'service obuspa start' >>"$dir/trigger.log" 2>&1
    fi
    sleep 20
    broker=$(R 'pidof obuspa')
    [[ $broker =~ ^[0-9]+$ ]] || { echo 'expected one obuspa PID after trigger' >&2; exit 2; }
    printf '%s\n' "$broker" >"$dir/broker.pid"
    start=$SECONDS
    deadline=$((start + 40))
    while :; do
        owners "$dir/observed.owners"
        comm -23 "$dir/expected.owners" "$dir/observed.owners" >"$dir/missing.owners"
        printf '%s\t%s\n' "$((SECONDS - start))" "$(paste -sd, "$dir/missing.owners")" >>"$dir/polls.tsv"
        if [[ ! -s $dir/missing.owners ]]; then break; fi
        (( SECONDS < deadline )) || break
        sleep 2
    done
    socket_connected=$(connected "$dir/sockets.txt")
    for peer_service in "${peer_services[@]}"; do
        peer_connected=$(connected "$dir/sockets-$peer_service.txt" "$peer_service")
        if [[ $peer_connected == 0 ]]; then socket_connected=0; fi
    done
    verdict=PASS
    if [[ -s $dir/missing.owners ]]; then verdict=FAIL; fi
    if [[ $socket_connected == 0 ]]; then verdict=INVALID; fi
    missing=$(paste -sd, "$dir/missing.owners")
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$run" "$kind" "$param" "$service" "$socket_connected" "$verdict" "$missing" | tee -a "$CI_PROJECT_DIR/results.tsv"
    previous_missing=$dir/missing.owners
    R 'logread' >"$dir/logread.txt"
done
done
# Scoring is separate: preserve every raw row, including the controller.
python3 - "$CI_PROJECT_DIR/results.tsv" "$out/scored-results.tsv" <<'SCORE' | tee "$out/summary.txt"
import csv
import sys
from collections import Counter
counts = {trigger: {mode: Counter() for mode in ('raw', 'scored')}
          for trigger in ('ci-order', 'dutinit')}
with open(sys.argv[1], newline='') as source, open(sys.argv[2], 'w', newline='') as dest:
    writer = csv.writer(dest, delimiter='\t', lineterminator='\n')
    for row in csv.reader(source, delimiter='\t'):
        counts[row[1]]['raw'][row[5]] += 1
        missing = [owner for owner in row[6].split(',')
                   if owner and owner != 'proto::prplmesh-controller']
        verdict = 'INVALID' if row[4] != '1' else ('FAIL' if missing else 'PASS')
        writer.writerow(row[:5] + [verdict, ','.join(missing)])
        counts[row[1]]['scored'][verdict] += 1
for trigger, modes in counts.items():
    for mode, values in modes.items():
        print(f'{trigger} {mode}: ' + ', '.join(
            f'{status}={values[status]}' for status in ('FAIL', 'PASS', 'INVALID')))
SCORE
