#!/bin/bash
set -euo pipefail

helpers=$(realpath "$(dirname "${BASH_SOURCE[0]}")/../../scripts/helpers.sh")
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export CI_PROJECT_DIR="$scratch/project" CI_JOB_ID=123
mkdir -p "$CI_PROJECT_DIR" "$scratch/bin"
cd "$scratch"
# shellcheck source=../../scripts/helpers.sh
source "$helpers"

fail() { printf 'FAIL %s\n' "$*" >&2; exit 1; }
assert_equal() { [ "$1" = "$2" ] || fail "expected '$2', got '$1'"; }
assert_contains() { [[ "$1" == *"$2"* ]] || fail "missing '$2' in '$1'"; }
assert_absent() { [[ "$1" != *"$2"* ]] || fail "unexpected '$2' in '$1'"; }
pass() { printf 'PASS %s\n' "$*"; }

assert_equal "$(format_duration 5)" '5 s'
assert_equal "$(format_duration 42)" '42 s'
assert_equal "$(format_duration 252)" '4 min 12 s'
assert_equal "$(format_duration 3720)" '1 h 2 min'
assert_equal "$(format_duration 0)" '0 s'
assert_equal "$(format_duration 60)" '1 min'
assert_equal "$(format_duration 08)" '8 s'
if format_duration invalid; then fail 'accepted invalid duration'; fi
pass 'duration formatting'

output=$(log_warn 'Continue with cleanup')
assert_contains "$output" $'\e[1;38;5;208m⚠️'
assert_contains "$(log_budget 'Time left')" $'\e[96m⏳'
assert_contains "$(log_skip 'Already done')" $'\e[90m⏩'
assert_contains "$(log_stop 'Tests stopped')" $'\e[1;91m🛑'
assert_contains "$(log_summary 'Finished')" $'\e[1m🏁'
pass 'log colors and glyphs'

# Run the debug collection command from the job template with a stub SSH.
(
 lifecycle="$(dirname "$helpers")/../dut-lifecycle.yml"
 debug_command=$(sed -n 's/^ *teardown_step "Collect debug information" [0-9][0-9]* \(.*\) || true$/\1/p' "$lifecycle")
 [ -n "$debug_command" ] || fail 'missing debug collection command'
 cat > "$scratch/bin/ssh" <<'SH'
#!/bin/sh
[ -t 0 ] || exit 1
[ "$#" -eq 6 ] && [ "$*" = '-t -o LogLevel=ERROR root@debug-device /bin/getDebugInformation --all' ] || exit 1
sleep 0.1
printf 'debug output\n'
SH
 chmod +x "$scratch/bin/ssh"
 export PATH="$scratch/bin:$PATH" TARGET_LAN_IP=debug-device
 debug_output="$scratch/debug-output"
 printf '\000' | bash -ec "$debug_command" > "$debug_output" 2>&1
 grep -aFq 'debug output' "$debug_output" || fail 'missing debug output'
 if grep -aFq '^@' "$debug_output"; then fail 'debug output contains echoed ^@'; fi
 cmp -s "$debug_output" <(tr -d '\000' < "$debug_output") || fail 'debug output contains NUL'
 rm "$scratch/bin/ssh"
 pass 'debug collection preserves PTY output without echoing NUL'
)

# Run the QEMU template's script entries as one job shell with no VM.
(
 qemu_template="$(dirname "$helpers")/../testbed/qemu-x86-64.yml"
 qemu_script="$scratch/qemu-script.sh"
 awk '
  /^  script:$/ { script = 1; next }
  script && /^  [^ ]/ { exit }
  script && /^    - \|$/ { next }
  script && /^    - / { print substr($0, 7) }
  script && /^      / { print substr($0, 7) }
 ' "$qemu_template" > "$qemu_script"
 mkdir -p "$scratch/qemu/bin" "$scratch/qemu/.gitlab/scripts" "$scratch/qemu/.gitlab/tests/cram/scripts"
 cd "$scratch/qemu"
 ln -s "$helpers" .gitlab/scripts/helpers.sh
 cat > .gitlab/tests/cram/scripts/resolve-component-tests.py <<'SH'
#!/bin/sh
printf '%s\n' '.gitlab/tests/cram/smoke.t'
SH
 cat > bin/testbed-qemu <<'SH'
#!/bin/sh
case "$QEMU_RESULT" in
 cutoff)
  trap 'echo "QEMU received SIGTERM"; exit 143' TERM
  sleep 30 &
  wait "$!"
  ;;
 *) exit "$QEMU_RESULT" ;;
esac
SH
 export REAL_TIMEOUT
 REAL_TIMEOUT=$(command -v timeout)
 cat > bin/timeout <<'SH'
#!/bin/sh
if [ "$1" = --signal=TERM ] && [ "$4" = testbed-qemu ] && [ "$QEMU_RESULT" = cutoff ]; then
 [ "$2" = --kill-after=150s ] && [ "$3" -ge 120 ] || exit 99
 shift 3
 exec "$REAL_TIMEOUT" --signal=TERM --kill-after=2s 1s "$@"
fi
exec "$REAL_TIMEOUT" "$@"
SH
 chmod +x bin/* .gitlab/tests/cram/scripts/resolve-component-tests.py
 export PATH="$PWD/bin:$PATH" CI_PROJECT_DIR="$PWD" CI_JOB_TIMEOUT=600
 export COMPONENT=smoke DUT_BOARD=qemu-x86-64 TESTBED_QEMU_IMAGE=image TESTBED_QEMU_ACCEL=kvm
 export CRAM_TEST_SUITE_POST=.gitlab/tests/cram/post/generic TEST_TEARDOWN_RESERVE=180
 export CI_JOB_STARTED_AT QEMU_RESULT
 CI_JOB_STARTED_AT=$(date -u +%FT%TZ)
 for QEMU_RESULT in 0 1 cutoff; do
  log="$scratch/qemu-$QEMU_RESULT.log"
  rc=0
  bash -eu -o pipefail "$qemu_script" > "$log" 2>&1 || rc=$?
  output=$(cat "$log")
  assert_contains "$output" '⏳ Time budget:'
  {
   printf '%s\n' 'section_start:testbed-setup[collapsed=true] 📦 Testbed Setup'
   printf '%s\n' 'section_end:testbed-setup'
   printf '%s\n' 'section_start:test-execution[collapsed=false] 📦 Test Execution [smoke]'
   if [ "$QEMU_RESULT" != 1 ]; then
    printf '%s\n' 'section_end:test-execution'
   fi
  } > "$scratch/qemu-headers.expected"
  # Ignore timestamps and terminal escapes when comparing the section markers.
  sed -nE $'s/^(section_(start|end):)[0-9]+:/\\1/; s/\e\\[[0-9;]*[Km]//g; s/\r/ /; s/ $//; /^section_/p' \
   "$log" > "$scratch/qemu-headers.actual"
  diff -u "$scratch/qemu-headers.expected" "$scratch/qemu-headers.actual"
  if [ "$QEMU_RESULT" = cutoff ]; then
   assert_equal "$rc" 86
   assert_contains "$output" 'QEMU received SIGTERM'
   assert_contains "$output" '🛑 Tests stopped on purpose: the time budget ended.'
   assert_contains "$output" 'The job fails with exit code 86, which means a time limit was reached.'
  else
   assert_equal "$rc" "$QEMU_RESULT"
   assert_absent "$output" 'Tests stopped on purpose'
  fi
 done
 pass 'QEMU preserves normal section headers and exit codes, and logs a SIGTERM cutoff with exit 86'
)

output=$(run_step 'Run a successful command' 2 /bin/true)
assert_contains "$output" '  ✅ Run a successful command ('
assert_absent "$output" $'\e['
assert_absent "$output" 'exit code'
assert_absent "$output" 'section_start:'
assert_absent "$output" 'time limit'
pass 'one success line without failure details or a step section'

rc=0
run_step 'Wait for completion' 1 sleep 5 > "$scratch/timeout.log" || rc=$?
assert_equal "$rc" 124
assert_equal "$RUN_STEP_STATUS" 124
output=$(cat "$scratch/timeout.log")
assert_contains "$output" $'\e[1;38;5;208m⚠️ WARNING:'
assert_absent "$output" '❌ ERROR:'
assert_contains "$output" 'stopped at its time limit of 1 s'
assert_contains "$output" 'exit code 124: time limit reached'
assert_absent "$output" 'section_start:'
assert_absent "$output" 'name='
pass 'real command timeout and stop sentence'

for limit in 0 -1 invalid; do
 rc=0
 run_step 'Do not run this command' "$limit" touch "$scratch/ran" > "$scratch/skip.log" || rc=$?
 assert_equal "$rc" 125
 [ ! -e "$scratch/ran" ] || fail 'invalid limit ran the command'
 assert_contains "$(cat "$scratch/skip.log")" 'exit code 125: skipped'
done
rc=0
run_step 'Refuse shell builtins' 2 true > "$scratch/builtin.log" || rc=$?
assert_equal "$rc" 126
pass 'invalid limits and shell builtins are refused'

for status in 86 137 7; do
 rc=0
 run_step 'Run a failing command' 2 bash -c "exit $status" > "$scratch/status.log" || rc=$?
 assert_equal "$rc" "$status"
 assert_contains "$(cat "$scratch/status.log")" "exit code $status:"
 assert_contains "$(cat "$scratch/status.log")" $'\e[1;38;5;208m⚠️ WARNING:'
 assert_absent "$(cat "$scratch/status.log")" '❌ ERROR:'
done
assert_contains "$(run_step 'Report a time limit' 2 bash -c 'exit 86' || :)" 'a time limit was reached'
pass 'command failure status is preserved and explained'

rc=0
(
 section_start setup 'Device setup' collapsed '🔧'
 fatal_error 'Setup cannot continue'
) > "$scratch/fatal.log" || rc=$?
assert_equal "$rc" 1
output=$(cat "$scratch/fatal.log")
assert_contains "$output" '🔧 Device setup'
assert_contains "$output" $'section_end:'
[[ "$output" == *section_end:*'❌ ERROR: Setup cannot continue'* ]] || fail 'fatal error appeared inside the section'
pass 'fatal error closes the phase before printing'

output=$(
 section_start cleanup Cleanup collapsed '🧹'
 log_warn 'A log is missing'
 log_error 'A command failed'
 section_end cleanup
)
[[ "$output" == *section_end:*'⚠️ WARNING: A log is missing'*'❌ ERROR: A command failed'* ]] || fail 'section problems were not repeated outside'
assert_contains "$(section_start build Build)" '📦 Build'
assert_contains "$(section_start tests Tests expanded '🧪')" '🧪 Tests'
pass 'phase emoji and visible warning/error replay'

rc=0
(
 export CI_JOB_ID=125
 section_start setup Setup collapsed '🔧'
 setup_step 'Wait for setup' 1 sleep 5
 printf 'SHOULD NOT RUN\n'
) > "$scratch/setup.log" || rc=$?
assert_equal "$rc" 86
output=$(cat "$scratch/setup.log")
[[ "$output" == *section_end:*'❌ ERROR:'* ]] || fail 'setup timeout error appeared inside section'
assert_contains "$output" 'exit code 86, which means a time limit was reached'
assert_absent "$output" 'SHOULD NOT RUN'
rc=0
setup_step 'Run failed setup' 2 /bin/false > "$scratch/setup-failed.log" || rc=$?
assert_equal "$rc" 1
assert_contains "$(cat "$scratch/setup-failed.log")" '❌ ERROR:'
pass 'setup timeout exits with 86; ordinary failure returns its status'

TEARDOWN_DEADLINE=$(($(date +%s) + 30))
teardown_step 'Collect logs' 2 /bin/false > "$scratch/teardown.log"
assert_equal "$RUN_STEP_STATUS" 1
assert_contains "$(cat "$scratch/teardown.log")" '⚠️ WARNING:'
assert_absent "$(cat "$scratch/teardown.log")" '❌ ERROR:'
TEARDOWN_DEADLINE=$(date +%s)
teardown_step 'Collect logs' 2 touch "$scratch/ran" > "$scratch/deadline.log"
assert_equal "$RUN_STEP_STATUS" 125
[ ! -e "$scratch/ran" ] || fail 'expired deadline ran command'
assert_equal "$(cat "$scratch/deadline.log")" $'\e[90m⏩ Collect logs: skipped, the time for log collection ran out\e[0m'
pass 'teardown continues after failures and deadline skips'

cat > "$scratch/bin/ssh" <<'SH'
#!/bin/sh
exit "${SSH_STATUS:-0}"
SH
chmod +x "$scratch/bin/ssh"
export PATH="$scratch/bin:$PATH" TARGET_LAN_IP=unused SSH_STATUS=1
TEARDOWN_DEADLINE=$(($(date +%s) + 30))
TEARDOWN_WARNINGS=0
if device_reachable > "$scratch/device.log"; then fail 'failed device probe returned success'; fi
assert_contains "$(cat "$scratch/device.log")" 'Device logs and debug information are skipped'
assert_equal "$TEARDOWN_WARNINGS" 1
assert_absent "$(cat "$scratch/device.log")" 'Check that the device answers over SSH failed'
SSH_STATUS=0
device_reachable > "$scratch/device.log"
assert_equal "$TEARDOWN_WARNINGS" 1
for status in 1 124 137 125; do
 TEARDOWN_SSH_RECOVERY_STATUS=$status
 TEARDOWN_WARNINGS=0
 TEARDOWN_STEPS_SKIPPED=0
 # SSH would succeed here: failed recovery must skip the probe entirely.
 if device_reachable > "$scratch/device.log"; then fail 'probed after failed recovery'; fi
 assert_equal "$TEARDOWN_WARNINGS" 1
 assert_equal "$TEARDOWN_STEPS_SKIPPED" 1
 assert_equal "$RUN_STEP_STATUS" 125
 assert_contains "$(cat "$scratch/device.log")" '⏩ Check that the device answers over SSH: skipped'
done
unset TEARDOWN_SSH_RECOVERY_STATUS
TEARDOWN_DEADLINE=$(date +%s)
if device_reachable > "$scratch/device.log"; then fail 'skipped device probe returned success'; fi
pass 'device predicate warns once and skips its probe after failed recovery'

output=$(unset CI_JOB_STARTED_AT CI_JOB_TIMEOUT; teardown_begin; teardown_device_logs_begin)
assert_contains "$output" '⚠️ WARNING:'
assert_contains "$output" '⏳ Log collection may take 4 min'
assert_absent "$output" 'deadline='
assert_absent "$output" 'job_end='
pass 'teardown budget uses readable durations without epoch records'

assert_equal "$(read_outcome)" unknown
for outcome in passed tests-failed cutoff hung-test setup-timeout; do
 write_outcome "$outcome"
 assert_equal "$(read_outcome)" "$outcome"
 assert_equal "$(bash -c 'source "$1"; read_outcome' bash "$helpers")" "$outcome"
done
if write_outcome invalid; then fail 'accepted invalid outcome'; fi
assert_equal "$(read_outcome)" setup-timeout
assert_equal "$(job_state_dir)" "$CI_PROJECT_DIR/.ci-job-state/$CI_JOB_ID"
assert_equal "$(CI_JOB_ID=124 read_outcome)" unknown
pass 'all outcome words persist across shells and are isolated per job'

assert_equal "$(read_duration setup)" unknown
write_duration setup 252
write_duration tests 0042
assert_equal "$(read_duration setup)" 252
assert_equal "$(read_duration tests)" 42
assert_equal "$(bash -c 'source "$1"; read_duration setup' bash "$helpers")" 252
if write_duration '../escape' 1; then fail 'accepted invalid duration name'; fi
if write_duration setup invalid; then fail 'accepted invalid stored duration'; fi
assert_equal "$(read_duration setup)" 252
pass 'durations persist across shells with validated names and values'

# Keep this setup job separate from the generic state round-trip assertions.
(
 export CI_JOB_ID=200 CI_JOB_STARTED_AT='2026-01-01T00:00:00Z'
 # A fixed job clock proves setup includes time before the shell started.
 date() {
  case "$*" in
   '-d 2026-01-01T00:00:00Z +%s') printf '1000\n' ;;
   '+%s') printf '1252\n' ;;
   *) command date "$@" ;;
  esac
 }
 setup_begin
 section_start setup Setup collapsed '🔧' > "$scratch/setup-success.log"
 setup_step 'Prepare the testbed' 2 /bin/true >> "$scratch/setup-success.log"
 source "$helpers"
 setup_step 'Validate the package' 2 /bin/true >> "$scratch/setup-success.log"
 setup_finish >> "$scratch/setup-success.log"
 output=$(cat "$scratch/setup-success.log")
 assert_contains "$output" '✅ Setup finished (2 steps), 4 min 12 s after the job started'
 [[ "$output" == *section_end:*'✅ Setup finished'* ]] || fail 'setup summary appeared inside section'
 assert_equal "$(read_duration setup)" 252
 assert_equal "$(bash -c 'source "$1"; read_duration setup' bash "$helpers")" 252
 pass 'setup counts survive sourcing and duration includes runner preparation'

 setup_begin
 section_start setup Setup collapsed '🔧' > "$scratch/setup-counts.log"
 setup_step 'Prepare the testbed' 2 /bin/true >> "$scratch/setup-counts.log"
 rc=0
 setup_step 'Read an optional diagnostic' 2 /bin/false >> "$scratch/setup-counts.log" || rc=$?
 assert_equal "$rc" 1
 setup_finish >> "$scratch/setup-counts.log"
 output=$(cat "$scratch/setup-counts.log")
 assert_contains "$output" '💡 Setup finished (1 steps done, 1 failed, 0 stopped), 4 min 12 s after the job started'
 assert_absent "$output" '✅ Setup finished'
 pass 'optional setup failures are counted without a success summary'

 hung_setup() { sleep 5; }
 export -f hung_setup
 for boot in no yes; do
  setup_begin
  if [ "$boot" = yes ]; then
   mark_device_boot_started
   [ -f "$(job_state_dir)/device-boot-started" ] || fail 'boot marker missing'
   bash -c 'source "$1"; test -f "$(job_state_dir)/device-boot-started"' bash "$helpers" || fail 'boot marker unavailable to after_script'
  else
   [ ! -e "$(job_state_dir)/device-boot-started" ] || fail 'setup began with stale boot marker'
  fi
  rc=0
  (
   section_start setup Setup collapsed '🔧'
   setup_step 'Wait for the device to boot' 1 bash -c hung_setup
   printf 'SHOULD NOT RUN\n'
  ) > "$scratch/hung-$boot.log" || rc=$?
  assert_equal "$rc" 86
  output=$(cat "$scratch/hung-$boot.log")
  error='❌ ERROR: Setup failed. "Wait for the device to boot" did not finish in 1 s and was stopped.'
  assert_contains "$output" "$error"
  [[ "$output" == *section_end:*"$error"* ]] || fail 'setup failure is hidden inside section'
  assert_contains "$output" '💡 The tests did not start. The job fails with exit code 86, which means a time limit was reached.'
  assert_contains "$output" '💡 Setup finished (0 steps done, 0 failed, 1 stopped), 4 min 12 s after the job started'
  assert_absent "$output" 'SHOULD NOT RUN'
  assert_absent "$output" '⚠️ WARNING:'
  assert_absent "$output" '✅ Setup finished'
  assert_equal "$(read_outcome)" setup-timeout
  assert_equal "$(read_duration setup)" 252
  assert_equal "$(bash -c 'source "$1"; read_outcome' bash "$helpers")" setup-timeout
  if [ "$boot" = yes ]; then
   assert_contains "$output" '💡 The device had started to boot, so teardown now tries to reach it and save its logs.'
   assert_absent "$output" '⏩ Device recovery'
  else
   assert_contains "$output" '⏩ Device recovery and log collection skipped: the job stopped before the device started to boot.'
   assert_absent "$output" 'The device had started to boot'
  fi
 done
 pass 'hung setup function exits 86 with visible error, persisted state and boot-dependent explanation'
)

# Exercise the boot settle step from the shared lifecycle.
(
 lifecycle="$(dirname "$helpers")/../dut-lifecycle.yml"
 settle_step=$(sed -n 's/^    - \(setup_step "Let the device settle after boot".*\)/\1/p' "$lifecycle")
 [ -n "$settle_step" ] || fail 'missing boot settle step'
 DUT_SLEEP_AFTER_BOOT=1
 output=$(eval "$settle_step")
 assert_contains "$output" '  ✅ Let the device settle after boot ('
 pass 'device boot settle delay appears as a successful setup step'
)

# Stub SSH so failures have distinct diagnostics and configurable elapsed time.
(
 cat > "$scratch/bin/ssh" <<'SH'
#!/bin/sh
read -r attempt < "$SSH_ATTEMPT_FILE"
attempt=$((attempt + 1))
printf '%s\n' "$attempt" > "$SSH_ATTEMPT_FILE"
printf 'ssh: attempt %s failed\n' "$attempt" >&2
[ "$attempt" -ne "$SSH_SUCCESS_ATTEMPT" ] || exit 0
sleep "$SSH_ATTEMPT_DELAY"
exit 23
SH
 chmod +x "$scratch/bin/ssh"
 export PATH="$scratch/bin:$PATH" TARGET_LAN_IP=unused DUT_SSH_CONNECT_TIMEOUT=1
 export SSH_ATTEMPT_FILE="$scratch/ssh-attempt" SSH_ATTEMPT_DELAY=1 SSH_SUCCESS_ATTEMPT=0
 export DUT_SSH_CONNECT_ATTEMPTS=120

 printf '0\n' > "$SSH_ATTEMPT_FILE"
 limit=8
 start=$SECONDS
 rc=0
 wait_for_ssh "$limit" 2> "$scratch/ssh-error" || rc=$?
 elapsed=$((SECONDS - start))
 assert_equal "$rc" 124
 (( elapsed <= limit - 2 )) || fail "SSH wait took ${elapsed}s with a ${limit}s limit"
 attempt=$(cat "$SSH_ATTEMPT_FILE")
 (( attempt > 0 && attempt < DUT_SSH_CONNECT_ATTEMPTS )) || fail 'SSH wait did not stop at its deadline'
 printf 'ssh: attempt %s failed\n' "$attempt" | cmp -s - "$scratch/ssh-error" || fail 'SSH deadline lost the last error'
 pass 'SSH deadline prints the last error and returns 124 before the step limit'

 printf '0\n' > "$SSH_ATTEMPT_FILE"
 SSH_ATTEMPT_DELAY=0 DUT_SSH_CONNECT_ATTEMPTS=2
 rc=0
 wait_for_ssh 20 2> "$scratch/ssh-error" || rc=$?
 assert_equal "$rc" 23
 assert_equal "$(cat "$SSH_ATTEMPT_FILE")" 2
 printf 'ssh: attempt 2 failed\n' | cmp -s - "$scratch/ssh-error" || fail 'SSH exhaustion lost the last error'
 pass 'SSH attempt exhaustion prints the last error and preserves its status'

 printf '0\n' > "$SSH_ATTEMPT_FILE"
 DUT_SSH_CONNECT_ATTEMPTS=5 SSH_SUCCESS_ATTEMPT=3
 wait_for_ssh 20 > "$scratch/ssh-output" 2> "$scratch/ssh-error"
 assert_equal "$(cat "$SSH_ATTEMPT_FILE")" 3
 [ ! -s "$scratch/ssh-output" ] && [ ! -s "$scratch/ssh-error" ] || fail 'SSH success printed retry diagnostics'
 pass 'SSH succeeds on the third attempt without printing retry diagnostics'
)

# The collector must preserve artifact names and try every snapshot on failure.
(
 mkdir -p "$scratch/collector/bin"
 cat > "$scratch/collector/bin/ssh" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >> "$SSH_COMMANDS"
printf 'snapshot: %s\n' "$*"
# A real SSH client consumes stdin unless -n is set, which must not eat the table.
[ "$1" = -n ] || cat >/dev/null
[ "${SSH_FAIL_COMMAND:-}" != "$3" ]
SH
 chmod +x "$scratch/collector/bin/ssh"
 export PATH="$scratch/collector/bin:$PATH" LABGRID_TARGET=example
 export SSH_COMMANDS="$scratch/collector/commands"
 cd "$scratch/collector"
 collect_device_logs
 expected=$'-n root@unused ps\n-n root@unused dmesg\n-n root@unused cat /var/log/messages\n-n root@unused opkg list'
 assert_equal "$(cat "$SSH_COMMANDS")" "$expected"
 for file in processes dmesg syslog opkg_list; do
  [ -s "$file-example.txt" ] || fail "missing $file snapshot"
 done
 assert_contains "$(cat syslog-example.txt)" 'cat /var/log/messages'
 assert_contains "$(cat opkg_list-example.txt)" 'opkg list'
 : > "$SSH_COMMANDS"
 export SSH_FAIL_COMMAND=dmesg
 rc=0
 collect_device_logs || rc=$?
 assert_equal "$rc" 1
 assert_equal "$(cat "$SSH_COMMANDS")" "$expected"
 pass 'device log table preserves commands and artifacts and continues after failure'
)

# Exercise the actual lifecycle commands with local archives and an SSH stub.
(
 lifecycle="$(dirname "$helpers")/../dut-lifecycle.yml"
 collect_debug=$(sed -n '/teardown_step "Collect debug information"/p' "$lifecycle")
 assert_contains "$collect_debug" 'script --quiet --echo never --command "ssh -t -o LogLevel=ERROR '
 assert_contains "$collect_debug" '/bin/getDebugInformation --all" /dev/null || true'
 pass 'debug collection keeps the SSH terminal, suppresses close notices and discards the typescript'

 copy_config=$(sed -n '/teardown_step "Copy device configuration"/p' "$lifecycle")
 core_steps=$(awk '
  /^\.dut-lifecycle.extract-debug:/ { block = 1; next }
  block && /^[^ ]/ { exit }
  block && /^      if \[ -e coredumps_all.tar.gz/ { started = 1 }
  started { print }
 ' "$lifecycle")
 debug_steps=$(awk '
  /^\.dut-lifecycle.extract-debug:/ { block = 1; next }
  block && /^      if \[ -e coredumps_all.tar.gz/ { exit }
  block && /^      if compgen/ { started = 1 }
  started { print }
 ' "$lifecycle")
 [ -n "$copy_config" ] && [ -n "$core_steps" ] || fail 'missing lifecycle commands'
 [ -n "$debug_steps" ] || fail 'missing debug archive commands'
 mkdir -p "$scratch/optional/bin" "$scratch/optional/device/etc/rc.d" "$scratch/optional/copy" "$scratch/optional/cores"
 export CONFIG_DEVICE_ROOT="$scratch/optional/device"
 export REAL_TAR
 REAL_TAR=$(command -v tar)
 printf 'configuration\n' > "$CONFIG_DEVICE_ROOT/etc/config"
 ln -s missing "$CONFIG_DEVICE_ROOT/etc/rc.d/missing-link"
 ln -s config "$CONFIG_DEVICE_ROOT/etc/config-link"
 mkfifo "$CONFIG_DEVICE_ROOT/etc/config-fifo"
 ln -s config-fifo "$CONFIG_DEVICE_ROOT/etc/fifo-link"
 cat > "$scratch/optional/bin/ssh" <<'SH'
#!/bin/sh
[ "$1" = root@unused ] && [ "${2#cd / && }" != "$2" ] || exit 99
cd "$CONFIG_DEVICE_ROOT" || exit $?
PATH=${PATH#*:} sh -c "${2#cd / && }" || exit $?
exit "${CONFIG_SSH_STATUS:-0}"
SH
 cat > "$scratch/optional/bin/tar" <<'SH'
#!/bin/sh
if [ "${CONFIG_EXTRACT_STATUS:-0}" != 0 ]; then
 cat >/dev/null
 exit "$CONFIG_EXTRACT_STATUS"
fi
exec "$REAL_TAR" "$@"
SH
 cat > "$scratch/optional/bin/rm" <<'SH'
#!/bin/sh
exit 17
SH
 cat > "$scratch/optional/bin/mv" <<'SH'
#!/bin/sh
exit 18
SH
 chmod +x "$scratch/optional/bin/"*
 cd "$scratch/optional/copy"
 export PATH="$scratch/optional/bin:$PATH" LABGRID_TARGET=example
 TEARDOWN_DEADLINE=$(($(date +%s) + 60))
 output=$(eval "$copy_config" 2>&1)
 assert_absent "$output" '⚠️ WARNING:'
 assert_equal "$(cat etc/config)" configuration
 [ ! -e etc/rc.d/missing-link ] && [ ! -L etc/rc.d/missing-link ] || fail 'dangling configuration link retained'
 assert_equal "$(cat etc/config-link)" configuration
 [ ! -L etc/config-link ] || fail 'valid configuration link was not dereferenced'
 [ ! -e etc/config-fifo ] || fail 'configuration FIFO retained'
 [ ! -e etc/fifo-link ] && [ ! -L etc/fifo-link ] || fail 'configuration FIFO link retained'
 pass 'configuration copy preserves file and valid symlink contents and skips FIFOs and dangling links without warnings'

 # Exercise a real tar read failure, not just an injected SSH exit status.
 if [ "$EUID" -ne 0 ]; then
  printf 'unreadable configuration\n' > "$CONFIG_DEVICE_ROOT/etc/unreadable"
  chmod 000 "$CONFIG_DEVICE_ROOT/etc/unreadable"
  output=$(eval "$copy_config" 2>&1)
  chmod 600 "$CONFIG_DEVICE_ROOT/etc/unreadable"
  assert_contains "$output" '⚠️ WARNING: Copy device configuration failed (exit code 2:'
  PATH=${PATH#*:} rm "$CONFIG_DEVICE_ROOT/etc/unreadable"
  pass 'unreadable regular configuration file still warns'
 else
  printf 'SKIP unreadable configuration file: root bypasses file permissions\n'
 fi

 # A failed remote read must warn even when local extraction succeeds.
 export CONFIG_SSH_STATUS=23
 output=$(eval "$copy_config" 2>&1)
 assert_contains "$output" '⚠️ WARNING: Copy device configuration failed (exit code 23:'
 CONFIG_SSH_STATUS=0
 export CONFIG_EXTRACT_STATUS=19
 output=$(eval "$copy_config" 2>&1)
 assert_contains "$output" '⚠️ WARNING: Copy device configuration failed (exit code 19:'
 CONFIG_EXTRACT_STATUS=0
 pass 'remote read and local configuration extraction failures still warn'

 # Use real filesystem operations except when injecting remove/rename failures.
 cd "$scratch/optional/cores"
 PATH=${PATH#*:}
 TEARDOWN_STEPS_SKIPPED=0
 eval "$debug_steps" > "$scratch/debug-absent.log" 2>&1
 assert_equal "$TEARDOWN_STEPS_SKIPPED" 2
 assert_absent "$(cat "$scratch/debug-absent.log")" '⚠️ WARNING:'
 assert_contains "$(cat "$scratch/debug-absent.log")" '⏩ Unpack debug information: skipped, no debug archive was collected'
 assert_contains "$(cat "$scratch/debug-absent.log")" '⏩ Rename debug information: skipped, no debug archive was collected'
 pass 'absent debug archive skips both dependent steps and counts each skip'

 printf 'debug contents\n' > debug-example.txt
 tar -czf debug-example_all.tar.gz debug-example.txt
 rm debug-example.txt
 output=$(eval "$debug_steps" 2>&1)
 assert_absent "$output" '⚠️ WARNING:'
 assert_equal "$(cat debug-information-example.txt)" 'debug contents'
 output=$(PATH="$scratch/optional/bin:$PATH"; eval "$debug_steps" 2>&1)
 assert_contains "$output" '⚠️ WARNING: Rename debug information failed (exit code 18:'
 printf 'not an archive\n' > debug-example_all.tar.gz
 output=$(eval "$debug_steps" 2>&1)
 assert_contains "$output" '⚠️ WARNING: Unpack debug information failed (exit code '
 rm debug-example_all.tar.gz debug-information-example.txt
 pass 'collected debug archives retain contents and unpack or rename failures still warn'

 output=$(eval "$core_steps" 2>&1)
 assert_absent "$output" '⚠️ WARNING:'
 assert_absent "$output" '✅'
 pass 'absent core archive skips removal and rename without warnings'

 tar -czf coredumps_all.tar.gz --files-from /dev/null
 output=$(eval "$core_steps" 2>&1)
 assert_absent "$output" '⚠️ WARNING:'
 [ ! -e coredumps_all.tar.gz ] && [ ! -e coredumps-example.tar.gz ] || fail 'empty core archive retained'
 pass 'empty core archive is removed without a rename warning'

 printf 'core data\n' > core
 tar -czf coredumps_all.tar.gz core
 output=$(eval "$core_steps" 2>&1)
 assert_absent "$output" '⚠️ WARNING:'
 assert_equal "$(tar -xOf coredumps-example.tar.gz core)" 'core data'
 pass 'nonempty core archive is renamed with its contents intact and no warning'

 printf 'not an archive\n' > coredumps_all.tar.gz
 output=$(eval "$core_steps" 2>&1)
 assert_contains "$output" '⚠️ WARNING: Remove an empty core dump archive failed (exit code '
 pass 'corrupt core archive still warns'

 tar -czf coredumps_all.tar.gz --files-from /dev/null
 output=$(PATH="$scratch/optional/bin:$PATH"; eval "$core_steps" 2>&1)
 assert_contains "$output" '⚠️ WARNING: Remove an empty core dump archive failed (exit code 17:'
 [ -e coredumps_all.tar.gz ] || fail 'failed removal discarded archive'
 tar -czf coredumps_all.tar.gz core
 output=$(PATH="$scratch/optional/bin:$PATH"; eval "$core_steps" 2>&1)
 assert_absent "$output" 'Remove an empty core dump archive failed'
 assert_contains "$output" '⚠️ WARNING: Rename the core dump archive failed (exit code 18:'
 [ -e coredumps_all.tar.gz ] || fail 'failed rename discarded archive'
 pass 'core archive removal and rename failures still warn and retain the source'
)

# after_script is a new shell: summaries must read saved outcomes and durations.
(
 ci_dir="$(dirname "$helpers")/.."
 assert_contains "$(teardown_begin expanded)" 'teardown-report[collapsed=false]'
 assert_contains "$(teardown_begin)" 'teardown-report[collapsed=true]'
 grep -qx '    - teardown_begin expanded' "$ci_dir/cdrouter.yml" || fail 'CDRouter does not expand the report'
 grep -qx '    - teardown_begin' "$ci_dir/testbed.yml" || fail 'cram does not use the default report state'
 if grep -q 'teardown_begin expanded' "$ci_dir/testbed.yml"; then
  fail 'cram expands the report'
 fi
 pass 'CDRouter expands the report and cram keeps it collapsed'

 export CI_JOB_ID=300 CI_JOB_STARTED_AT
 CI_JOB_STARTED_AT=$(date -u +%FT%TZ)
 export CI_JOB_TIMEOUT=600
 for outcome in passed tests-failed cutoff hung-test setup-timeout unknown; do
  setup_begin
  if [ "$outcome" != unknown ]; then
   write_outcome "$outcome" 7
   write_duration setup 382
   write_duration tests 2678
   mark_device_boot_started
  fi
  output=$(bash -eu -c '
   source "$1"
   teardown_begin
   teardown_step "Write the report" 2 /bin/true
   teardown_device_logs_begin
   section_start teardown-power-off "Teardown: power off" collapsed "🧹"
   teardown_cleanup_step "Power off the device" 2 /bin/true
   teardown_finish
  ' bash "$helpers")
  case "$outcome" in
   passed) expected='tests passed, 0 warnings, exit code 0' ;;
   tests-failed) expected='tests failed, 0 warnings, exit code 7' ;;
   cutoff) expected='tests cut off by the time budget, 0 warnings, exit code 86' ;;
   hung-test) expected='tests stopped because one test did not finish, 0 warnings, exit code 86' ;;
   setup-timeout) expected='setup failed at a time limit, 0 warnings, exit code 86' ;;
   unknown) expected='outcome unknown, 0 warnings, exit code unknown' ;;
  esac
  assert_contains "$output" "🏁 Summary: $expected"
  [[ "$output" == *'Teardown: report'*'Teardown: device logs'*'Teardown: power off'*'Teardown finished'*'🏁 Summary:'* ]] || fail 'teardown sections or summary out of order'
  if [ "$outcome" = setup-timeout ]; then
   assert_contains "$output" 'Setup stopped after 6 min 22 s · tests not started · teardown '
   assert_absent "$output" 'The device had started to boot, so teardown now tries to reach it and save its logs.'
  elif [ "$outcome" = unknown ]; then
   assert_contains "$output" 'Setup unknown · tests unknown · teardown '
   assert_contains "$output" '⏩ Device recovery and log collection skipped: the job stopped before the device started to boot.'
   assert_contains "$output" '💡 Teardown finished'
   assert_contains "$output" '9 skipped'
  else
   assert_contains "$output" 'Setup 6 min 22 s · tests 44 min 38 s · teardown '
   assert_absent "$output" 'The device had started to boot'
  fi
  if [ "$outcome" != unknown ]; then
   assert_contains "$output" '✅ Teardown finished'
  fi
 done
 pass 'all summary outcomes, exact exit status and durations survive a fresh shell'

 setup_begin
 write_outcome setup-timeout
 output=$(teardown_begin; teardown_device_logs_begin; printf 'booted: %s\n' "$TEARDOWN_DEVICE_BOOTED")
 assert_contains "$output" 'booted: false'
 assert_contains "$output" 'Device recovery and log collection skipped'
 mark_device_boot_started
 output=$(teardown_begin; teardown_device_logs_begin; printf 'booted: %s\n' "$TEARDOWN_DEVICE_BOOTED")
 assert_contains "$output" 'booted: true'
 assert_absent "$output" 'The device had started to boot'
 pass 'recovery decision uses the boot marker after a setup timeout'

 # Exercise the script failure and after_script in separate shells.
 setup_begin
 mark_device_boot_started
 rc=0
 bash -eu -c '
  source "$1"
  section_start setup Setup collapsed "🔧"
  setup_step "Wait for the device to boot" 1 sleep 5
 ' bash "$helpers" > "$scratch/setup-recovery.log" || rc=$?
 assert_equal "$rc" 86
 bash -eu -c '
  source "$1"
  teardown_begin
  teardown_device_logs_begin
  printf "booted: %s\n" "$TEARDOWN_DEVICE_BOOTED"
 ' bash "$helpers" >> "$scratch/setup-recovery.log"
 output=$(cat "$scratch/setup-recovery.log")
 recovery='💡 The device had started to boot, so teardown now tries to reach it and save its logs.'
 assert_equal "$(grep -Fc "$recovery" "$scratch/setup-recovery.log")" 1
 [[ "$output" == *'❌ ERROR: Setup failed.'*'💡 The tests did not start.'*"$recovery"*'Teardown: report'* ]] || fail 'recovery explanation out of order'
 assert_contains "$output" 'booted: true'
 pass 'setup timeout explains recovery once before teardown in a fresh shell'

 (
  export CI_JOB_ID=301
  setup_begin
  mark_device_boot_started
  output=$(teardown_begin; teardown_device_logs_begin)
  assert_contains "$output" "$recovery"
  pass 'unknown outcome still explains recovery during teardown'
 )

 output=$(
  teardown_begin
  teardown_step 'Write the report' 2 /bin/false
  teardown_device_logs_begin
  teardown_step 'Measure memory use' 1 sleep 5
  section_start teardown-power-off 'Teardown: power off' collapsed '🧹'
  TEARDOWN_DEADLINE=$(date +%s)
  teardown_step 'Rename debug information' 2 /bin/true
  teardown_cleanup_step 'Power off the device' 2 /bin/true
  teardown_finish
 )
 assert_contains "$output" '💡 Teardown finished'
 assert_absent "$output" '✅ Teardown finished'
 assert_contains "$output" '1 steps done, 1 failed, 1 stopped, 1 skipped'
 assert_contains "$output" '2 warnings, exit code 86'
 # Replaying a warning after its own section must not count it twice.
 [[ "$output" == *'teardown-report'$'\r'*'⚠️ WARNING: Write the report failed'*'Teardown: device logs'* ]] || fail 'report warning not replayed at its boundary'
 [[ "$output" == *'teardown-device-logs'$'\r'*'⚠️ WARNING: "Measure memory use" did not finish in 1 s and was stopped. Its output is missing from the artifacts.'*'Teardown: power off'* ]] || fail 'device warning not replayed at its boundary'
 [[ "$output" == *'teardown-power-off'$'\r'*'💡 Teardown finished'*'🏁 Summary:'* ]] || fail 'closing lines not at top level'
 pass 'timeouts, failures and skips counted once; mandatory cleanup survives exhausted collection'

 # Both timeout statuses must explain which artifacts are missing.
 for status in 124 137; do
  for step in 'Restore SSH access to the device' 'Collect device logs: process list, kernel log, system log, installed packages'; do
   output=$(
    teardown_begin
    teardown_device_logs_begin
    teardown_step "$step" 45 bash -c "exit $status"
    section_end
   )
   if [ "$step" = 'Restore SSH access to the device' ]; then
    suffix='The device logs are missing from the artifacts.'
   else
    suffix='Its output is missing from the artifacts.'
   fi
   warning="⚠️ WARNING: \"$step\" did not finish in 45 s and was stopped. $suffix"
   assert_contains "$output" "$warning"
   assert_equal "$(printf '%s\n' "$output" | grep -Fc "$warning")" 2
  done
 done
 pass 'stopped recovery and collection name missing artifacts and replay their warnings'

 # Fixed time makes the budget arithmetic and first device-section line exact.
 date() {
  case "$*" in
   '+%s') printf '1000\n' ;;
   '-d fixed +%s') printf '800\n' ;;
   *) command date "$@" ;;
  esac
 }
 CI_JOB_STARTED_AT=fixed CI_JOB_TIMEOUT=400
 output=$(teardown_begin; teardown_device_logs_begin)
 [[ "$output" == *'🧹 Teardown: device logs'$'\e[0m\n\e[96m⏳ Log collection may take 1 min 10 s (until 00:17 UTC). The job ends at 00:20 UTC.'* ]] || fail 'device budget is not first or does not respect the job tail'
 pass 'device section starts with the remaining collection budget and job end in UTC'
)
