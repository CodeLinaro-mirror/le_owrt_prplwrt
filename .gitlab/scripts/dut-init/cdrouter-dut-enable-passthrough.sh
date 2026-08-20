#!/bin/bash
# DUT init for CDRouter-Passthrough. Runs on the GitLab runner (same as
# cdrouter-dut-flush-dns-relay-cache.sh / cdrouter-dut-configure-dyndns.sh).
#
# Enable DHCPServerFixed with a synthetic ClientMAC so CDRouter's LAN host
# (different MAC) still NATs. Product passthrough + spoofing are on.

set -eu
set -o pipefail

ssh_dut() {
	# shellcheck disable=SC2029
	ssh "root@$TARGET_LAN_IP" "$1"
}

PT_ROOT=""
PT_MODE=""
if ssh_dut "ba-cli 'Device.IP.Passthrough.1.Enable?'" | grep -q 'Device.IP.Passthrough.1.'; then
	PT_ROOT="Device.IP.Passthrough"
	PT_MODE="DHCPServerFixed"
elif ssh_dut "ba-cli 'Device.IP.X_PRPLWARE-COM_Passthrough.1.Enable?'" | grep -q 'X_PRPLWARE-COM_Passthrough'; then
	PT_ROOT="Device.IP.X_PRPLWARE-COM_Passthrough"
	PT_MODE="DHCPS-fixed"
else
	echo "passthrough DM not found — skip enable-passthrough init"
	exit 0
fi

echo "passthrough init on ${PT_ROOT} Mode=${PT_MODE}"

ssh_dut "ba-cli '${PT_ROOT}.1.Enable=0'" >/dev/null || true
ssh_dut "ba-cli '${PT_ROOT}.1.Mode=${PT_MODE}'" >/dev/null || true
ssh_dut "ba-cli '${PT_ROOT}.1.ClientMACAddress=AA:BB:CC:DD:EE:FF'" >/dev/null || true
ssh_dut "ba-cli '${PT_ROOT}.1.Enable=1'" >/dev/null || true
sleep 15
ssh_dut "ba-cli '${PT_ROOT}.1.Status?'"
