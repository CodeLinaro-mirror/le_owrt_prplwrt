#!/bin/bash
# One bounded timing diagnostic; the 50-run comparison uses the default mode.
# Remote shell expressions must reach the DUT without local expansion.
# shellcheck disable=SC2016
set -euo pipefail
export LC_ALL=C
: "${CI_PROJECT_DIR:?missing project directory}"
: "${CRAM_REMOTE_COMMAND:?missing DUT remote command}"
: "${CRAM_REMOTE_COPY:?missing DUT copy command}"
out=$CI_PROJECT_DIR/uspreg-results/timing
mkdir -p "$out"
[[ -z $(find "$out" -mindepth 1 -maxdepth 1 -print -quit) ]] || exit 2
mapfile -d '' -t remote < <(python3 -c 'import os,shlex,sys; sys.stdout.buffer.write(b"\0".join(s.encode() for s in shlex.split(os.environ["CRAM_REMOTE_COMMAND"]))+b"\0")')
mapfile -d '' -t copy < <(python3 -c 'import os,shlex,sys; sys.stdout.buffer.write(b"\0".join(s.encode() for s in shlex.split(os.environ["CRAM_REMOTE_COPY"]))+b"\0")')
R() { timeout 15s "${remote[@]}" "set -e; $1"; }
stream_pid=''
cleanup() {
    local status=$?
    trap - EXIT
    if [[ -n $stream_pid ]]; then
        kill "$stream_pid" 2>/dev/null || true
        wait "$stream_pid" 2>/dev/null || true
    fi
    # Restart from stock init definitions to remove the temporary environment.
    if ! R 'if [ -f /run/usp-timing/obuspa.init ]; then
        cp -p /run/usp-timing/obuspa.init /etc/init.d/obuspa &&
        service obuspa restart && service tr181-routeradvertisement restart &&
        p=$(pidof tr181-routeradvertisement) && test -n "$p" &&
        ! grep -q usp-socket-trace /proc/$p/maps && rm -r /run/usp-timing
        else true; fi' >"$out/cleanup.txt" 2>&1; then
        echo 'timing diagnostic cleanup failed' >&2
        status=1
    fi
    exit "$status"
}
R 'test -x /etc/init.d/tr181-routeradvertisement; mkdir -p /run/usp-timing; cp -p /etc/init.d/obuspa /run/usp-timing/obuspa.init'
trap cleanup EXIT
export DUT_OBUSPA_VERBOSE_LEVEL=3 DUT_OBUSPA_PROTOCOL_TRACE=1
bash "$CI_PROJECT_DIR/.gitlab/scripts/dut-init/dut-configure-obuspa-logging.sh" >"$out/logging-setup.txt" 2>&1
# Retain full protocol output even if the syslog ring wraps during startup.
R 'if grep -q "^[[:space:]#]*procd_append_param command -l " /etc/init.d/obuspa; then
    sed -i "s@^[[:space:]#]*procd_append_param command -l .*@    procd_append_param command -l /run/usp-timing/broker.log@" /etc/init.d/obuspa
    else sed -i "/procd_set_param stderr 1/a\\
    procd_append_param command -l /run/usp-timing/broker.log" /etc/init.d/obuspa; fi
    grep "^[[:space:]]*procd_append_param command -[vpl]" /etc/init.d/obuspa' >>"$out/logging-setup.txt"
timeout 15s "${copy[@]}" "$CI_PROJECT_DIR/.gitlab/uspreg-socket-trace.so" "${remote[-1]}:/run/usp-timing/usp-socket-trace.so"
# Update only this service's existing procd instances, preserving their config.
# Do not print or save the inherited environment.
python3 - <<'CONFIGURE'
import json
import os
import shlex
import subprocess
remote = shlex.split(os.environ['CRAM_REMOTE_COMMAND'])
name = 'tr181-routeradvertisement'
def call(command):
    return subprocess.check_output(remote + [command], timeout=15, text=True)
config = json.loads(call('ubus call service list ' + shlex.quote(json.dumps({'name': name, 'verbose': True}))))[name]
assert config.get('instances'), 'selected service has no procd instances'
for instance in config['instances'].values():
    assert instance.get('command'), 'selected instance has no command'
    for runtime in ('running', 'pid', 'exit_code', 'respawn_count'):
        instance.pop(runtime, None)
    respawn = instance.get('respawn')
    if isinstance(respawn, dict):
        instance['respawn'] = [str(respawn[key]) for key in ('threshold', 'timeout', 'retry')]
    # service list omits these flags; enable both for this logging diagnostic.
    instance.update(stdout=True, stderr=True)
    env = instance.setdefault('env', {})
    preload = '/run/usp-timing/usp-socket-trace.so'
    if env.get('LD_PRELOAD'):
        preload += ':' + env['LD_PRELOAD']
    env['LD_PRELOAD'] = preload
    # An env command in the launcher can override the instance environment.
    for index, argument in enumerate(instance['command']):
        if argument.startswith('LD_PRELOAD='):
            instance['command'][index] = 'LD_PRELOAD=' + preload + ':' + argument.partition('=')[2]
config['name'] = name
call('ubus call service set ' + shlex.quote(json.dumps(config)))
print('Temporary socket observer configured for ' + name)
CONFIGURE
for (( attempt=0; attempt<20; attempt++ )); do
    if R 'p=$(pidof tr181-routeradvertisement); test -n "$p" && grep -q usp-socket-trace /proc/$p/maps'; then break; fi
    sleep 1
done
R 'p=$(pidof tr181-routeradvertisement); grep usp-socket-trace /proc/$p/maps' >"$out/observer-loaded.txt"
{
    date -u +%FT%TZ
    printf 'revision=%s\nfirmware_job=%s\nmode=timing\nN=10\nverbose=3\nprotocol_trace=1\nservice=tr181-routeradvertisement\nclock=CLOCK_MONOTONIC\n' "${CI_COMMIT_SHA:-unknown}" "${PREBUILT_FIRMWARE_JOB_ID:-unknown}"
} >"$out/config.txt"
for (( run=1; run<=10; run++ )); do
    dir=$out/run-$(printf '%03d' "$run")
    mkdir -p "$dir"
    R 'date -u +%FT%TZ; cat /proc/uptime' >"$dir/before-clock.txt"
    R 'logread' >"$dir/logread-before.txt"
    timeout --kill-after=3s 100s "${remote[@]}" 'logread -f' >"$dir/logread-stream.txt" 2>"$dir/logread-stream.stderr" &
    stream_pid=$!
    R 'service obuspa stop' >"$dir/trigger.log" 2>&1
    R 'rm -f /etc/obuspa.db; : >/run/usp-timing/broker.log; for f in /run/usp-timing/socket-io-*.log; do [ ! -f "$f" ] || : >"$f"; done' >>"$dir/trigger.log" 2>&1
    date -u +%FT%TZ >"$dir/start.txt"
    R "logger -t USP-TIMING 'begin run=$run'; service obuspa start" >>"$dir/trigger.log" 2>&1
    sleep 60
    R 'pidof obuspa' >"$dir/broker.pid"
    R 'p=$(pidof tr181-routeradvertisement); echo "service_pid=$p"; grep usp-socket-trace /proc/$p/maps; cat /proc/net/unix' >"$dir/service.txt"
    R 'cat /run/usp-timing/socket-io-*.log' >"$dir/service-socket-io.log"
    R 'cat /run/usp-timing/broker.log' >"$dir/broker.log"
    R 'obuspa -f /etc/obuspa.db -c dump datamodel' >"$dir/observed.datamodel"
    R 'logread' >"$dir/logread.txt"
    R 'date -u +%FT%TZ; cat /proc/uptime' >"$dir/after-clock.txt"
    kill "$stream_pid" 2>/dev/null || true
    wait "$stream_pid" 2>/dev/null || true
    stream_pid=''
    date -u +%FT%TZ >"$dir/end.txt"
    printf 'timing dutinit %s of 10 collected\n' "$run"
done
python3 "$CI_PROJECT_DIR/.gitlab/uspreg-timing-analyze.py" "$out" | tee "$out/summary.txt"
