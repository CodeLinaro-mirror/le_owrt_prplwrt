#!/bin/bash

source .gitlab/scripts/helpers.sh

set -eu
set -o pipefail

DEFAULT_TEST_APP_UUID="e6626035-71c6-594d-bcfb-a4ecca69514e"
DEFAULT_EXEC_ENV="generic"
DEFAULT_PREPULL_TIMEOUT="300"
DEFAULT_WAN_SETTLE_DELAY="5"

deadline=""
registry_host=""
test_app_duid=""
test_app_url=""
test_app_version=""

handle_error() {
	local exit_code=$1
	local line_no=$2
	local bash_lineno=$3
	local last_command=$4

	log_error "Error occurred in script at line: $line_no / $bash_lineno"
	log_error "Command that failed: $last_command"
	log_error "Exit code: $exit_code"

	dump_prepull_state || true
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

validate_positive_integer() {
	local name="$1"
	local value="$2"

	case "$value" in
	"" | *[!0-9]*)
		fail "$name must be a positive integer"
		;;
	0)
		fail "$name must be greater than zero"
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

docker_registry_host_from_url() {
	local url="$1"
	local registry

	case "$url" in
	docker://*/*)
		registry="${url#docker://}"
		registry="${registry%%/*}"
		echo "${registry%%:*}"
		;;
	*)
		return 1
		;;
	esac
}

docker_image_version_from_url() {
	local url="$1"
	local reference
	local last_component

	reference="${url#docker://}"
	reference="${reference#*/}"
	last_component="${reference##*/}"

	case "$last_component" in
	*:*)
		echo "${last_component##*:}"
		;;
	*)
		echo "latest"
		;;
	esac
}

generate_test_app_duid() {
	local uuid="$1"
	local exec_env="$2"

	python3 - "$uuid" "$exec_env" <<'PY'
import sys
import uuid

print(uuid.uuid5(uuid.UUID(sys.argv[1]), sys.argv[2]))
PY
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

bring_testbed_wan_up() {
	log_info "Bringing testbed WAN interface $TESTBED_WAN_INTERFACE up for USP Services pre-pull"
	sudo ip link set "$TESTBED_WAN_INTERFACE" up 2>/dev/null
	sleep "$wan_settle_delay"
}

bring_testbed_wan_down() {
	if [ -n "${TESTBED_WAN_INTERFACE:-}" ]; then
		log_info "Bringing testbed WAN interface $TESTBED_WAN_INTERFACE down after USP Services pre-pull"
		sudo ip link set "$TESTBED_WAN_INTERFACE" down 2>/dev/null || true
	fi
}

dut_has_default_route() {
	ssh_dut_shell "ip route get 1.1.1.1 >/dev/null 2>&1"
}

dut_can_resolve_registry() {
	ssh_dut_cmd nslookup "$registry_host" >/dev/null 2>&1
}

rlyeh_image_downloaded() {
	local image_status

	image_status="$(
		ba_cli_json_filter \
			"Rlyeh.Images.[ DUID == \"$test_app_duid\" && Version == \"$test_app_version\" ].Status?" \
			'@[*].*.Status' 2>/dev/null |
			tr -d '\r' |
			sed -n '1p' ||
			true
	)"

	[ "$image_status" = "Downloaded" ]
}

pull_test_app_image() {
	log_info "Pre-pulling USP Services test application image"
	ba_cli_json "Rlyeh.pull(URI = \"$test_app_url\", DUID = \"$test_app_duid\")"
}

dump_prepull_state() {
	if [ -z "${TARGET_LAN_IP:-}" ]; then
		return 0
	fi

	log_info "Dumping USP Services pre-pull state"
	if [ -n "${TESTBED_WAN_INTERFACE:-}" ]; then
		sudo ip addr show "$TESTBED_WAN_INTERFACE" || true
	fi
	ssh_dut_shell "ip addr; ip route; cat /etc/resolv.conf" || true
	if [ -n "$registry_host" ]; then
		ssh_dut_cmd nslookup "$registry_host" || true
	fi
	ba_cli_json "Rlyeh.?" || true
	ba_cli_json "Rlyeh.Images.?" || true
	ssh_dut_shell "logread | grep -Ei 'cthulhu|rlyeh|timingila|netifd|dnsmasq|udhcpc|Pull image|Curl' | tail -n 200" || true
}

main() {
	local test_app_uuid
	local exec_env
	local prepull_timeout

	require_env TARGET_LAN_IP
	require_env TESTBED_WAN_INTERFACE
	require_env CDROUTER_USP_SERVICES_TEST_APP_URL

	test_app_uuid="${CDROUTER_USP_SERVICES_TEST_APP_UUID:-$DEFAULT_TEST_APP_UUID}"
	exec_env="${CDROUTER_USP_SERVICES_EXEC_ENV:-$DEFAULT_EXEC_ENV}"
	prepull_timeout="${CDROUTER_USP_SERVICES_PREPULL_TIMEOUT:-$DEFAULT_PREPULL_TIMEOUT}"
	wan_settle_delay="${CDROUTER_USP_SERVICES_PREPULL_WAN_SETTLE_DELAY:-$DEFAULT_WAN_SETTLE_DELAY}"

	validate_uuid CDROUTER_USP_SERVICES_TEST_APP_UUID "$test_app_uuid"
	validate_positive_integer CDROUTER_USP_SERVICES_PREPULL_TIMEOUT "$prepull_timeout"
	validate_positive_integer CDROUTER_USP_SERVICES_PREPULL_WAN_SETTLE_DELAY "$wan_settle_delay"
	validate_no_double_quote CDROUTER_USP_SERVICES_TEST_APP_URL "$CDROUTER_USP_SERVICES_TEST_APP_URL"
	validate_no_double_quote CDROUTER_USP_SERVICES_EXEC_ENV "$exec_env"

	expand_url_tokens "$CDROUTER_USP_SERVICES_TEST_APP_URL" ||
		fail "Unable to expand %BOARD_ARCH% in CDROUTER_USP_SERVICES_TEST_APP_URL"
	validate_no_double_quote CDROUTER_USP_SERVICES_TEST_APP_URL "$test_app_url"

	registry_host="$(docker_registry_host_from_url "$test_app_url")" ||
		fail "CDROUTER_USP_SERVICES_TEST_APP_URL must be a docker:// registry URL"
	test_app_version="$(docker_image_version_from_url "$test_app_url")"
	test_app_duid="$(generate_test_app_duid "$test_app_uuid" "$exec_env")"

	log_info "USP Services test app DUID is $test_app_duid"
	log_info "USP Services test app image version is $test_app_version"

	deadline=$(($(date +%s) + prepull_timeout))

	bring_testbed_wan_up
	trap bring_testbed_wan_down EXIT

	wait_for_condition "DUT default route" dut_has_default_route
	wait_for_condition "DUT DNS resolution for $registry_host" dut_can_resolve_registry
	pull_test_app_image
	wait_for_condition "USP Services test application image" rlyeh_image_downloaded

	log_success "USP Services test application image is pre-pulled"
}

trap 'handle_error $? $LINENO $BASH_LINENO "$BASH_COMMAND"' ERR

main "$@"
