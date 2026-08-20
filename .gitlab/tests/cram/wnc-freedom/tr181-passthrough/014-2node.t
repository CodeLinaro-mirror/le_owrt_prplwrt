Two-node passthrough cram (runner = TARGET_LAN_TEST_HOST, DUT = TARGET_LAN_IP).
Pattern: NAT portmapping 015-nat-portmapping.t — testbed PC is second LAN node.

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../../scripts/passthrough.sh"

  $ R logger -t cram "tr181-passthrough: 2-node LAN runner test"

  $ init_passthrough_dm_paths
  passthrough-dm-(bbf|legacy) (re)

Runner LAN connectivity to testbed host address:

  $ pt_cram_verify_runner_lan_reachable
  3 packets transmitted, 3 received, 0% packet loss

Reset and configure passthrough for runner MAC (when available):

  $ reset_passthrough_to_defaults
  passthrough-reset-to-defaults

  $ wait_until_wan_ipv4_available
  wan-ipv4-ready=[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ (re)

  $ RUNNER_MAC="$(pt_cram_runner_lan_mac)"; if [ -n "$RUNNER_MAC" ]; then apply_passthrough_client_mac "$RUNNER_MAC"; else apply_passthrough_synthetic_client_mac; fi
  passthrough-client-mac-configured

  $ apply_passthrough_dhcps_fixed_mode
  passthrough-mode-dhcps-fixed

  $ apply_passthrough_enable
  passthrough-enable-applied

  $ wait_until_passthrough_status_enabled
  Device.IP.(Passthrough|X_PRPLWARE-COM_Passthrough).1.Status="Enabled"

Read public IP P from passthrough pool and bind runner (optional datapath check):

  $ PT_PUBLIC_IP="$(read_passthrough_pool_public_ip)"; echo "pt-public-ip=${PT_PUBLIC_IP}"
  pt-public-ip=[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ (re)

  $ pt_cram_bind_runner_public_ip "$PT_PUBLIC_IP"
  passthrough-runner-bound-public-ip

Runner ping to DUT LAN IP must succeed:

  $ ping -c2 -W1 ${TARGET_LAN_IP:-192.168.1.1}
  2 packets transmitted, 2 received, 0% packet loss

Security readback while PT on (2-node context):

  $ assert_rp_filter_when_pt_enabled
  passthrough-rp-filter-disabled-when-enabled

  $ assert_lan_ipv4_spoofing_protection_enabled
  passthrough-lan-spoofing-protection-enabled

Teardown runner bind and disable passthrough:

  $ pt_cram_unbind_runner_public_ip "$PT_PUBLIC_IP"
  passthrough-runner-unbound-public-ip

  $ apply_passthrough_disable
  passthrough-disable-applied

  $ wait_until_passthrough_status_disabled
  Device.IP.(Passthrough|X_PRPLWARE-COM_Passthrough).1.Status="Disabled"
