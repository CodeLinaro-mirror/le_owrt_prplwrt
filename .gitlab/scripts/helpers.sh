#!/bin/bash

# after_script runs in a new shell and must source .gitlab/scripts/helpers.sh.

log_error() { echo -e "\e[91m❌ ERROR: $*\e[0m"; }
log_success() { echo -e "\e[92m✅ $*\e[0m"; }
log_info() { echo -e "\e[93m💡 $*\e[0m"; }

# section_start - Start a collapsible section in GitLab CI job logs
#
# Creates a collapsible section marker in GitLab CI logs that can be expanded
# or collapsed in the web interface.
#
# Parameters:
#   $1 - section_title: Unique identifier for the section (required)
#   $2 - section_description: Display name shown in the UI (optional, defaults to section_title)
#   $3 - collapse_state: "collapsed" or "expanded" (optional, defaults to "expanded")
#
# Usage:
#   section_start "build_logs" "Build Output"
#   section_start "test_results" "Test Results" "collapsed"
#   section_start "warnings"
#
# Note: Each section_start must have a matching section_end with the same section_title
#
section_start() {
	local section_title="${1}"
	local section_description="${2:-$section_title}"
	local collapse_state="${3:-expanded}"
	local collapsed_flag="false"

	if [ "$collapse_state" = "collapsed" ]; then
		collapsed_flag="true"
	fi

	echo -e "section_start:$(date +%s):${section_title}[collapsed=${collapsed_flag}]\r\e[0K\e[95m📦 ${section_description}\e[0m"
}

# section_end - End a collapsible section in GitLab CI job logs
#
# Closes a section that was opened with section_start. The section_title must
# match the one used in the corresponding section_start call.
#
# Parameters:
#   $1 - section_title: Unique identifier for the section (required, must match section_start)
#
# Usage:
#   section_end "build_logs"
#   section_end "test_results"
#
# Example workflow:
#   section_start "build_logs" "Build Output"
#   make build
#   section_end "build_logs"
#
section_end() {
	local section_title="${1}"

	echo -e "section_end:$(date +%s):${section_title}\r\e[0K"
}

# bounded - Run an external command with a time cap and log its duration
#
# Opens a log section, stops the command at the cap, and sends KILL after a
# further five seconds if needed. Logs the duration in seconds and exit code,
# warns on timeout, and returns the command status without changing shell options.
# Shell functions and builtins are refused with exit code 126.
# A cap that is not a positive integer skips the command with exit code 125.
#
# Parameters:
#   $1 - step: Unique name for the teardown step (required)
#   $2 - cap: Time limit in seconds (required)
#   $3... - command: External command and its arguments (required)
#
# Usage:
#   bounded report 20 ./collect-report.sh
#   bounded logs 30 ssh root@"$TARGET_LAN_IP" dmesg
#
bounded() {
	local step="${1}"
	local cap="${2}"
	local start rc
	shift 2

	section_start "teardown-${step}" "Teardown: ${step}"
	start=$(date +%s)

	if ! [[ "$cap" =~ ^0*[1-9][0-9]*$ ]]; then
		# Return 125 for a skipped step, distinct from timeout's 124/137.
		rc=125
		log_error "step ${step} skipped: cap '${cap}' must be a positive integer"
		printf 'teardown-step name=%s dur=%s rc=%s cap=%s skipped\n' "$step" "$(( $(date +%s) - start ))" "$rc" "$cap"
		section_end "teardown-${step}"
		return "$rc"
	fi

	case "$(type -t "$1")" in
		function|builtin)
			log_error "bounded requires an external command: $1"
			rc=126
			;;
		*)
			if timeout --kill-after=5 "$cap" "$@"; then
				rc=0
			else
				rc=$?
			fi
			;;
	esac

	printf 'teardown-step name=%s dur=%s rc=%s\n' "$step" "$(( $(date +%s) - start ))" "$rc"
	if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
		echo "WARNING: step ${step} exceeded ${cap} s and was stopped"
	fi
	section_end "teardown-${step}"
	return "$rc"
}

# Collection shares one wall-clock budget and leaves time for mandatory cleanup
# and artifact upload, even when after_script starts late.
TEARDOWN_COLLECTION_SECONDS=240
TEARDOWN_JOB_TAIL_SECONDS=130

teardown_init() {
	local start job_end
	start=$(date +%s)
	job_end=$(( $(date -d "$CI_JOB_STARTED_AT" +%s) + CI_JOB_TIMEOUT ))
	TEARDOWN_DEADLINE=$(( start + TEARDOWN_COLLECTION_SECONDS ))
	if [ "$(( job_end - TEARDOWN_JOB_TAIL_SECONDS ))" -lt "$TEARDOWN_DEADLINE" ]; then
		TEARDOWN_DEADLINE=$(( job_end - TEARDOWN_JOB_TAIL_SECONDS ))
	fi
	printf 'teardown-deadline start=%s job_end=%s deadline=%s\n' "$start" "$job_end" "$TEARDOWN_DEADLINE"
}

# Like bounded, but clamp the cap to the collection time still available.
# A deadline skip returns 125, without passing zero (unlimited) to timeout.
teardown_bounded() {
	local step="$1" cap="$2" left
	shift 2
	left=$(( TEARDOWN_DEADLINE - $(date +%s) ))
	if [ "$left" -le 0 ]; then
		section_start "teardown-${step}" "Teardown: ${step}"
		printf 'teardown-step name=%s dur=0 rc=125 skipped (deadline)\n' "$step"
		section_end "teardown-${step}"
		return 125
	fi
	if [ "$left" -lt "$cap" ]; then
		cap="$left"
	fi
	bounded "$step" "$cap" "$@"
}

teardown_dut_alive() {
	if teardown_bounded dut-alive 10 ssh -o ConnectTimeout=10 root@"$TARGET_LAN_IP" exit; then
		return 0
	fi
	echo "Skipping DUT logs, debug collection and scp: DUT gate failed or collection deadline reached."
	return 1
}
