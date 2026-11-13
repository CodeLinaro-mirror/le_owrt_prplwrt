#!/bin/bash

log_success() { printf '\e[92m✅ %s\e[0m\n' "$*"; }
log_info() { printf '\e[93m💡 %s\e[0m\n' "$*"; }
log_budget() { printf '\e[96m⏳ %s\e[0m\n' "$*"; }
log_skip() { printf '\e[90m⏩ %s\e[0m\n' "$*"; }
log_stop() { printf '\e[1;91m🛑 %s\e[0m\n' "$*"; }
log_summary() { printf '\e[1m🏁 %s\e[0m\n' "$*"; }

# Keep warnings and errors visible when their section is collapsed.
_section_problem() {
	local message
	printf -v message '\e[%sm%s\e[0m' "$1" "$2"
	printf '%s\n' "$message"
	if [ -n "${OPEN_SECTION:-}" ]; then
		SECTION_PROBLEMS="${SECTION_PROBLEMS:-}${message}"$'\n'
	fi
}

log_error() { _section_problem 91 "❌ ERROR: $*"; }
log_warn() {
	TEARDOWN_WARNINGS=$((${TEARDOWN_WARNINGS:-0} + 1))
	_section_problem '1;33' "⚠️ WARNING: $*"
}

# Durations are whole seconds; hour-long durations show hours and minutes.
format_duration() {
	[[ "${1:-}" =~ ^[0-9]+$ ]] || return 1
	local seconds=$((10#$1))
	if (( seconds >= 3600 )); then
		printf '%d h %d min\n' "$((seconds / 3600))" "$((seconds % 3600 / 60))"
	elif (( seconds >= 60 )); then
		if (( seconds % 60 )); then
			printf '%d min %d s\n' "$((seconds / 60))" "$((seconds % 60))"
		else
			printf '%d min\n' "$((seconds / 60))"
		fi
	else
		printf '%d s\n' "$seconds"
	fi
}

# section_start <id> [title] [collapsed|expanded] [phase emoji]
# Existing build sections keep the default package emoji. Protocol timestamps
# are required by GitLab; only the title is displayed in the job log.
section_start() {
	local section_title="$1" section_description="${2:-$1}"
	local collapse_state="${3:-expanded}" phase="${4:-📦}" collapsed_flag=false
	[ "$collapse_state" != collapsed ] || collapsed_flag=true
	# Phases are sequential: close an unfinished phase before opening another.
	section_close_on_fatal
	OPEN_SECTION="$section_title"
	SECTION_PROBLEMS=
	printf 'section_start:%s:%s[collapsed=%s]\r\e[0K\e[95m%s %s\e[0m\n' \
		"$(date +%s)" "$section_title" "$collapsed_flag" "$phase" "$section_description"
}

# section_end [id] closes the current section and repeats its problems outside.
section_end() {
	local section_title="${1:-${OPEN_SECTION:-}}"
	[ -n "$section_title" ] || return 0
	printf 'section_end:%s:%s\r\e[0K\n' "$(date +%s)" "$section_title"
	if [ "$section_title" = "${OPEN_SECTION:-}" ]; then
		OPEN_SECTION=
		printf '%s' "${SECTION_PROBLEMS:-}"
		SECTION_PROBLEMS=
	fi
}

section_close_on_fatal() {
	if [ -n "${OPEN_SECTION:-}" ]; then
		section_end "$OPEN_SECTION"
	fi
}

# The caller chooses the exit status (for example the setup timeout status).
fatal_error() {
	section_close_on_fatal
	log_error "$@"
	return 1
}

# run_step <sentence> <positive time limit in seconds> <external command>...
# Keep the command status and duration available to wrappers in the same shell.
# Shell functions and builtins cannot be executed by timeout and return 126.
run_step() {
	local step="$1" limit="$2" start rc=0 message
	local failure_log="${_step_failure_log:-log_warn}"
	shift 2
	start=$SECONDS
	if ! [[ "$limit" =~ ^0*[1-9][0-9]*$ ]]; then
		rc=125
		message="$step skipped: the time limit must be a positive number of seconds (exit code 125: skipped)."
	elif [ "$#" -eq 0 ]; then
		rc=126
		message="$step failed: an external command is required (exit code 126: command cannot be run)."
	else
		case "$(type -t "$1")" in
			function|builtin)
				rc=126
				message="$step failed: use an external command (exit code 126: command cannot be run)."
				;;
			*)
				timeout --kill-after=5 "$limit" "$@" || rc=$?
				case "$rc" in
					0) ;;
					124|137)
						message="$step stopped at its time limit of $(format_duration "$limit") (exit code $rc: time limit reached)."
						if [ "${_step_close_on_timeout:-false}" = true ]; then
							section_close_on_fatal
						fi
						;;
					125) message="$step failed (exit code 125: skipped; the command or time limit runner could not complete)." ;;
					86) message="$step failed (exit code 86: a time limit was reached)." ;;
					*) message="$step failed (exit code $rc: command failed)." ;;
				esac
				;;
		esac
	fi
	RUN_STEP_STATUS=$rc
	RUN_STEP_DURATION=$((SECONDS - start))
	if [ "$rc" -eq 0 ]; then
		printf '  ✅ %s (%s)\n' "$step" "$(format_duration "$RUN_STEP_DURATION")"
	else
		"$failure_log" "$message"
	fi
	return "$rc"
}

# Start once before the first setup section. Sourcing helpers again must not
# reset counts: GitLab runs before_script and script in the same shell.
setup_begin() {
	SETUP_STEPS_DONE=0
	SETUP_STEPS_FAILED=0
	SETUP_STEPS_STOPPED=0
	local directory
	directory=$(job_state_dir) || return 1
	mkdir -p "$directory" || return 1
	rm -f "$directory/device-boot-started" "$directory/outcome" "$directory/duration-setup" "$directory/duration-tests" "$directory/exit-code"
}

mark_device_boot_started() {
	local directory
	directory=$(job_state_dir) || return 1
	mkdir -p "$directory" || return 1
	: > "$directory/device-boot-started"
}

# Use the same job-start clock as the test budget, including runner preparation.
setup_finish() {
	local job_start elapsed duration total
	local done=${SETUP_STEPS_DONE:-0} failed=${SETUP_STEPS_FAILED:-0} stopped=${SETUP_STEPS_STOPPED:-0}
	total=$((done + failed + stopped))
	if job_start=$(date -d "${CI_JOB_STARTED_AT:-}" +%s 2>/dev/null) &&
		[ -n "${CI_JOB_STARTED_AT:-}" ]; then
		elapsed=$(( $(date +%s) - job_start ))
		[ "$elapsed" -ge 0 ] || elapsed=0
		write_duration setup "$elapsed" || return 1
		duration="$(format_duration "$elapsed") after the job started"
	else
		duration='time since the job started is unavailable'
	fi
	section_close_on_fatal
	if [ "$failed" -eq 0 ] && [ "$stopped" -eq 0 ]; then
		log_success "Setup finished ($total steps), $duration"
	else
		log_info "Setup finished ($done steps done, $failed failed, $stopped stopped), $duration"
	fi
}

_setup_step_error() {
	if [ "$RUN_STEP_STATUS" -eq 124 ] || [ "$RUN_STEP_STATUS" -eq 137 ]; then
		fatal_error "Setup failed. \"$_setup_step_name\" did not finish in $(format_duration "$_setup_step_limit") and was stopped." || :
	else
		log_error "$@"
	fi
}

# Setup timeouts fail the job, even for optional diagnostics. Ordinary command
# failures return to the caller's existing failure policy and count as failures.
setup_step() {
	local rc=0 _step_failure_log=_setup_step_error _step_close_on_timeout=true
	local _setup_step_name="$1" _setup_step_limit="$2" directory
	run_step "$@" || rc=$?
	case "$rc" in
		0) SETUP_STEPS_DONE=$((${SETUP_STEPS_DONE:-0} + 1)) ;;
		124|137)
			SETUP_STEPS_STOPPED=$((${SETUP_STEPS_STOPPED:-0} + 1))
			write_outcome setup-timeout || :
			log_info "The tests did not start. The job fails with exit code 86, which means a time limit was reached."
			directory=$(job_state_dir) || directory=
			if [ -n "$directory" ] && [ -f "$directory/device-boot-started" ]; then
				log_info "The device had started to boot, so teardown now tries to reach it and save its logs."
			else
				log_skip "Device recovery and log collection skipped: the job stopped before the device started to boot."
			fi
			setup_finish || :
			exit 86
			;;
		*) SETUP_STEPS_FAILED=$((${SETUP_STEPS_FAILED:-0} + 1)) ;;
	esac
	return "$rc"
}

# Compute the test budget after setup, keeping the job deadline in UTC.
test_budget() {
	local now deadline available
	now=$(date +%s)
	JOB_ELAPSED=$((now - $(date -d "$CI_JOB_STARTED_AT" +%s)))
	TEST_CUTOFF_TIMEOUT=$((CI_JOB_TIMEOUT - JOB_ELAPSED - TEST_TEARDOWN_RESERVE))
	deadline=$((now + TEST_CUTOFF_TIMEOUT))
	available=$TEST_CUTOFF_TIMEOUT
	[ "$available" -ge 0 ] || available=0
	log_budget "Time budget: the job may run $(format_duration "$CI_JOB_TIMEOUT"). $(format_duration "$JOB_ELAPSED") have passed and $(format_duration "$TEST_TEARDOWN_RESERVE") are kept
   for teardown and upload, so the tests may run $(format_duration "$available") (until $(date -u -d "@$deadline" +%H:%M) UTC)."
	write_duration setup "$JOB_ELAPSED"
	TEST_EXECUTION_START=$SECONDS
	if [ "$TEST_CUTOFF_TIMEOUT" -lt 120 ]; then
		write_outcome cutoff
		write_duration tests 0
		section_close_on_fatal
		log_error "The tests did not start: less than $(format_duration 120) remain in their time budget."
		tests_stopped cutoff
		log_error "The job fails with exit code 86, which means a time limit was reached."
		exit 86
	fi
}

tests_stopped() {
	case "$1" in
		cutoff) log_stop "Tests stopped on purpose: the time budget ended." ;;
		hung-test) log_stop "Tests stopped on purpose: one test did not finish." ;;
		*) return 1 ;;
	esac
	log_info "Results up to this point are kept. Teardown and artifact upload follow."
}

# The Python runner saves the stop reason before stopping or collecting results.
# An outer timeout preserves that reason if collection itself did not finish.
tests_finish() {
	local outcome
	write_duration tests "$((SECONDS - TEST_EXECUTION_START))"
	section_close_on_fatal
	case "$1" in
		0) write_outcome passed ;;
		86)
			outcome=$(read_outcome)
			[ "$outcome" = hung-test ] || outcome=cutoff
			write_outcome "$outcome"
			tests_stopped "$outcome"
			;;
		*) write_outcome tests-failed "$1" ;;
	esac
}

# Collection shares one wall-clock budget and leaves time for mandatory cleanup
# and artifact upload, even when after_script starts late.
TEARDOWN_COLLECTION_SECONDS=240
TEARDOWN_JOB_TAIL_SECONDS=130

teardown_begin() {
	local job_start
	TEARDOWN_START=$SECONDS
	TEARDOWN_STEPS_DONE=0
	TEARDOWN_STEPS_FAILED=0
	TEARDOWN_STEPS_STOPPED=0
	TEARDOWN_STEPS_SKIPPED=0
	TEARDOWN_WARNINGS=0
	TEARDOWN_OUTCOME=$(read_outcome) || TEARDOWN_OUTCOME=unknown
	TEARDOWN_DEADLINE=$(( $(date +%s) + TEARDOWN_COLLECTION_SECONDS ))
	TEARDOWN_JOB_END=
	section_start teardown-report "Teardown: report" "${1:-collapsed}" "🧹"
	if [ -z "${CI_JOB_STARTED_AT:-}" ] || [ -z "${CI_JOB_TIMEOUT:-}" ] ||
		! job_start=$(date -d "$CI_JOB_STARTED_AT" +%s 2>/dev/null); then
		log_warn "Missing or invalid job timing; allowing $(format_duration "$TEARDOWN_COLLECTION_SECONDS") for log collection."
	else
		TEARDOWN_JOB_END=$((job_start + CI_JOB_TIMEOUT))
		if [ "$((TEARDOWN_JOB_END - TEARDOWN_JOB_TAIL_SECONDS))" -lt "$TEARDOWN_DEADLINE" ]; then
			TEARDOWN_DEADLINE=$((TEARDOWN_JOB_END - TEARDOWN_JOB_TAIL_SECONDS))
		fi
	fi
}

teardown_device_logs_begin() {
	local left job_end directory
	section_start teardown-device-logs "Teardown: device logs" collapsed "🧹"
	left=$((TEARDOWN_DEADLINE - $(date +%s)))
	[ "$left" -ge 0 ] || left=0
	if [ -n "$TEARDOWN_JOB_END" ]; then
		job_end="The job ends at $(date -u -d "@$TEARDOWN_JOB_END" +%H:%M) UTC."
	else
		job_end="The job end time is unknown."
	fi
	log_budget "Log collection may take $(format_duration "$left") (until $(date -u -d "@$TEARDOWN_DEADLINE" +%H:%M) UTC). $job_end"
	export TEARDOWN_DEVICE_BOOTED=false
	directory=$(job_state_dir) || directory=
	if [ -n "$directory" ] && [ -f "$directory/device-boot-started" ]; then
		TEARDOWN_DEVICE_BOOTED=true
		if [ "$TEARDOWN_OUTCOME" = setup-timeout ] || [ "$TEARDOWN_OUTCOME" = unknown ]; then
			log_info "The device had started to boot, so teardown now tries to reach it and save its logs."
		fi
	else
		log_skip "Device recovery and log collection skipped: the job stopped before the device started to boot."
		# Recovery, host key, reachability probe and the six collection steps.
		TEARDOWN_STEPS_SKIPPED=$((TEARDOWN_STEPS_SKIPPED + 9))
	fi
}

_teardown_count_step() {
	case "$RUN_STEP_STATUS" in
		0) TEARDOWN_STEPS_DONE=$((${TEARDOWN_STEPS_DONE:-0} + 1)) ;;
		124|137) TEARDOWN_STEPS_STOPPED=$((${TEARDOWN_STEPS_STOPPED:-0} + 1)) ;;
		125) TEARDOWN_STEPS_SKIPPED=$((${TEARDOWN_STEPS_SKIPPED:-0} + 1)) ;;
		*) TEARDOWN_STEPS_FAILED=$((${TEARDOWN_STEPS_FAILED:-0} + 1)) ;;
	esac
}

_teardown_step_warning() {
	if [ "$RUN_STEP_STATUS" -eq 124 ] || [ "$RUN_STEP_STATUS" -eq 137 ]; then
		local message
		message="\"$_teardown_step_name\" did not finish in $(format_duration "$_teardown_step_limit") and was stopped."
		case "$_teardown_step_name" in
			'Restore SSH access to the device')
				message="$message The device logs are missing from the artifacts." ;;
			'Collect device logs: process list, kernel log, system log, installed packages'|'Collect debug information'|'Measure memory use'|'Copy '*)
				message="$message Its output is missing from the artifacts." ;;
		esac
		log_warn "$message"
	else
		log_warn "$@"
	fi
}

# Mandatory cleanup retains its own limit even when collection time runs out.
teardown_cleanup_step() {
	local _step_failure_log=_teardown_step_warning
	local _teardown_step_name="$1" _teardown_step_limit="$2"
	run_step "$@" || :
	_teardown_count_step
}

# Reserve the five-second KILL grace inside the collection deadline. Teardown
# failures are warnings and must not prevent later cleanup. RUN_STEP_STATUS
# retains the actual status for predicates such as device_reachable.
teardown_step() {
	local step="$1" limit="$2" left
	shift 2
	left=$((TEARDOWN_DEADLINE - $(date +%s) - 5))
	if [ "$left" -le 0 ]; then
		RUN_STEP_STATUS=125
		RUN_STEP_DURATION=0
		log_skip "$step: skipped, the time for log collection ran out"
		_teardown_count_step
		return 0
	fi
	if [[ "$limit" =~ ^0*[1-9][0-9]*$ ]] && [ "$left" -lt "$((10#$limit))" ]; then
		limit="$left"
	fi
	teardown_cleanup_step "$step" "$limit" "$@"
}

teardown_finish() {
	local duration counts outcome exit_code setup tests warnings
	duration=$((SECONDS - TEARDOWN_START))
	write_duration teardown "$duration" || :
	duration=$(format_duration "$duration")
	section_end
	counts="$TEARDOWN_STEPS_DONE steps done"
	[ "$TEARDOWN_STEPS_FAILED" -eq 0 ] || counts="$counts, $TEARDOWN_STEPS_FAILED failed"
	[ "$TEARDOWN_STEPS_STOPPED" -eq 0 ] || counts="$counts, $TEARDOWN_STEPS_STOPPED stopped"
	[ "$TEARDOWN_STEPS_SKIPPED" -eq 0 ] || counts="$counts, $TEARDOWN_STEPS_SKIPPED skipped"
	if [ "$TEARDOWN_STEPS_FAILED" -eq 0 ] && [ "$TEARDOWN_STEPS_STOPPED" -eq 0 ] && [ "$TEARDOWN_STEPS_SKIPPED" -eq 0 ]; then
		log_success "Teardown finished in $duration ($counts)"
	else
		log_info "Teardown finished in $duration ($counts)"
	fi
	case "$TEARDOWN_OUTCOME" in
		passed) outcome='tests passed' ;;
		tests-failed) outcome='tests failed' ;;
		cutoff) outcome='tests cut off by the time budget' ;;
		hung-test) outcome='tests stopped because one test did not finish' ;;
		setup-timeout) outcome='setup failed at a time limit' ;;
		*) outcome='outcome unknown' ;;
	esac
	exit_code=$(read_exit_code) || exit_code=unknown
	warnings="$TEARDOWN_WARNINGS warnings"
	[ "$TEARDOWN_WARNINGS" -ne 1 ] || warnings='1 warning'
	log_summary "Summary: $outcome, $warnings, exit code $exit_code"
	setup=$(read_duration setup) || setup=unknown
	tests=$(read_duration tests) || tests=unknown
	[ "$setup" = unknown ] || setup=$(format_duration "$setup")
	if [ "$TEARDOWN_OUTCOME" = setup-timeout ]; then
		setup="stopped after $setup"
		tests='not started'
	elif [ "$tests" != unknown ]; then
		tests=$(format_duration "$tests")
	fi
	printf '   Setup %s · tests %s · teardown %s\n' "$setup" "$tests" "$duration"
}

device_reachable() {
	teardown_step 'Check that the device answers over SSH' 10 ssh -o ConnectTimeout=10 root@"$TARGET_LAN_IP" exit
	if [ "$RUN_STEP_STATUS" -eq 0 ]; then
		return 0
	fi
	log_warn "The device does not answer over SSH. Device logs and debug information are skipped."
	return 1
}

# script and after_script share job-specific state outside all artifact paths.
# Resolve lazily so sourcing the helpers also works outside GitLab jobs.
job_state_dir() {
	[ -n "${CI_PROJECT_DIR:-}" ] && [[ "${CI_JOB_ID:-}" =~ ^[0-9]+$ ]] || return 1
	printf '%s/.ci-job-state/%s\n' "$CI_PROJECT_DIR" "$CI_JOB_ID"
}

write_outcome() {
	local directory
	case "${1:-}" in
		passed|tests-failed|cutoff|hung-test|setup-timeout) ;;
		*) return 1 ;;
	esac
	directory=$(job_state_dir) || return 1
	mkdir -p "$directory" || return 1
	printf '%s\n' "$1" > "$directory/outcome"
	rm -f "$directory/exit-code"
	if [[ "${2:-}" =~ ^[0-9]+$ ]]; then
		printf '%s\n' "$2" > "$directory/exit-code"
	fi
}

read_outcome() {
	local directory outcome
	directory=$(job_state_dir) || return 1
	if [ -r "$directory/outcome" ] && IFS= read -r outcome < "$directory/outcome"; then
		case "$outcome" in
			passed|tests-failed|cutoff|hung-test|setup-timeout) printf '%s\n' "$outcome"; return 0 ;;
		esac
	fi
	printf 'unknown\n'
}

# The outcome alone identifies intentional stops and success. Other failures
# retain their actual script exit code rather than guessing from job status.
read_exit_code() {
	local directory code outcome
	outcome=$(read_outcome) || outcome=unknown
	case "$outcome" in
		passed) printf '0\n'; return ;;
		cutoff|hung-test|setup-timeout) printf '86\n'; return ;;
		unknown) printf 'unknown\n'; return ;;
	esac
	directory=$(job_state_dir) || return 1
	if [ -r "$directory/exit-code" ] && IFS= read -r code < "$directory/exit-code" &&
		[[ "$code" =~ ^[0-9]+$ ]] && [ "$code" -le 255 ]; then
		printf '%s\n' "$code"
	else
		printf 'unknown\n'
	fi
}

# write_duration <phase name> <seconds>; read_duration <phase name>.
# Store seconds so later summaries can format or combine measured durations.
write_duration() {
	local directory
	[[ "${1:-}" =~ ^[a-z][a-z0-9-]*$ && "${2:-}" =~ ^[0-9]+$ ]] || return 1
	directory=$(job_state_dir) || return 1
	mkdir -p "$directory" || return 1
	printf '%s\n' "$((10#$2))" > "$directory/duration-$1"
}

read_duration() {
	local directory duration
	[[ "${1:-}" =~ ^[a-z][a-z0-9-]*$ ]] || return 1
	directory=$(job_state_dir) || return 1
	if [ -r "$directory/duration-$1" ] && IFS= read -r duration < "$directory/duration-$1" &&
		[[ "$duration" =~ ^[0-9]+$ ]]; then
		printf '%s\n' "$duration"
	else
		printf 'unknown\n'
	fi
}
