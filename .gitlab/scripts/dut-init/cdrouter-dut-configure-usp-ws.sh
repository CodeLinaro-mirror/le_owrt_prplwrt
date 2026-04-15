#!/bin/bash

source .gitlab/scripts/dut-init/cdrouter-dut-configure-usp-common.sh

set -eu
set -o pipefail

trap 'handle_error $? $LINENO $BASH_LINENO "$BASH_COMMAND" $(printf "::%s" ${FUNCNAME[@]:-})' ERR

main() {
	local reset_file=".gitlab/scripts/dut-init/obuspa_param_reset-ws.txt"

	USP_DEBUG_PATHS=(
		"Device.LocalAgent.MTP.1."
		"Device.LocalAgent.Controller.1.MTP.1."
	)

	configure_usp_reset_file "$reset_file" "WebSocket"
	wait_till_usp_value \
		"Device.LocalAgent.MTP.1.Protocol" \
		"WebSocket" \
		"LocalAgent WebSocket protocol"
	wait_till_usp_value \
		"Device.LocalAgent.MTP.1.WebSocket.Path" \
		"/queue/agent-1" \
		"LocalAgent WebSocket path"
	wait_till_usp_value \
		"Device.LocalAgent.Controller.1.MTP.1.WebSocket.Path" \
		"/controller-path" \
		"Controller WebSocket path"

	log_success "Configured DUT to use WebSocket as USP MTP"
}

main
