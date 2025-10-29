#!/bin/bash

source .gitlab/scripts/helpers.sh

set -eu         # exit on error and undefined variables
set -o pipefail # catch errors in pipes

radio_2g_path=""
ssid_2g_path=""

trap 'handle_error $? $LINENO $BASH_LINENO "$BASH_COMMAND" $(printf "::%s" ${FUNCNAME[@]:-})' ERR

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

ba_cli() {
	# shellcheck disable=SC2029
	ssh "root@$TARGET_LAN_IP" "ba-cli '$1'"
}

ba_cli_json() {
	# shellcheck disable=SC2029
	ssh "root@$TARGET_LAN_IP" "ba-cli --less --json '$1'"
}

# Device.WiFi.Radio.1.
dm_wifi_radio_2g_path() {
	ba_cli_json \
		"Device.WiFi.Radio.[OperatingFrequencyBand == \"2.4GHz\"].Alias?0" |
		jq -r '.[0] | keys[]' 2>/dev/null |
		sed 's/\.$//'
}

# Device.WiFi.SSID.1.
dm_wifi_2g_ssid_path() {
	local ssid="$1"
	[ -n "$radio_2g_path" ] || radio_2g_path=$(dm_wifi_radio_2g_path)
	ba_cli_json \
		"Device.WiFi.SSID.[LowerLayers == \"${radio_2g_path}\" && SSID == \"$ssid\"].Alias?0" |
		jq -r '.[0] | keys[]' 2>/dev/null |
		sed 's/\.$//'
}

dm_wifi_radio_2g() {
	[ -n "$radio_2g_path" ] || radio_2g_path=$(dm_wifi_radio_2g_path)
	ba_cli "$radio_2g_path.$1"
}

dm_wifi_ssid_2g() {
	local ssid="$1"
	[ -n "$ssid_2g_path" ] || ssid_2g_path=$(dm_wifi_2g_ssid_path "$ssid")
	ba_cli "$ssid_2g_path.$2"
}

wait_till_dm_ready() {
	local diff=0
	local start_time
	local current_time
	local timeout=120
	local radio_path=""

	start_time=$(cut -d. -f1 /proc/uptime)

	log_info "Checking if WiFi 2.4GHz radio datamodel is available..."

	while [ -z "$radio_path" ]; do
		radio_path=$(dm_wifi_radio_2g_path || true)
		current_time=$(cut -d. -f1 /proc/uptime)
		diff=$((current_time - start_time))

		if [ $diff -ge $timeout ]; then
			log_error "Timeout waiting for WiFi 2.4GHz radio datamodel to be available!"
			exit 1
		fi

		if [ -z "$radio_path" ]; then
			log_info "Waiting for WiFi 2.4GHz radio datamodel to be available ($diff s)"
			sleep 5
		fi
	done

	log_success "WiFi 2.4GHz radio datamodel is available"
}

configure_wireless_for_testbed_one() {
	log_info "Configuring DUT with wireless settings for testbed-01"

	dm_wifi_radio_2g Channel=6
	dm_wifi_ssid_2g prplOS SSID=prplOS-2g-6
}

configure_wireless_for_testbed_two() {
	log_info "Configuring DUT with wireless settings for testbed-02"

	dm_wifi_radio_2g Channel=11
	dm_wifi_ssid_2g prplOS SSID=prplOS-2g-11
}

running_on_testbed_one() {
	if echo "$CI_RUNNER_DESCRIPTION" | grep -q testbed-01; then
		return 0
	fi
	return 1
}

running_on_testbed_two() {
	if echo "$CI_RUNNER_DESCRIPTION" | grep -q testbed-02; then
		return 0
	fi
	return 1
}

wait_till_regulatory_domain_change() {
	for i in {1..10}; do
		if dm_wifi_radio_2g PossibleChannels? | grep -q '1,.*,13'; then
			log_success "Regulatory domain change took effect, channels 1-13 are available"
			return 0
		fi

		log_info "Waiting for regulatory domain change to take effect ($i/10)"
		sleep 1
	done

	log_error "Timeout waiting for regulatory domain change to take effect"
	exit 1
}

configure_regulatory_domain() {
	log_info "Configuring DUT for Czechia regulatory domain"
	dm_wifi_radio_2g RegulatoryDomain=CZ
}

main() {
	wait_till_dm_ready
	# configure_regulatory_domain
	# wait_till_regulatory_domain_change

	log_info "Enabling SSID in 2.4GHz band"
	dm_wifi_ssid_2g prplOS Enable=1

	running_on_testbed_one && configure_wireless_for_testbed_one
	running_on_testbed_two && configure_wireless_for_testbed_two

	return 0
}

main
