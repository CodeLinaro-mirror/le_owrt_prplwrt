#!/bin/sh
# Run on an isolated Linux host/DUT with Lua. No bus is needed.
# Usage: sh test-lcm-event-capture.sh /path/to/lcm/script_functions.sh
# Keep transfer_policy.sh beside the helper to check its integration too.
set -eu
helper=$(readlink -f "$1")
fixture=$(mktemp -d)
trap 'rc=$?; if [ "$rc" -ne 0 ]; then cat "$fixture/output" >&2; fi; rm -rf "$fixture"' EXIT
export LCM_EVENT_FIXTURE="$fixture"
export LUA_PATH="$fixture/?.lua;;"
cat > "$fixture/lamx.lua" <<'LUA'
local dir = os.getenv('LCM_EVENT_FIXTURE')
local mode = os.getenv('LCM_EVENT_CASE')
local function write(name, value)
    local f = assert(io.open(dir .. '/' .. name, 'w'))
    f:write(value or '1'); f:close()
end
local function exists(name)
    local f = io.open(dir .. '/' .. name)
    if f then f:close(); return true end
end
local stat = assert(io.open('/proc/self/stat'))
write('pid', stat:read('*l'):match('^%d+')); stat:close()
local callback
local loop = {stop = function() end}
function loop:start()
    while not exists('rpc') do os.execute('sleep 0.1') end
    if mode == 'crash' then error('injected subscriber failure') end
    if mode == 'early-exit' then return end
    if mode == 'delayed-event' then os.execute('sleep 2') end
    local function emit(uuid, op)
        callback('DUStateChange!', {data = {
            UUID = uuid, OperationPerformed = op, CurrentState = 'Failed',
            Fault = {FaultCode = 7032, FaultString = 'exact fault text'}
        }})
    end
    emit('wrong-uuid', 'Install')
    emit('test-uuid', 'Uninstall')
    if mode == 'missing' then
        while true do os.execute('sleep 0.1') end
    end
    emit('test-uuid', 'Install')
end
return {
    backend = {load = function() end},
    bus = {
        open = function() end,
        subscribe = function(_, cb)
            if mode == 'startup-failure' then error('injected subscribe failure') end
            if mode == 'startup-timeout' then
                -- Block in Lua itself, so cleanup has no artificial child.
                while true do end
            end
            if mode == 'delayed-start' then os.execute('sleep 2') end
            callback = cb
            return {}
        end
    },
    eventloop = {new = function() return loop end}
}
LUA
cat > "$fixture/run.sh" <<'SH'
. "$1"
[ -z "${LCM_EVENT_POLICY:-}" ] || . "$LCM_EVENT_POLICY"
cli_call_async() {
    # Readiness is required even for synchronous fault delivery.
    [ -s "${_DU_SUB_DIR}/ready" ] || return 99
    echo "${_DU_SUB_DIR}" > "$LCM_EVENT_FIXTURE/capture-dir"
    touch "$LCM_EVENT_FIXTURE/rpc"
    if [ "$LCM_EVENT_CASE" = interrupted ]; then
        read -r self rest < /proc/self/stat
        kill -TERM "$self"
    fi
    if [ "$LCM_EVENT_CASE" = immediate-fault ]; then
        while [ ! -s "${_DU_SUB_DIR}/done" ]; do sleep 0.1; done
        return 1
    fi
}
# Preserve the caller's trap as well as the historical RPC fault behavior.
trap 'echo caller-trap > "$LCM_EVENT_FIXTURE/caller-trap"' EXIT
cli_call_with_du_state_change test-uuid Install SoftwareModules. InstallDU '{}'
SH
for mode in delayed-start immediate-fault delayed-event startup-failure startup-timeout crash early-exit missing interrupted; do
    export LCM_EVENT_CASE="$mode"
    rm -f "$fixture/rpc" "$fixture/pid" "$fixture/capture-dir" "$fixture/caller-trap"
    before=$(date +%s)
    rc=0
    sh "$fixture/run.sh" "$helper" > "$fixture/output" 2>&1 || rc=$?
    elapsed=$(($(date +%s) - before))
    test "$elapsed" -le 12
    test -f "$fixture/caller-trap"
    if [ -f "$fixture/pid" ]; then
        ! kill -0 "$(cat "$fixture/pid")" 2>/dev/null
    fi
    if [ -f "$fixture/capture-dir" ]; then
        test ! -e "$(cat "$fixture/capture-dir")"
    fi
    case "$mode" in
    delayed-start|immediate-fault|delayed-event)
        test "$rc" -eq 0
        test "$(cat "$fixture/output")" = 'DUStateChange! ERROR: operation=Install state=Failed FaultCode=7032 FaultString=exact fault text'
        ;;
    startup-failure|startup-timeout)
        test "$rc" -ne 0
        test ! -e "$fixture/rpc"
        grep -q 'subscriber failed to become ready within 10 s: UUID=test-uuid operation=Install' "$fixture/output"
        ;;
    crash|early-exit)
        test "$rc" -ne 0
        grep -q 'subscriber exited without completion: UUID=test-uuid operation=Install' "$fixture/output"
        ;;
    missing)
        test "$rc" -ne 0
        test "$elapsed" -ge 10
        grep -q 'completion missing after 10 s: UUID=test-uuid operation=Install' "$fixture/output"
        ! grep -q 'FaultCode=' "$fixture/output"
        ;;
    interrupted) test "$rc" -ne 0 ;;
    esac
    printf 'PASS %s (%s s, rc=%s)\n' "$mode" "$elapsed" "$rc"
done
# A fresh success after all failure paths must contain no stale diagnostics.
export LCM_EVENT_CASE=immediate-fault
rm -f "$fixture/rpc"
sh "$fixture/run.sh" "$helper" > "$fixture/output" 2>&1
test "$(cat "$fixture/output")" = 'DUStateChange! ERROR: operation=Install state=Failed FaultCode=7032 FaultString=exact fault text'
test -z "$(find /tmp -maxdepth 1 -type d -name 'du_state_change_*' -print)"
echo 'PASS repeat after failures: no stale output or capture directories'

# 044 sources this file after the shared helper. It must not replace the
# subscriber protocol with the old single-argument Lua invocation.
export LCM_EVENT_POLICY="${helper%/*}/transfer_policy.sh"
rm -f "$fixture/rpc"
sh "$fixture/run.sh" "$helper" > "$fixture/output" 2>&1
test "$(cat "$fixture/output")" = 'DUStateChange! ERROR: operation=Install state=Failed FaultCode=7032 FaultString=exact fault text'
test ! -e "$(cat "$fixture/capture-dir")"
! kill -0 "$(cat "$fixture/pid")" 2>/dev/null
echo 'PASS transfer-policy integration: shared subscriber protocol'

# Force completion between the loop's marker check and its process/deadline
# check. A subscriber that has just published completion must not look failed.
cat > "$fixture/race.sh" <<'SH'
set -eu
. "$1"
_DU_SUB_DIR="$LCM_EVENT_FIXTURE/race"
_DU_SUB_PID=unused
mkdir -p "$_DU_SUB_DIR"
kill() {
    printf '1\n' > "$_DU_SUB_DIR/done"
    return 1
}
wait_du_state_change_marker done || {
    echo 'FAIL completion published during process-exit check' >&2
    exit 1
}
rm "$_DU_SUB_DIR/done"
kill() { return 0; }
_tick_calls=0
du_state_change_ticks() {
    _tick_calls=$((_tick_calls + 1))
    _du_ticks=0
    if [ "$_tick_calls" -eq 2 ]; then
        printf '1\n' > "$_DU_SUB_DIR/done"
        _du_ticks=1000
    fi
}
wait_du_state_change_marker done || {
    echo 'FAIL completion published during deadline check' >&2
    exit 1
}
SH
sh "$fixture/race.sh" "$helper"
echo 'PASS completion at process-exit and deadline boundaries'
