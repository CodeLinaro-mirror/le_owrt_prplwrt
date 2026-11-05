#!/usr/bin/env python3
"""Add private observations around the unchanged restart loop and its scoring."""
import csv
import json
import os
from pathlib import Path
import re
import shlex
import signal
import subprocess
import sys
import time

SERVICES = ('tr181-dslite', 'tr181-flashmonitor', 'routing-manager', 'tr181-gnimanager')
PROJECT = Path(os.environ['CI_PROJECT_DIR'])
OUT = PROJECT / 'uspreg-verbose'
REMOTE = shlex.split(os.environ['CRAM_REMOTE_COMMAND'])
COPY = shlex.split(os.environ['CRAM_REMOTE_COPY'])
DUT = '/run/usp-verbose'
STREAMS = ('logread-stream.txt', 'process-stream.txt', 'lifecycle-events')


def bounded(command, seconds=180):
    """Use image-provided shell builtins and sleep; the DUT has no timeout."""
    return '''set -eu
sh -c %s &
capture=$!
(
    sleep %d &
    timer=$!
    trap 'kill "$timer" 2>/dev/null || :; exit 0' HUP INT TERM
    wait "$timer"
    kill -TERM "$capture" 2>/dev/null || :
) &
watchdog=$!
trap 'kill "$capture" "$watchdog" 2>/dev/null || :; wait "$capture" 2>/dev/null || :; wait "$watchdog" 2>/dev/null || :' EXIT
trap 'exit 143' HUP INT TERM
wait "$capture"
''' % (shlex.quote(command), seconds)


def stream_command(name):
    if name == 'logread-stream.txt':
        # This image's logread -f is a shell wrapper around exactly this tail.
        # Exec the follower so the watchdog also terminates the actual reader.
        return 'exec tail -f /var/log/messages'
    if name == 'lifecycle-events':
        return 'exec ubus listen'
    assert name == 'process-stream.txt'
    return '''while :; do
    date -u +%FT%TZ; cat /proc/uptime
    printf 'broker '; pidof obuspa || true
    for p in $(pidof obuspa); do cat /proc/$p/stat 2>/dev/null || true; done
    for s in ''' + ' '.join(SERVICES) + '''; do
        echo "service=$s"
        for p in $(pidof "$s" 2>/dev/null); do
            cat /proc/$p/stat 2>/dev/null || true
            for f in /proc/$p/fd/*; do
                l=$(readlink "$f" 2>/dev/null || true)
                case "$l" in socket:*) echo "pid=$p fd=${f##*/} $l";; esac
            done
        done
    done
    sleep 1
done'''


def check_streams(directory):
    for name in STREAMS:
        if not (directory / (name + '.ready')).exists() or (directory / (name + '.exit')).exists():
            raise RuntimeError('continuous stream unavailable')


def capture(directory, name):
    """A long-lived host worker records readiness and every unexpected exit."""
    assert name in STREAMS
    with (directory / (name + '.stderr')).open('w') as err:
        if name == 'lifecycle-events':
            child = subprocess.Popen(REMOTE + [bounded(stream_command(name))],
                                     stdout=subprocess.PIPE, stderr=err, text=True)
        else:
            dest = (directory / name).open('w')
            child = subprocess.Popen(REMOTE + [bounded(stream_command(name))], stdout=dest, stderr=err)
        try:
            time.sleep(1)
            if child.poll() is not None:
                raise RuntimeError('stream exited during startup')
            (directory / (name + '.ready')).write_text('ready\n')
            if name == 'lifecycle-events':
                event_stream(directory, child)
            code = child.wait()
            (directory / (name + '.exit')).write_text(str(code) + '\n')
            raise RuntimeError('stream exited before collection finished')
        finally:
            if not (directory / 'capture-stop-requested').exists() and not (directory / (name + '.exit')).exists():
                (directory / (name + '.exit')).write_text('worker failed\n')
            child.terminate()
            try:
                child.wait(timeout=3)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()
            if name != 'lifecycle-events':
                dest.close()


def remote(command, timeout=20):
    return subprocess.check_output(REMOTE + ['set -e; ' + command], timeout=timeout, text=True)


def save(directory, name, command, timeout=20):
    (directory / name).write_text(remote(command, timeout))


def configure():
    """Preserve all existing instance settings; never persist inherited env."""
    for name in SERVICES:
        response = remote('ubus call service list ' + shlex.quote(json.dumps({'name': name, 'verbose': True})))
        config = json.loads(response)[name]
        assert config.get('instances'), 'missing service instances'
        loaded = remote('for p in $(pidof ' + name + '); do grep -l usp-verbose-observer /proc/$p/maps || true; done')
        if loaded.strip():
            continue
        for instance in config['instances'].values():
            for runtime in ('running', 'pid', 'exit_code', 'respawn_count'):
                instance.pop(runtime, None)
            if isinstance(instance.get('respawn'), dict):
                instance['respawn'] = [str(instance['respawn'][key]) for key in ('threshold', 'timeout', 'retry')]
            env = instance.setdefault('env', {})
            preload = DUT + '/usp-verbose-observer.so'
            if env.get('LD_PRELOAD'):
                preload += ':' + env['LD_PRELOAD']
            env['LD_PRELOAD'] = preload
            for index, argument in enumerate(instance['command']):
                if argument.startswith('LD_PRELOAD='):
                    instance['command'][index] = 'LD_PRELOAD=' + preload + ':' + argument.partition('=')[2]
            instance.update(stdout=True, stderr=True)
        config['name'] = name
        remote('ubus call service set ' + shlex.quote(json.dumps(config)))
        for attempt in range(20):
            if remote('p=$(pidof ' + name + '); test -n "$p" && grep -l usp-verbose-observer /proc/$p/maps || true').strip():
                break
            time.sleep(1)
        else:
            raise RuntimeError('observer failed to load: ' + name)


def runtime_snapshot(directory, name):
    data = {'host_utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
            'host_monotonic_ns': time.monotonic_ns(), 'services': {}}
    for service in SERVICES:
        result = json.loads(remote('ubus call service list ' + shlex.quote(json.dumps({'name': service, 'verbose': True}))))
        data['services'][service] = {
            instance: {key: value for key, value in fields.items()
                       if key in ('running', 'pid', 'exit_code', 'respawn_count', 'respawn')}
            for instance, fields in result.get(service, {}).get('instances', {}).items()}
    (directory / name).write_text(json.dumps(data, indent=2) + '\n')


def event_stream(directory, child):
    # ubus notifications can contain arbitrary data. Keep only service lifecycle
    # events for the selected names, and only fixed numeric / boolean fields.
    decoder, pending = json.JSONDecoder(), ''
    try:
        with (directory / 'lifecycle-events.jsonl').open('w') as dest:
            for line in child.stdout:
                pending += line
                if len(pending) > 1024 * 1024:
                    pending = ''
                    dest.write(json.dumps({'capture_gap': 'oversize_event'}) + '\n')
                while pending.strip():
                    pending = pending.lstrip()
                    try:
                        item, end = decoder.raw_decode(pending)
                    except ValueError:
                        break
                    pending = pending[end:]
                    for event, fields in item.items():
                        if not event.startswith('instance.') or not isinstance(fields, dict):
                            continue
                        name = fields.get('name', fields.get('service'))
                        if name not in SERVICES:
                            continue
                        record = {'event': event, 'service': name, 'host_monotonic_ns': time.monotonic_ns(),
                                  'host_utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())}
                        record.update({key: value for key, value in fields.items()
                                       if key in ('pid', 'exit_code', 'signal', 'respawn_count', 'running')
                                       and isinstance(value, (int, bool))})
                        dest.write(json.dumps(record) + '\n')
                        dest.flush()
    finally:
        child.terminate()
        try:
            child.wait(timeout=3)
        except subprocess.TimeoutExpired:
            child.kill()


def begin(directory):
    directory.mkdir(parents=True, exist_ok=True)
    save(directory, 'before-clock.txt', 'date -u +%FT%TZ; cat /proc/uptime')
    runtime_snapshot(directory, 'runtime-before.json')
    # Store each run on the DUT separately. New brokers open their log with "w".
    # Preserve it on the host before the next restart.
    remote('for f in ' + DUT + '/socket-io-*.log; do [ ! -f "$f" ] || : >"$f"; done')
    processes, children = [], []
    for name in STREAMS:
        with (directory / (name + '.worker-stderr')).open('w') as err:
            child = subprocess.Popen([sys.executable, __file__, 'capture', str(directory), name],
                                     stdout=subprocess.DEVNULL, stderr=err, start_new_session=True)
        processes.append(child.pid)
        children.append(child)
    (directory / 'capture-pids.json').write_text(json.dumps(processes))
    for attempt in range(50):
        if any(child.poll() is not None for child in children):
            raise RuntimeError('continuous observer exited')
        if all((directory / (name + '.ready')).exists() for name in STREAMS):
            break
        time.sleep(0.1)
    check_streams(directory)
    save(directory, 'capture-ready.txt', 'date -u +%FT%TZ; cat /proc/uptime; logger -t USP-VERBOSE ' + shlex.quote('begin ' + str(directory.relative_to(OUT))))


def end(directory):
    # This is after baseline qualification/scoring. Later snapshots do not score.
    save(directory, 'qualification-clock.txt', 'date -u +%FT%TZ; cat /proc/uptime')
    runtime_snapshot(directory, 'runtime-qualified.json')
    broker = remote('pidof obuspa').strip()
    assert re.fullmatch(r'[0-9]+', broker)
    for service in SERVICES:
        # Reuse precisely the baseline peer observer, without altering the gate.
        save(directory, 'peer-' + service + '.txt', 'date -u +%FT%TZ; cat /proc/uptime; '
             'for p in $(pidof ' + service + '); do for f in /proc/$p/fd/*; do '
             'l=$(readlink "$f" 2>/dev/null || true); case "$l" in socket:*) '
             'echo "pid=$p fd=${f##*/} $l"; /run/usp-harness/socket-peer "$p" "${f##*/}" ' + broker + ' || true;; esac; done; done')
    for delay in (10, 20):
        time.sleep(delay)
        save(directory, 'later-' + str(delay) + '-clock.txt', 'date -u +%FT%TZ; cat /proc/uptime')
        save(directory, 'later-' + str(delay) + '.datamodel', 'obuspa -f /etc/obuspa.db -c dump datamodel')
    runtime_snapshot(directory, 'runtime-after.json')
    save(directory, 'after-clock.txt', 'date -u +%FT%TZ; cat /proc/uptime')
    save(directory, 'broker.log', 'cat ' + DUT + '/broker.log')
    save(directory, 'service-socket-io.log', 'cat ' + DUT + '/socket-io-*.log')
    try:
        check_streams(directory)
    except RuntimeError:
        print('Continuous stream failure; inspect private artifacts.', file=sys.stderr)
        raise
    stop(directory)


def stop(directory):
    state = directory / 'capture-pids.json'
    if state.exists():
        (directory / 'capture-stop-requested').write_text('intentional stop\n')
        for pid in json.loads(state.read_text()):
            try:
                os.killpg(pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
        state.unlink()


def public_check():
    rows = list(csv.reader((PROJECT / 'results.tsv').open(), delimiter='\t'))
    assert len(rows) == 50
    for row in rows:
        assert len(row) == 7 and row[1] == 'dutinit'
        assert row[2] == '-' and row[3] == 'tr181-routeradvertisement'
        assert row[4] in ('0', '1') and row[5] in ('PASS', 'FAIL', 'INVALID')
        assert row[0].isdigit() and 1 <= int(row[0]) <= 50
        assert all(re.fullmatch(r'proto::[A-Za-z0-9_-]+', owner) for owner in row[6].split(',') if owner)
    summary = (PROJECT / 'uspreg-results/summary.txt').read_text()
    summary = ''.join(line + '\n' for line in summary.splitlines() if line.startswith('dutinit '))
    assert len(summary.splitlines()) == 2
    assert all(re.fullmatch(r'(ci-order|dutinit) (raw|scored): FAIL=\d+, PASS=\d+, INVALID=\d+', line)
               for line in summary.splitlines())
    # These are the only DUT-derived text files printed in the public trace.
    print((PROJECT / 'results.tsv').read_text(), end='')
    print(summary, end='')
    revision = os.environ['CI_COMMIT_SHA']
    assert re.fullmatch(r'[0-9a-f]{40}', revision)
    print(json.dumps({'revision': revision, 'target': 'OSPv2', 'firmware_job': '17753834532',
                      'N_per_trigger': 50, 'window_seconds': 40, 'artifacts_public': False}))
    print('Public output allowlist scan: PASS (result columns, counts and metadata only)')


def main():
    OUT.mkdir(exist_ok=True)
    if sys.argv[1:] and sys.argv[1] in ('prepare', 'before', 'after', 'capture'):
        mode, directory = sys.argv[1], Path(sys.argv[2])
        {'prepare': lambda _: configure(), 'before': begin, 'after': end,
         'capture': lambda path: capture(path, sys.argv[3])}[mode](directory)
        return
    assert os.environ.get('N', '50') == '50', 'this diagnostic requires N=50'
    assert os.environ['PREBUILT_FIRMWARE_JOB_ID'] == '17753834532'
    assert not list(OUT.iterdir()), 'diagnostic directory must be empty'
    save(OUT, 'device-command-preflight.txt',
         'for tool in sh sleep kill wait trap date cat printf pidof readlink echo ubus logread tail logger '
         'mkdir cp grep sed service rm test chmod awk obuspa; do command -v "$tool"; done; '
         'test -r /var/log/messages; '
         'for name in obuspa tr181-routeradvertisement tr181-neighbordiscovery ' + ' '.join(SERVICES) + '; do '
         'test -x /etc/init.d/$name; sh -n /etc/init.d/$name; done; '
         'ubus call service list \'{"name":"obuspa","verbose":true}\' >/dev/null; '
         'obuspa -f /etc/obuspa.db -c dump datamodel >/dev/null')
    save(OUT, 'passive-probe-capabilities.txt', 'for d in /sys/kernel/tracing /sys/kernel/debug/tracing; do '
         'test ! -d "$d" || { echo "tracefs=$d"; test ! -w "$d/uprobe_events" || echo uprobe_control_writable; }; done; '
         'for tool in bpftrace perf readelf nm; do command -v "$tool" || true; done')
    (OUT / 'metadata.json').write_text(json.dumps({
        'revision': os.environ['CI_COMMIT_SHA'], 'firmware_job': '17753834532',
        'services': SERVICES, 'N_per_trigger': 50, 'window_seconds': 40,
        'later_snapshot_delays_seconds': [10, 20], 'baseline_loop_unmodified': True,
        'observer_payloads_retained': False, 'artifacts_public': False}, indent=2) + '\n')
    remote('mkdir -p ' + DUT + '; cp -p /etc/init.d/obuspa ' + DUT + '/obuspa.init')
    initial_model = remote('obuspa -f /etc/obuspa.db -c dump datamodel')
    initial_owners = set(re.findall(r'^Device\..*?(proto::[^ \r\n]+)', initial_model, re.MULTILINE))
    assert initial_owners, 'initial owners unavailable'
    (OUT / 'setup.expected.owners').write_text(''.join(owner + '\n' for owner in sorted(initial_owners)))
    status = 1
    loop = None
    try:
        setup = subprocess.run(['bash', str(PROJECT / '.gitlab/scripts/dut-init/dut-configure-obuspa-logging.sh')],
                               env=os.environ | {'DUT_OBUSPA_VERBOSE_LEVEL': '3', 'DUT_OBUSPA_PROTOCOL_TRACE': '1'},
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        (OUT / 'logging-setup.txt').write_text(setup.stdout)
        setup.check_returncode()
        remote('if grep -q "^[[:space:]#]*procd_append_param command -l " /etc/init.d/obuspa; then '
               'sed -i "s@^[[:space:]#]*procd_append_param command -l .*@    procd_append_param command -l ' + DUT + '/broker.log@" /etc/init.d/obuspa; '
               'else sed -i "/procd_set_param stderr 1/a\\\\\n    procd_append_param command -l ' + DUT + '/broker.log" /etc/init.d/obuspa; fi; '
               'grep -q "^[[:space:]]*procd_append_param command -l ' + DUT + '/broker.log" /etc/init.d/obuspa')
        subprocess.run(COPY + [str(PROJECT / '.gitlab/uspreg-verbose-observer.so'), REMOTE[-1] + ':' + DUT + '/usp-verbose-observer.so'], check=True, timeout=20)
        # Start with private file logging; this unscored setup restart also proves
        # the new command works before the first baseline wait.
        remote('service obuspa restart')
        time.sleep(20)
        configure()
        # The logging setup restart is outside the measurement. Restore any
        # owner it lost so the first observation has the original owner set.
        def current_owners():
            return set(re.findall(r'^Device\..*?(proto::[^ \r\n]+)',
                                  remote('obuspa -f /etc/obuspa.db -c dump datamodel'), re.MULTILINE))
        for owner in sorted(initial_owners - current_owners()):
            name = owner.removeprefix('proto::')
            if name == 'prplmesh-controller':
                name = 'prplmesh'
            assert re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9_-]*', name)
            remote('test -x /etc/init.d/' + name + ' && /etc/init.d/' + name + ' restart')
        configure()
        for attempt in range(20):
            actual = current_owners()
            if initial_owners <= actual:
                break
            time.sleep(2)
        else:
            raise RuntimeError('logging setup lost baseline owners')
        (OUT / 'setup.restored.owners').write_text(''.join(owner + '\n' for owner in sorted(actual)))
        source = (PROJECT / '.gitlab/uspreg-loop.sh').read_text()
        replacements = {
            'for kind in ci-order dutinit; do': 'for kind in dutinit; do',
            '    wait_baseline "$dir/expected.owners"': '    diag prepare "$kind" "$run"\n    wait_baseline "$dir/expected.owners"',
            '    date -u +%FT%TZ >"$dir/start.txt"': '    diag before "$kind" "$run"\n    date -u +%FT%TZ >"$dir/start.txt"',
            '    R \'logread\' >"$dir/logread.txt"': '    R \'logread\' >"$dir/logread.txt"\n    diag after "$kind" "$run"',
            ' | tee -a "$CI_PROJECT_DIR/results.tsv"': ' >>"$CI_PROJECT_DIR/results.tsv"',
            'SCORE\' | tee "$out/summary.txt"': 'SCORE\' >"$out/summary.txt"',
        }
        for old, new in replacements.items():
            assert source.count(old) == 1, 'baseline hook moved: ' + old
            source = source.replace(old, new)
        hooks = '''diag() {
    python3 "$CI_PROJECT_DIR/.gitlab/uspreg-verbose.py" "$1" "$CI_PROJECT_DIR/uspreg-verbose/$2/run-$(printf '%03d' "$3")"
}
'''
        script = OUT / 'observed-loop.sh'
        script.write_text(hooks + source)
        with (OUT / 'loop.stdout').open('w') as stdout, (OUT / 'loop.stderr').open('w') as stderr:
            loop = subprocess.Popen(['bash', str(script)], stdout=stdout, stderr=stderr, start_new_session=True)
            code = loop.wait()
        if code:
            raise RuntimeError('baseline command failed')
        public_check()
        status = 0
    finally:
        if loop is not None and loop.poll() is None:
            os.killpg(loop.pid, signal.SIGTERM)
            try:
                loop.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(loop.pid, signal.SIGKILL)
                loop.wait()
        for directory in OUT.glob('*/run-*'):
            stop(directory)
        # Stock init restarts restore original environments, including any
        # LD_PRELOAD in launcher commands, which were never written to disk.
        try:
            save(OUT, 'cleanup.txt', 'cp -p ' + DUT + '/obuspa.init /etc/init.d/obuspa; '
                 'service obuspa restart; ' + '; '.join('service ' + name + ' restart' for name in SERVICES) + '; '
                 'sleep 3; for s in ' + ' '.join(SERVICES) + '; do '
                 'for p in $(pidof "$s"); do if grep -q usp-verbose-observer /proc/$p/maps; then exit 1; fi; done; done; '
                 'rm -r ' + DUT, timeout=60)
        except Exception:
            status = 1
        if status:
            raise RuntimeError('diagnostic or cleanup failed; inspect private artifacts')


if __name__ == '__main__':
    def interrupted(signum, frame):
        raise RuntimeError('diagnostic interrupted')
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    try:
        main()
    except Exception:
        # subprocess exceptions can contain an inherited procd environment.
        failed = [name for name in STREAMS if list(OUT.glob('*/run-*/' + name + '.exit'))]
        message = ('Continuous stream failed: ' + ', '.join(failed) if failed else
                   'Verbose diagnostic or continuous stream failed')
        print(message + '; inspect private artifacts.', file=sys.stderr)
        sys.exit(1)
