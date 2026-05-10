#!/bin/bash

source .gitlab/scripts/helpers.sh

set -eu
set -o pipefail

DEFAULT_TEST_APP_UUID="e6626035-71c6-594d-bcfb-a4ecca69514e"
DEFAULT_TEST_APP_ENDPOINT_ID="proto::test-uds"
DEFAULT_REQUIRED_ROLES="Full Access"
DEFAULT_EXEC_ENV="generic"
DEFAULT_INSTALL_TIMEOUT="180"

duid=""
eu_status=""

handle_error() {
	local exit_code=$1
	local line_no=$2
	local bash_lineno=$3
	local last_command=$4

	log_error "Error occurred in script at line: $line_no / $bash_lineno"
	log_error "Command that failed: $last_command"
	log_error "Exit code: $exit_code"

	dump_usp_services_state || true
	exit "$exit_code"
}

fail() {
	log_error "$*"
	exit 1
}

require_env() {
	local name="$1"

	if [ -z "${!name:-}" ]; then
		fail "$name must be set"
	fi
}

validate_no_double_quote() {
	local name="$1"
	local value="$2"

	case "$value" in
	*\"*)
		fail "$name must not contain double quotes"
		;;
	esac
}

validate_uuid() {
	local name="$1"
	local value="$2"

	case "$value" in
	????????-????-????-????-????????????)
		case "$value" in
		*[!0-9a-fA-F-]*)
			fail "$name must be a UUID"
			;;
		esac
		;;
	*)
		fail "$name must be a UUID"
		;;
	esac
}

validate_timeout() {
	local value="$1"

	case "$value" in
	"" | *[!0-9]*)
		fail "CDROUTER_USP_SERVICES_INSTALL_TIMEOUT must be a positive integer"
		;;
	0)
		fail "CDROUTER_USP_SERVICES_INSTALL_TIMEOUT must be greater than zero"
		;;
	esac
}

shell_quote() {
	printf "'"
	printf "%s" "$1" | sed "s/'/'\\\\''/g"
	printf "'"
}

ssh_dut_shell() {
	local command="$1"

	ssh -o BatchMode=yes -o StrictHostKeyChecking=no "root@$TARGET_LAN_IP" "$command"
}

ssh_dut_cmd() {
	local command=""
	local arg

	for arg in "$@"; do
		command="${command:+$command }$(shell_quote "$arg")"
	done

	ssh_dut_shell "$command"
}

ba_cli_json() {
	local expression="$1"

	ssh_dut_cmd ba-cli -l -j "$expression"
}

ba_cli_json_filter() {
	local expression="$1"
	local filter="$2"

	ssh_dut_shell "ba-cli -l -j $(shell_quote "$expression") | jsonfilter -e $(shell_quote "$filter")"
}

obuspa_get() {
	ssh_dut_cmd obuspa -c get "$1"
}

obuspa_value() {
	local path="$1"

	obuspa_get "$path" 2>/dev/null |
		awk -F' => ' -v path="$path" '$1 == path { print $2; exit }'
}

dump_usp_services_state() {
	if [ -z "${TARGET_LAN_IP:-}" ]; then
		return 0
	fi

	log_info "Dumping USP Services installer state"
	ba_cli_json "SoftwareModules.?" || true
	ba_cli_json "SoftwareModules.ExecEnv.?" || true
	ba_cli_json "SoftwareModules.DeploymentUnit.?" || true
	ba_cli_json "SoftwareModules.ExecutionUnit.?" || true
	obuspa_get "Device.UnixDomainSockets." || true
	obuspa_get "Device.LocalAgent.MTP." || true
	obuspa_get "Device.TestUDS." || true
	ssh_dut_shell "logread | grep -Ei 'cthulhu|rlyeh|timingila|obuspa|testuds|test-uds|SoftwareModules|usp' | tail -n 200" || true
	ssh_dut_shell "ps | grep -Ei 'cthulhu|rlyeh|timingila|obuspa|test' | grep -v grep" || true
}

board_arch_from_name() {
	local board_name="$1"

	case "$board_name" in
	wnc-freedom | freedom | prpl-haze | haze | arcadyan-mozart | mozart)
		echo "cortexa53"
		;;
	mxl25641-hdk-6 | urx851-b0-dk | urx851-b0-dk-pon | lgm | qemu-standard-pc-*)
		echo "x86-64"
		;;
	turris-omnia)
		echo "cortexa9"
		;;
	*)
		return 1
		;;
	esac
}

resolve_board_arch() {
	local board_name="${DUT_BOARD:-}"
	local board_arch=""

	if [ -n "$board_name" ]; then
		board_arch="$(board_arch_from_name "$board_name" || true)"
		if [ -n "$board_arch" ]; then
			echo "$board_arch"
			return 0
		fi
	fi

	board_name="$(ssh_dut_shell "cut -d, -f2 </tmp/sysinfo/board_name 2>/dev/null || true" |
		tr -d '\r\n' ||
		true)"
	board_arch="$(board_arch_from_name "$board_name" || true)"
	if [ -n "$board_arch" ]; then
		echo "$board_arch"
		return 0
	fi

	return 1
}

expand_url_tokens() {
	local board_arch

	test_app_url="$1"
	case "$test_app_url" in
	*%BOARD_ARCH%*)
		board_arch="$(resolve_board_arch)" ||
			return 1
		log_info "Expanded %BOARD_ARCH% to $board_arch"
		test_app_url="${test_app_url//%BOARD_ARCH%/$board_arch}"
		;;
	esac
}

seconds_remaining() {
	local now

	now="$(date +%s)"
	echo $((deadline - now))
}

wait_for_condition() {
	local description="$1"
	shift
	local remaining

	log_info "Waiting for $description"
	while true; do
		if "$@"; then
			log_success "$description is ready"
			return 0
		fi

		remaining="$(seconds_remaining)"
		if [ "$remaining" -le 0 ]; then
			log_error "Timeout waiting for $description"
			return 1
		fi

		log_info "Waiting for $description (${remaining}s remaining)"
		sleep 5
	done
}

authenticated_controller_socket_ready() {
	local auth_required
	local registration_restricted

	auth_required="$(obuspa_value "Device.UnixDomainSockets.UnixDomainSocket.3.AuthRequired" || true)"
	registration_restricted="$(obuspa_value "Device.UnixDomainSockets.UnixDomainSocket.3.RegistrationRestricted" || true)"

	[ "$auth_required" = "true" ] && [ "$registration_restricted" = "true" ]
}

authenticated_agent_socket_ready() {
	local auth_required
	local registration_restricted

	auth_required="$(obuspa_value "Device.UnixDomainSockets.UnixDomainSocket.4.AuthRequired" || true)"
	registration_restricted="$(obuspa_value "Device.UnixDomainSockets.UnixDomainSocket.4.RegistrationRestricted" || true)"

	[ "$auth_required" = "true" ] && [ "$registration_restricted" = "true" ]
}

deployment_unit_present() {
	duid="$(
		ba_cli_json_filter \
			"SoftwareModules.DeploymentUnit.[ UUID == \"$test_app_uuid\" ].DUID?" \
			'@[*].*.DUID' 2>/dev/null |
			tr -d '\r' |
			sed -n '1p' ||
			true
	)"

	[ -n "$duid" ]
}

execution_unit_active() {
	if [ -z "$duid" ]; then
		return 1
	fi

	eu_status="$(
		ba_cli_json_filter \
			"SoftwareModules.ExecutionUnit.[ EUID == \"$duid\" ].Status?" \
			'@[*].*.Status' 2>/dev/null |
			tr -d '\r' |
			sed -n '1p' ||
			true
	)"

	[ "$eu_status" = "Active" ]
}

test_uds_model_present() {
	obuspa_get "Device.TestUDS." >/dev/null 2>&1
}

restart_cthulhu_after_obuspa_reset() {
	log_info "Restarting cthulhu after the OBUSPA reset"
	ssh_dut_cmd /etc/init.d/cthulhu restart
	sleep 10
}

configure_exec_env_roles() {
	log_info "Configuring $exec_env execution environment roles"
	ba_cli_json \
		"SoftwareModules.ExecEnv.[ Name == \"$exec_env\" ].ModifyAvailableRoles(AvailableRoles = \"$required_roles\", AvailableUserRoles = \"\")"
}

install_test_app() {
	log_info "Installing USP Services test application"
	ba_cli_json \
		"SoftwareModules.InstallDU(URL = \"$test_app_url\", UUID = $test_app_uuid, ExecutionEnvRef = \"$exec_env\", AutoStart = true, RequiredRoles = \"$required_roles\", Privileged = false, NumRequiredUIDs = 10, EnvVariable = [{Key=\"USP_ENDPOINT_ID\", Value=\"$test_app_endpoint_id\"}])"
}

main() {
	require_env TARGET_LAN_IP
	require_env CDROUTER_USP_SERVICES_TEST_APP_URL

	test_app_uuid="${CDROUTER_USP_SERVICES_TEST_APP_UUID:-$DEFAULT_TEST_APP_UUID}"
	test_app_endpoint_id="${CDROUTER_USP_SERVICES_TEST_APP_ENDPOINT_ID:-${CDROUTER_CONFIG_USP_SERVICES_TEST_APP_ENDPOINT_ID:-$DEFAULT_TEST_APP_ENDPOINT_ID}}"
	required_roles="${CDROUTER_USP_SERVICES_REQUIRED_ROLES:-$DEFAULT_REQUIRED_ROLES}"
	exec_env="${CDROUTER_USP_SERVICES_EXEC_ENV:-$DEFAULT_EXEC_ENV}"
	install_timeout="${CDROUTER_USP_SERVICES_INSTALL_TIMEOUT:-$DEFAULT_INSTALL_TIMEOUT}"

	validate_uuid CDROUTER_USP_SERVICES_TEST_APP_UUID "$test_app_uuid"
	validate_timeout "$install_timeout"
	validate_no_double_quote CDROUTER_USP_SERVICES_TEST_APP_URL "$CDROUTER_USP_SERVICES_TEST_APP_URL"
	validate_no_double_quote CDROUTER_USP_SERVICES_TEST_APP_ENDPOINT_ID "$test_app_endpoint_id"
	validate_no_double_quote CDROUTER_USP_SERVICES_REQUIRED_ROLES "$required_roles"
	validate_no_double_quote CDROUTER_USP_SERVICES_EXEC_ENV "$exec_env"

	expand_url_tokens "$CDROUTER_USP_SERVICES_TEST_APP_URL" ||
		fail "Unable to expand %BOARD_ARCH% in CDROUTER_USP_SERVICES_TEST_APP_URL"
	validate_no_double_quote CDROUTER_USP_SERVICES_TEST_APP_URL "$test_app_url"

	deadline=$(($(date +%s) + install_timeout))

	wait_for_condition "authenticated controller UDS socket" authenticated_controller_socket_ready
	wait_for_condition "authenticated agent UDS socket" authenticated_agent_socket_ready
	restart_cthulhu_after_obuspa_reset
	configure_exec_env_roles
	install_test_app
	wait_for_condition "USP Services DeploymentUnit" deployment_unit_present
	wait_for_condition "USP Services ExecutionUnit" execution_unit_active
	wait_for_condition "Device.TestUDS data model" test_uds_model_present

	log_success "USP Services test application is installed and active"
}

trap 'handle_error $? $LINENO $BASH_LINENO "$BASH_COMMAND"' ERR

main "$@"
