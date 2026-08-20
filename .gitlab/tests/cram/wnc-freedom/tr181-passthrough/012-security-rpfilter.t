Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../../scripts/passthrough.sh"

  $ R logger -t cram "tr181-passthrough: security rp_filter and spoofing"

  $ init_passthrough_dm_paths
  passthrough-dm-(bbf|legacy) (re)

Passthrough must be enabled (run after 011-enable-dhcp-server-fixed.t):

  $ read_passthrough_enable
  Device.IP.(Passthrough|X_PRPLWARE-COM_Passthrough).1.Enable=1 (re)

  $ wait_until_passthrough_status_enabled
  Device.IP.(Passthrough|X_PRPLWARE-COM_Passthrough).1.Status="Enabled" (re)

When passthrough is enabled, rp_filter must be relaxed (all=0):

  $ assert_rp_filter_when_pt_enabled
  rp-filter-all=0
  rp-filter-lan=[0-9]+ (re)
  passthrough-rp-filter-disabled-when-enabled

LAN IPv4SpoofingProtection must stay enabled during passthrough:

  $ assert_lan_ipv4_spoofing_protection_enabled
  passthrough-lan-spoofing-protection-enabled

Passthrough firewall rules must still be present:

  $ assert_passthrough_firewall_enabled
  passthrough-firewall-enabled
  dm-passthrough-rules=[0-9]+ (re)
  mangle-prerouting-connmark=[0-9]+ (re)
  nat-prerouting-dnat=[0-9]+ (re)
  filter-forward-out-accept=[0-9]+ (re)
