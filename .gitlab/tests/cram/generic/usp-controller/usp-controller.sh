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

# The controller host and port, from USP_CONTROLLER_URL. The URL must give
# the port.
_usp_url_host=${USP_CONTROLLER_URL#*://}
_usp_url_host=${_usp_url_host%%/*}
case ${_usp_url_host} in
*:*) _usp_url_port=${_usp_url_host##*:} ;;
*) _usp_url_port= ;;
esac
_usp_url_host=${_usp_url_host%:*}
case ${_usp_url_port} in
''|*[!0-9]*)
	echo "usp-controller: USP_CONTROLLER_URL has no port: ${USP_CONTROLLER_URL}"
	exit 1
	;;
esac

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

# usp_clean_slate: remove the rows that the onboarding created on the DUT,
# for every controller, so that a test can onboard exactly the transports it
# needs. It prints nothing on success and one line on failure.
usp_clean_slate() {
	if ! _usp_output=$(testbed-qemu usp cleanup --all 2>&1); then
		echo "usp-controller: cleanup failed: $(printf '%s\n' "${_usp_output}" | tail -n 1)"
		return 1
	fi
}

# usp_agent_wait: wait, at most 60 s, until the DUT agent is ready. The agent
# is ready when it answers a local Get of Device.DeviceInfo.SoftwareVersion
# and the number of USP services registered with it stays the same for 3 s.
# The services register again one by one after an agent start, and the
# DeviceInfo service is not the last one. A probe counts only when both Gets
# succeed and give values, so a probe that finds no USP service fails. A
# failed probe starts the 3 s again. The 60 s include the SSH connections to
# the DUT. It prints nothing when the agent is ready and one line otherwise.
usp_agent_wait() {
	_usp_end=$(($(date +%s%3N) + 60000))
	_usp_last=
	_usp_same=0
	while _usp_left=$(((_usp_end - $(date +%s%3N)) / 1000)); [ "${_usp_left}" -gt 0 ]; do
		if _usp_count=$(timeout "${_usp_left}" ${CRAM_REMOTE_COMMAND} \
			'v=$(obuspa -c get Device.DeviceInfo.SoftwareVersion) || exit 1
			case $v in *" => "*) ;; *) exit 1 ;; esac
			v=$(obuspa -c get "Device.USPServices.USPService.*.EndpointID") || exit 1
			n=$(printf "%s\n" "$v" | grep -c " => ")
			[ "$n" -gt 0 ] || exit 1
			echo "$n"' \
			2>/dev/null); then
			if [ "${_usp_count}" = "${_usp_last}" ]; then
				_usp_same=$((_usp_same + 1))
				[ "${_usp_same}" -ge 3 ] && return 0
			else
				_usp_same=0
			fi
			_usp_last=${_usp_count}
		else
			_usp_last=
			_usp_same=0
		fi
		[ $((_usp_end - $(date +%s%3N))) -gt 1000 ] || break
		sleep 1
	done
	echo "usp-controller: the DUT agent is not ready after 60 s"
	return 1
}

# usp_agent_restart: restart the DUT agent and wait until it answers. It
# prints nothing on success and one line on failure.
usp_agent_restart() {
	if ! _usp_output=$(${CRAM_REMOTE_COMMAND} /etc/init.d/obuspa restart 2>&1); then
		echo "usp-controller: agent restart failed: $(printf '%s\n' "${_usp_output}" | tail -n 1)"
		return 1
	fi
	usp_agent_wait
}

# usp_dut_value PATH: print the values that the DUT agent gives for PATH,
# read locally on the DUT. PATH must not contain a single quote. The command
# line of the agent exits 0 also when the Get fails, and then prints an error
# line or nothing. So when the read fails, prints a line that is not a value,
# or gives no value, it prints one line on standard error and returns 1.
usp_dut_value() {
	if ! _usp_value=$(${CRAM_REMOTE_COMMAND} "obuspa -c get '$1'" 2>/dev/null) ||
		[ -z "${_usp_value}" ] || printf '%s\n' "${_usp_value}" | grep -qv ' => '; then
		echo "usp-controller: cannot read $1 on the DUT${_usp_value:+: $(printf '%s\n' "${_usp_value}" | tail -n 1)}" >&2
		return 1
	fi
	printf '%s\n' "${_usp_value}" | sed 's/^[^ ]* => //'
}

# _usp_tcp: print "TRANSPORT BYTES" for each TCP connection that the DUT
# holds to the controller. TRANSPORT is the transport that the controller
# reports for the connection, or "unknown PEER". BYTES is the number of bytes
# that the controller received on it.
_usp_tcp() {
	_usp_sources=$(testbed-qemu usp agents --json | python3 -c 'import json, sys
for agent in json.load(sys.stdin):
    for transport in agent.get("transports") or ():
        if transport.get("connected") and transport.get("connection_source"):
            print(transport["connection_source"], transport["transport_type"])') || return 1
	ss -Htni state established "( sport = :${_usp_url_port} )" | awk \
		-v self="${_usp_url_host}:" -v sources="${_usp_sources}" '
		BEGIN {
			n = split(sources, line, "\n")
			for (i = 1; i <= n; i++) {
				split(line[i], field, " ")
				transport[field[1]] = field[2]
			}
		}
		/^[^ \t]/ {
			peer = (index($4, self) == 1) ? "" : $4
			next
		}
		peer != "" {
			bytes = 0
			if (match($0, /bytes_received:[0-9]+/))
				bytes = substr($0, RSTART + 15, RLENGTH - 15)
			print ((peer in transport) ? transport[peer] : "unknown " peer), bytes
			peer = ""
		}'
}

# usp_connections: print the transport of each TCP connection that the DUT
# holds to the controller, one per line, sorted.
usp_connections() {
	_usp_tcp | sed 's/ [0-9]*$//' | sort
}

# usp_received TRANSPORT: print the number of bytes that the controller
# received on the connection of TRANSPORT.
usp_received() {
	_usp_tcp | sed -n "s/^$1 \([0-9]*\)$/\1/p"
}

# usp_now: print the current Unix time with fractions of a second. The
# controller runs on the same host and records the time it receives each
# notification from the same clock.
usp_now() {
	date +%s.%N
}

# usp_notify_wait SINCE ID SECONDS: wait at most SECONDS until the controller
# has received a notification for the subscription ID since the Unix time
# SINCE, then print every such notification, one per line, as
# `testbed-qemu usp notifications` prints it. The controller also keeps the
# notifications of its own subscriptions, so only the lines of ID count. Only
# a read that the client completes with success counts. Every read gives all
# notifications since SINCE, so a failed read is followed by the next one. It
# prints one line when no notification arrives in time, and another line when
# the last read failed, because then nothing shows that none arrived.
usp_notify_wait() {
	_usp_end=$(($(date +%s) + $3))
	while :; do
		if _usp_output=$(testbed-qemu usp notifications --since "$1" 2>&1); then
			_usp_read=
			_usp_lines=$(printf '%s\n' "${_usp_output}" | awk -v id="$2" '$2 == id')
			if [ -n "${_usp_lines}" ]; then
				printf '%s\n' "${_usp_lines}"
				return 0
			fi
		else
			_usp_read="exit $?${_usp_output:+: $(printf '%s\n' "${_usp_output}" | tail -n 1)}"
		fi
		[ "$(date +%s)" -lt "${_usp_end}" ] || break
		sleep 0.5
	done
	if [ -n "${_usp_read}" ]; then
		echo "usp-controller: cannot read the notifications from the controller (${_usp_read})"
		return 1
	fi
	echo "usp-controller: no notification for subscription $2 within $3 s"
	return 1
}

case ${TESTFILE:-} in
000-preflight.t)
	rm -f "${USP_PREFLIGHT_RESULT}"
	;;
[0-9][0-9][0-9]-mtp-*.t)
	# A test for one MTP removes the rows of every controller and onboards
	# its own transport, so it does not need the MQTT client.
	usp_controller_check
	;;
*)
	usp_controller_check
	usp_mqtt_client_check
	;;
esac
