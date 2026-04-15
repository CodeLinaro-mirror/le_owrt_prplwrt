#!/bin/bash

source .gitlab/scripts/helpers.sh

USP_DEBUG_PATHS=()

handle_error() {
	local exit_code=$1
	local line_no=$2
	local bash_lineno=$3
	local last_command=$4

	log_error "Error occurred in script at line: $line_no / $bash_lineno"
	log_error "Command that failed: $last_command"
	log_error "Exit code: $exit_code"

	exit "$exit_code"
}

obuspa_get() {
	# shellcheck disable=SC2029
	ssh "root@$TARGET_LAN_IP" obuspa -c get "$1"
}

obuspa_value() {
	local path="$1"

	obuspa_get "$path" 2>/dev/null |
		awk -F' => ' -v path="$path" '$1 == path { print $2; exit }'
}

dump_usp_state() {
	local path

	for path in "$@"; do
		[ -n "$path" ] || continue
		log_info "Dumping $path"
		obuspa_get "$path" || true
	done

	log_info "Dumping recent system log lines"
	# shellcheck disable=SC2029
	ssh "root@$TARGET_LAN_IP" "logread | tail -n 200" || true
}

wait_till_usp_value() {
	local path="$1"
	local expected="$2"
	local description="$3"
	local timeout="${4:-120}"
	local diff=0
	local start_time
	local value=""

	start_time=$(date +%s)
	log_info "Checking if $description is ready..."

	while true; do
		value=$(obuspa_value "$path" || true)
		if [ "$value" = "$expected" ]; then
			log_success "$description is ready"
			return 0
		fi

		diff=$(($(date +%s) - start_time))
		if [ "$diff" -ge "$timeout" ]; then
			log_error "Timeout waiting for $description, expected '$expected', got '${value:-<empty>}'"
			dump_usp_state "${USP_DEBUG_PATHS[@]}"
			return 1
		fi

		log_info "Waiting for $description ($diff s)"
		sleep 5
	done
}

configure_usp_reset_file() {
	local reset_file="$1"
	local protocol_name="$2"
	local remote_reset_file="/etc/config/obuspa_param_reset.txt"

	log_info "Stopping obuspa service"
	ssh "root@$TARGET_LAN_IP" "service obuspa stop"

	log_info "Installing ${protocol_name} OBUSPA reset file"
	scp "$reset_file" "root@${TARGET_LAN_IP}:${remote_reset_file}"

	log_info "Removing stale OBUSPA database"
	ssh "root@$TARGET_LAN_IP" "rm -f /etc/obuspa.db"

	log_info "Starting obuspa service"
	ssh "root@$TARGET_LAN_IP" "service obuspa start"
}
