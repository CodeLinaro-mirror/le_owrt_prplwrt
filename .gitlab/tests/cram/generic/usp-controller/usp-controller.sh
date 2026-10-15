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

# usp_mqtt_wait TLS: wait at most 30 s until the controller sees the agent
# connected over MQTT with tls=TLS (true or false), then print that line of
# `testbed-qemu usp agents` without its enabled field. A new onboarding over
# MQTT returns as soon as the controller lists the agent as connected over
# MQTT, and that can still be the connection from before the change. It prints
# one line when the time runs out.
usp_mqtt_wait() {
	_usp_end=$(($(date +%s) + 30))
	while :; do
		_usp_line=$(testbed-qemu usp agents 2>/dev/null | grep ' mqtt ' | sed 's/ enabled=[a-z]*//')
		case ${_usp_line} in
		*" connected=true tls=$1")
			printf '%s\n' "${_usp_line}"
			return 0
			;;
		esac
		[ "$(date +%s)" -lt "${_usp_end}" ] || break
		sleep 0.5
	done
	echo "usp-controller: agent not connected over MQTT with tls=$1 within 30 s: ${_usp_line}"
	return 1
}

# usp_mqtt_switch TLS: switch the MQTT client of this controller to MQTT
# with TLS (TLS=true) or without TLS (TLS=false), and wait until the
# controller sees the agent connected that way. It runs the onboarding over
# MQTT again with the new setting. It prints the line of usp_mqtt_wait on
# success and one line on failure.
usp_mqtt_switch() {
	case $1 in
	true) _usp_tls=--tls ;;
	*) _usp_tls=--no-tls ;;
	esac
	testbed-qemu usp onboard mqtt "${_usp_tls}" >/dev/null || return 1
	usp_mqtt_wait "$1"
}

# usp_acl_rows_add: add the two port mappings that the access control tests
# use, both disabled: usp-acl-a and usp-acl-b. Rows that an interrupted
# earlier run left are deleted first. It sets usp_acl_a and usp_acl_b to the
# object instance paths of the rows, and usp_acl_ctl to the controller row of
# this controller. It prints nothing on success and one line on failure.
usp_acl_rows_add() {
	usp_acl_rows_del
	for _usp_row in a:50541 b:50542; do
		if ! testbed-qemu usp add Device.NAT.PortMapping. "Alias=usp-acl-${_usp_row%:*}" \
			"ExternalPort=${_usp_row#*:}" "Description=usp-acl-${_usp_row%:*}0" Enable=false >/dev/null; then
			echo "usp-controller: cannot add the port mapping usp-acl-${_usp_row%:*}"
			return 1
		fi
	done
	usp_acl_a=$(testbed-qemu usp get 'Device.NAT.PortMapping.[Alias=="usp-acl-a"].Alias' | sed -n 's/Alias=.*$//p')
	usp_acl_b=$(testbed-qemu usp get 'Device.NAT.PortMapping.[Alias=="usp-acl-b"].Alias' | sed -n 's/Alias=.*$//p')
	usp_acl_ctl=$(testbed-qemu usp get "Device.LocalAgent.Controller.[EndpointID==\"$(usp_controller_id)\"].EndpointID" | sed -n 's/EndpointID=.*$//p')
	if [ -z "${usp_acl_a}" ] || [ -z "${usp_acl_b}" ] || [ -z "${usp_acl_ctl}" ]; then
		echo "usp-controller: cannot read the paths of the access control rows"
		return 1
	fi
}

# usp_acl_rows_del: delete the port mappings of usp_acl_rows_add, one at a
# time, so that a missing row does not keep the other one. A delete of a row
# that is not there can fail, so the result of each delete does not count;
# a Get must then succeed and find neither row. It prints nothing on success
# and one line otherwise.
usp_acl_rows_del() {
	for _usp_row in a b; do
		testbed-qemu usp delete "Device.NAT.PortMapping.[Alias==\"usp-acl-${_usp_row}\"]." >/dev/null 2>&1
	done
	_usp_absent 'Device.NAT.PortMapping.[Alias=="usp-acl-a"].Alias' 'Device.NAT.PortMapping.[Alias=="usp-acl-b"].Alias'
}

# _usp_absent PATH...: check with a Get over the controller that no PATH
# matches. It prints nothing when the Get succeeds and gives nothing, and one
# line otherwise.
_usp_absent() {
	if ! _usp_output=$(testbed-qemu usp get "$@" 2>&1); then
		echo "usp-controller: cannot read $*: $(printf '%s\n' "${_usp_output}" | tail -n 1)"
		return 1
	fi
	if [ -n "${_usp_output}" ]; then
		echo "usp-controller: still on the DUT: $(printf '%s' "${_usp_output}" | tr '\n' ' ')"
		return 1
	fi
}

# usp_acl_limit ROLE: add three permission rows to the Role with the object
# path ROLE. Their Order values (100 to 102) are higher than the Order of the
# rows that the agent creates, so they take priority for their targets:
#   usp-acl-deny    the instance usp_acl_b: no permission at all
#   usp-acl-ro      the parameter Description of usp_acl_a: read and notify,
#                   no write
#   usp-acl-noexec  SendOnBoardRequest() of usp_acl_ctl: read, no execute
# It prints nothing on success and one line on failure.
usp_acl_limit() {
	_usp_acl_perm "$1" usp-acl-deny 100 "${usp_acl_b}" ---- ---- ---- ---- &&
	_usp_acl_perm "$1" usp-acl-ro 101 "${usp_acl_a}Description" r--n ---- ---- ---- &&
	_usp_acl_perm "$1" usp-acl-noexec 102 "${usp_acl_ctl}SendOnBoardRequest()" ---- ---- ---- r---
}

# _usp_acl_perm ROLE ALIAS ORDER TARGETS PARAM OBJ INSTANTIATEDOBJ
# COMMANDEVENT: add one enabled permission row to ROLE.
_usp_acl_perm() {
	if ! _usp_output=$(testbed-qemu usp add "$1Permission." "Alias=$2" "Order=$3" "Targets=$4" \
		"Param=$5" "Obj=$6" "InstantiatedObj=$7" "CommandEvent=$8" Enable=true 2>&1); then
		echo "usp-controller: cannot add the permission row $2: $(printf '%s\n' "${_usp_output}" | tail -n 1)"
		return 1
	fi
}

# usp_acl_unlimit ROLE: delete the permission rows of usp_acl_limit from the
# Role with the object path ROLE. The agent's command line deletes them, so
# this works whatever the rows deny and whatever the transport of the
# controller is. That command line exits 0 also when it fails, so each delete
# counts only when it prints that it deleted the row or that no row matched.
# A read of the Role must then succeed and show none of the rows: it reads
# PermissionNumberOfEntries and, when that is not 0, the Alias of each row,
# and the numbers must agree. It also keeps ROLE in usp_acl_limited for
# usp_acl_cleanup. It prints nothing on success and one line otherwise.
usp_acl_unlimit() {
	usp_acl_limited=$1
	for _usp_alias in usp-acl-deny usp-acl-ro usp-acl-noexec; do
		if ! _usp_output=$(${CRAM_REMOTE_COMMAND} "obuspa -c del '$1Permission.[Alias==\"${_usp_alias}\"].'" 2>/dev/null); then
			echo "usp-controller: cannot delete the permission row ${_usp_alias} of $1"
			return 1
		fi
		case ${_usp_output} in
		"No objects were matched for deletion") continue ;;
		"Deleted $1Permission."*[!0-9]*) ;;
		"Deleted $1Permission."[0-9]*) continue ;;
		esac
		echo "usp-controller: cannot delete the permission row ${_usp_alias} of $1: $(printf '%s\n' "${_usp_output:-no output}" | tail -n 1)"
		return 1
	done
	if ! _usp_output=$(${CRAM_REMOTE_COMMAND} "obuspa -c get '$1PermissionNumberOfEntries'" 2>/dev/null); then
		echo "usp-controller: cannot read the permission rows of $1"
		return 1
	fi
	case ${_usp_output} in
	"$1PermissionNumberOfEntries => "*) _usp_count=${_usp_output#* => } ;;
	*) _usp_count= ;;
	esac
	case ${_usp_count} in
	'' | *[!0-9]*)
		echo "usp-controller: cannot read the permission rows of $1: $(printf '%s' "${_usp_output}" | tr '\n' ' ')"
		return 1
		;;
	0) return 0 ;;
	esac
	if ! _usp_output=$(${CRAM_REMOTE_COMMAND} "obuspa -c get '$1Permission.*.Alias'" 2>/dev/null); then
		echo "usp-controller: cannot read the permission rows of $1"
		return 1
	fi
	_usp_rows=0
	_usp_left=
	_usp_bad=
	while IFS= read -r _usp_line; do
		case ${_usp_line} in
		"$1Permission."*".Alias => usp-acl-"*) _usp_rows=$((_usp_rows + 1)) _usp_left=1 ;;
		"$1Permission."*".Alias => "*) _usp_rows=$((_usp_rows + 1)) ;;
		*) _usp_bad=1 ;;
		esac
	done <<EOF
${_usp_output}
EOF
	if [ -n "${_usp_bad}" ] || [ "${_usp_count}" != "${_usp_rows}" ]; then
		echo "usp-controller: cannot read the permission rows of $1: $(printf '%s' "${_usp_output}" | tr '\n' ' ')"
		return 1
	fi
	if [ -n "${_usp_left}" ]; then
		echo "usp-controller: permission rows of the access control tests are left in $1"
		return 1
	fi
}

# usp_acl_ca_role: print the Role that the DUT agent gives to a controller
# whose certificate chain ends in the CA of this controller. The CA is the
# LocalAgent.Certificate row with the SHA-256 fingerprint of the CA that the
# controller publishes, and the Role is the one of the
# ControllerTrust.Credential row that refers to that certificate. It prints one
# line that starts with "usp-controller:" when there is no such row.
usp_acl_ca_role() {
	_usp_fp=$(curl -fsS "${USP_CONTROLLER_URL%/}/api/v1/mux/ca.pem" | python3 -c '
import hashlib, ssl, sys
print(hashlib.sha256(ssl.PEM_cert_to_DER_cert(sys.stdin.read())).hexdigest().upper())') || {
		echo "usp-controller: cannot read the CA of the controller"
		return 1
	}
	for _usp_cert in $(testbed-qemu usp instances Device.LocalAgent.Certificate. | grep '\.$'); do
		if [ "$(testbed-qemu usp operate "${_usp_cert}GetFingerprint()" FingerprintAlgorithm=SHA-256 |
			sed -n 's/^.*\.Fingerprint="\(.*\)"$/\1/p')" = "${_usp_fp}" ]; then
			testbed-qemu usp get "Device.LocalAgent.ControllerTrust.Credential.[Credential==\"${_usp_cert%.}\"].Role" |
				sed -n 's/^[^=]*="\(..*\)"$/\1/p' | grep . && return 0
			break
		fi
	done
	echo "usp-controller: no Credential row gives a Role to the CA of the controller"
	return 1
}

# usp_acl_trap [SUBSCRIPTION_ID...]: run usp_acl_cleanup when the test shell
# exits: at the end of the test file, and also when a signal stops the test
# early. An access control test calls it before its first change on the DUT.
# Each SUBSCRIPTION_ID is the ID of a subscription that the test adds.
usp_acl_trap() {
	usp_acl_subscriptions="$*"
	trap usp_acl_cleanup EXIT
	trap 'exit 129' HUP
	trap 'exit 130' INT
	trap 'exit 143' TERM
}

# usp_acl_cleanup: undo what an access control test changed on the DUT,
# also after a partial change. When the test ends normally, it has undone
# everything already, and this finds nothing to do. Each step runs whatever
# the earlier steps gave:
#   - delete the permission rows of usp_acl_limit from the Role in
#     usp_acl_limited (set by usp_acl_unlimit)
#   - switch the MQTT client back to MQTT without TLS, unless the controller
#     already lists the agent connected that way
#   - delete the subscriptions of usp_acl_trap
#   - put back the AssignedRole of the controller row usp_acl_ctl that
#     usp_acl_assigned holds, when the test set usp_acl_assigned
#   - delete the Role usp-acl-limited
#   - delete the port mappings of usp_acl_rows_add
# A Get must then succeed and find none of the subscriptions and not the
# Role. It prints nothing when every step succeeds and one line otherwise.
# It does not change the exit status of the test.
usp_acl_cleanup() {
	_usp_errors=
	if [ -n "${usp_acl_limited:-}" ]; then
		_usp_output=$(usp_acl_unlimit "${usp_acl_limited}" 2>&1) || _usp_acl_error "${_usp_output}"
	fi
	_usp_output=$(testbed-qemu usp agents 2>/dev/null) || _usp_output=
	case ${_usp_output} in
	*" mqtt enabled=true connected=true tls=false"*) ;;
	*) _usp_output=$(usp_mqtt_switch false 2>&1) || _usp_acl_error "${_usp_output}" ;;
	esac
	set -- 'Device.LocalAgent.ControllerTrust.Role.[Alias=="usp-acl-limited"].Alias'
	for _usp_id in ${usp_acl_subscriptions:-}; do
		testbed-qemu usp delete "Device.LocalAgent.Subscription.[ID==\"${_usp_id}\"]." >/dev/null 2>&1
		set -- "$@" "Device.LocalAgent.Subscription.[ID==\"${_usp_id}\"].ID"
	done
	if [ -n "${usp_acl_assigned+set}" ] && [ -n "${usp_acl_ctl:-}" ]; then
		testbed-qemu usp set "${usp_acl_ctl}AssignedRole=${usp_acl_assigned}" >/dev/null 2>&1
		if ! _usp_output=$(usp_dut_value "${usp_acl_ctl}AssignedRole" 2>&1); then
			_usp_acl_error "${_usp_output}"
		elif [ "${_usp_output}" != "${usp_acl_assigned}" ]; then
			_usp_acl_error "AssignedRole of ${usp_acl_ctl} is '${_usp_output}', expected '${usp_acl_assigned}'"
		fi
	fi
	testbed-qemu usp delete 'Device.LocalAgent.ControllerTrust.Role.[Alias=="usp-acl-limited"].' >/dev/null 2>&1
	_usp_output=$(usp_acl_rows_del 2>&1) || _usp_acl_error "${_usp_output}"
	_usp_output=$(_usp_absent "$@" 2>&1) || _usp_acl_error "${_usp_output}"
	if [ -n "${_usp_errors}" ]; then
		echo "usp-controller: cleanup after the test failed: ${_usp_errors}"
	fi
}

# _usp_acl_error TEXT: add TEXT, without its "usp-controller: " prefix and on
# one line, to the errors of usp_acl_cleanup.
_usp_acl_error() {
	_usp_text=$(printf '%s\n' "$1" | sed 's/^usp-controller: //' | tr '\n' ' ' | sed 's/ *$//')
	_usp_errors="${_usp_errors:+${_usp_errors}; }${_usp_text}"
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
