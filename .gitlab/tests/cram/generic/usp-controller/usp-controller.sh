# SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation
#
# Shared setup for the USP controller tests. Every test in this directory
# sources it first:
#
#   $ . "${TESTDIR}/usp-controller.sh"
#
# Without a controller (USP_CONTROLLER_URL unset) the test does not apply and
# exits 80, which cram reports as skipped. With a controller, nothing skips.
#
# 000-preflight.t checks the controller path and records its result for this
# testbed run and this DUT boot. Every other test fails at once, with one
# line that names the cause, when that result is missing, is a failure, or
# comes from an earlier DUT boot, or when the DUT has no MQTT client for the
# controller. Nothing here provisions the DUT again.

[ -n "${USP_CONTROLLER_URL:-}" ] || exit 80

if [ -z "${TESTBED_QEMU_ARTIFACT_ROOT:-}" ] || [ -z "${TESTBED_QEMU_SCRATCH:-}" ]; then
	echo "usp-controller: TESTBED_QEMU_ARTIFACT_ROOT and TESTBED_QEMU_SCRATCH must be set"
	exit 1
fi

USP_PREFLIGHT_RESULT="${TESTBED_QEMU_ARTIFACT_ROOT}/usp-controller-preflight.txt"
# The testbed creates a new workspace for each run, so its path is the run ID.
USP_RUN_ID="${TESTBED_QEMU_SCRATCH}"

usp_boot_id() {
	${CRAM_REMOTE_COMMAND} cat /proc/sys/kernel/random/boot_id 2>/dev/null
}

# usp_preflight_write RESULT: replace the result file atomically.
usp_preflight_write() {
	_usp_tmp=$(mktemp "${USP_PREFLIGHT_RESULT}.XXXXXX") || exit 1
	printf 'run_id=%s\nboot_id=%s\nresult=%s\n' \
		"${USP_RUN_ID}" "$(usp_boot_id)" "$1" > "${_usp_tmp}" || exit 1
	mv -f "${_usp_tmp}" "${USP_PREFLIGHT_RESULT}" || exit 1
}

usp_preflight_pass() {
	usp_preflight_write pass
}

# usp_preflight_fail REASON: record the failure, print it on one line and
# stop the test.
usp_preflight_fail() {
	_usp_reason=$(printf '%s' "$1" | tr '\n' ' ')
	usp_preflight_write "fail ${_usp_reason}"
	echo "usp-controller: pre-flight failed: ${_usp_reason}"
	exit 1
}

# usp_preflight_check REASON COMMAND [ARG...]: run COMMAND without output.
# When it fails, fail the pre-flight with REASON and the last line COMMAND
# printed.
usp_preflight_check() {
	_usp_reason=$1
	shift
	if ! _usp_output=$("$@" 2>&1); then
		_usp_last=$(printf '%s\n' "${_usp_output}" | tail -n 1)
		usp_preflight_fail "${_usp_reason}${_usp_last:+: ${_usp_last}}"
	fi
}

usp_result_field() {
	sed -n "s/^$1=//p" "${USP_PREFLIGHT_RESULT}"
}

# usp_controller_id: print the EndpointID of the controller.
usp_controller_id() {
	testbed-qemu usp health --json | python3 -c 'import json, sys; print(json.load(sys.stdin)["controller_id"])'
}

# usp_mqtt_client_check: fail the test with one line when the DUT has no MQTT
# client for the controller. The tests reach the agent over the MQTT client
# that the onboarding created. The check only reads from the DUT. The client
# is gone only when the read succeeds and finds no client; a failed read has
# its own line.
usp_mqtt_client_check() {
	_usp_ctl=$(usp_controller_id 2>/dev/null)
	if [ -z "${_usp_ctl}" ]; then
		echo "usp-controller: cannot read the controller EndpointID"
		exit 1
	fi
	if ! _usp_output=$(${CRAM_REMOTE_COMMAND} "obuspa -c get 'Device.MQTT.Client.[Alias==\"${_usp_ctl}-mqtt-client\"].Alias'" 2>/dev/null); then
		echo "usp-controller: cannot read the MQTT clients of the DUT"
		exit 1
	fi
	case ${_usp_output} in
	*"ERROR: "*)
		echo "usp-controller: cannot read the MQTT clients of the DUT: $(printf '%s\n' "${_usp_output}" | tail -n 1)"
		exit 1
		;;
	*" => "*) ;;
	*)
		echo "usp-controller: MQTT client of controller ${_usp_ctl} is gone from the DUT"
		exit 1
		;;
	esac
}

usp_controller_check() {
	if [ ! -f "${USP_PREFLIGHT_RESULT}" ] || [ "$(usp_result_field run_id)" != "${USP_RUN_ID}" ]; then
		echo "usp-controller: pre-flight result missing for this run"
		exit 1
	fi
	_usp_result=$(usp_result_field result)
	if [ "${_usp_result}" != pass ]; then
		echo "usp-controller: pre-flight failed: ${_usp_result#fail }"
		exit 1
	fi
	_usp_boot=$(usp_boot_id)
	if [ -z "${_usp_boot}" ]; then
		echo "usp-controller: cannot read the DUT boot ID"
		exit 1
	fi
	if [ "${_usp_boot}" != "$(usp_result_field boot_id)" ]; then
		echo "usp-controller: pre-flight result stale: DUT rebooted since the pre-flight"
		exit 1
	fi
}

if [ "${TESTFILE:-}" = 000-preflight.t ]; then
	rm -f "${USP_PREFLIGHT_RESULT}"
else
	usp_controller_check
	usp_mqtt_client_check
fi
