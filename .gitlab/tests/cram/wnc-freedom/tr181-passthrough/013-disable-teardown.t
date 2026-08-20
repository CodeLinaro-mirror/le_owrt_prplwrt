Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../../scripts/passthrough.sh"

  $ R logger -t cram "tr181-passthrough: disable and teardown"

  $ init_passthrough_dm_paths
  passthrough-dm-(bbf|legacy) (re)

Disable passthrough and verify firewall cleared:

  $ apply_passthrough_disable
  passthrough-disable-applied

  $ wait_until_passthrough_enable 0
  Device.IP.(Passthrough|X_PRPLWARE-COM_Passthrough).1.Enable=0 (re)

  $ wait_until_passthrough_status_disabled
  Device.IP.(Passthrough|X_PRPLWARE-COM_Passthrough).1.Status="Disabled" (re)

  $ sleep 15

  $ wait_until_passthrough_firewall_disabled
  passthrough-firewall-cleared

  $ assert_passthrough_firewall_disabled
  passthrough-firewall-disabled
  filter-passthrough-appends=(0|2) (re)
  nat-passthrough-appends=0
  mangle-passthrough-appends=0
  forward-passthrough-jump=[1-9][0-9]* (re)
  connmark-forward-dispatch=[1-9][0-9]* (re)
  dm-passthrough-rules=0

After disable, rp_filter should be restored (platform default strict):

  $ assert_rp_filter_restored_when_pt_disabled
  rp-filter-all=1
  passthrough-rp-filter-restored-when-disabled

  $ R logger -t cram "tr181-passthrough test suite finished"
