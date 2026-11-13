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
assert_contains "$output" $'\e[1;33m⚠️'
assert_contains "$(log_budget 'Time left')" $'\e[96m⏳'
assert_contains "$(log_skip 'Already done')" $'\e[90m⏩'
assert_contains "$(log_stop 'Tests stopped')" $'\e[1;91m🛑'
assert_contains "$(log_summary 'Finished')" $'\e[1m🏁'
pass 'log colors and glyphs'

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
assert_contains "$output" $'\e[1;33m⚠️ WARNING:'
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
 if [ "$status" -eq 137 ]; then
  assert_contains "$(cat "$scratch/status.log")" 'killed (exit code 137)'
 else
  assert_contains "$(cat "$scratch/status.log")" "exit code $status:"
 fi
 assert_contains "$(cat "$scratch/status.log")" $'\e[1;33m⚠️ WARNING:'
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

rc=0
(
 setup_step 'Run killed setup' 45 bash -c 'kill -KILL "$$"' || exit "$?"
) > "$scratch/setup-killed.log" 2>&1 || rc=$?
assert_equal "$rc" 137
assert_contains "$(cat "$scratch/setup-killed.log")" 'Run killed setup killed (exit code 137)'
assert_absent "$(cat "$scratch/setup-killed.log")" 'job fails with exit code 86'
pass 'an immediate SIGKILL during setup remains a command failure'

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
if device_reachable > "$scratch/device.log"; then fail 'failed device probe returned success'; fi
assert_contains "$(cat "$scratch/device.log")" 'Device logs and debug information are skipped'
SSH_STATUS=0
device_reachable > "$scratch/device.log"
TEARDOWN_DEADLINE=$(date +%s)
if device_reachable > "$scratch/device.log"; then fail 'skipped device probe returned success'; fi
pass 'device predicate preserves failure despite best-effort teardown'

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

 rc=0
 (
  setup_begin
  section_start setup Setup collapsed '🔧'
  setup_optional_step 'Read an optional diagnostic' 2 /bin/false || fail 'optional failure returned an error'
  setup_optional_step 'Wait for an optional diagnostic' 1 sleep 5 || fail 'optional timeout returned an error'
  setup_optional_step 'Read another diagnostic' 2 /bin/true
  setup_finish
 ) > "$scratch/setup-optional.log" || rc=$?
 assert_equal "$rc" 0
 output=$(cat "$scratch/setup-optional.log")
 assert_contains "$output" '⚠️ WARNING: Read an optional diagnostic failed'
 assert_contains "$output" '⚠️ WARNING: Wait for an optional diagnostic stopped at its time limit of 1 s'
 assert_contains "$output" '✅ Read another diagnostic'
 assert_contains "$output" 'Setup finished (1 steps done, 1 failed, 1 stopped)'
 assert_absent "$output" 'exit code 86'
 pass 'optional setup diagnostics warn, count outcomes and allow the next command'

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

# after_script is a new shell: summaries must read saved outcomes and durations.
(
 assert_contains "$(teardown_begin expanded)" 'teardown-report[collapsed=false]'
 assert_contains "$(teardown_begin)" 'teardown-report[collapsed=true]'
 pass 'teardown report supports expanded and collapsed sections'

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
   assert_contains "$output" 'The device had started to boot, so teardown now tries to reach it and save its logs.'
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
 assert_contains "$output" 'The device had started to boot'
 pass 'recovery decision uses the boot marker after a setup timeout'

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
  if [ "$status" -eq 137 ]; then
   limit=1
   command='trap "" TERM; exec sleep 30'
  else
   limit=45
   command='exit 124'
  fi
  for step in 'Restore SSH access to the device' 'Collect device logs: process list, kernel log, system log, installed packages'; do
   output=$(
    teardown_begin
    teardown_device_logs_begin
    teardown_step "$step" "$limit" bash -c "$command" 2> "$scratch/teardown-timeout.stderr"
    assert_equal "$RUN_STEP_STATUS" 124
    section_end
   )
   if [ "$step" = 'Restore SSH access to the device' ]; then
    suffix='The device logs are missing from the artifacts.'
   else
    suffix='Its output is missing from the artifacts.'
   fi
   warning="⚠️ WARNING: \"$step\" did not finish in $limit s and was stopped. $suffix"
   assert_contains "$output" "$warning"
   assert_equal "$(printf '%s\n' "$output" | grep -Fc "$warning")" 2
  done
 done
 pass 'stopped recovery and collection name missing artifacts and replay their warnings'

 output=$(
  teardown_begin
  teardown_device_logs_begin
  teardown_step 'Collect device logs' 45 bash -c 'kill -KILL "$$"' 2> "$scratch/teardown-killed.stderr"
  assert_equal "$RUN_STEP_STATUS" 137
  assert_equal "$TEARDOWN_STEPS_FAILED" 1
  assert_equal "$TEARDOWN_STEPS_STOPPED" 0
  section_end
 )
 assert_contains "$output" '⚠️ WARNING: Collect device logs killed (exit code 137)'
 pass 'an immediate SIGKILL during teardown counts as failed'

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
