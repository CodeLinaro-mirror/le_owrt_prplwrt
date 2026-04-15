#!/bin/bash

source .gitlab/scripts/dut-init/cdrouter-dut-configure-usp-common.sh

set -eu
set -o pipefail

trap 'handle_error $? $LINENO $BASH_LINENO "$BASH_COMMAND" $(printf "::%s" ${FUNCNAME[@]:-})' ERR

main() {
	local reset_file=".gitlab/scripts/dut-init/obuspa_param_reset-mqtt.txt"

	USP_DEBUG_PATHS=(
		"Device.LocalAgent.MTP.1."
		"Device.LocalAgent.Controller.1.MTP.1."
		"Device.MQTT."
	)

	configure_usp_reset_file "$reset_file" "MQTTv5"
	wait_till_usp_value \
		"Device.LocalAgent.MTP.1.Protocol" \
		"MQTT" \
		"LocalAgent MQTT protocol"
	wait_till_usp_value \
		"Device.LocalAgent.MTP.1.MQTT.ResponseTopicConfigured" \
		"/queue/agent-1" \
		"LocalAgent MQTT response topic"
	wait_till_usp_value \
		"Device.LocalAgent.Controller.1.MTP.1.MQTT.Topic" \
		"/controller-path" \
		"Controller MQTT topic"

	log_success "Configured DUT to use MQTTv5 as USP MTP"
}

main
