Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../../scripts/passthrough.sh"

  $ R logger -t cram "tr181-passthrough: defaults and reset"

Wait for Device.IP.Passthrough. (amx_wait_for waits for every argument; BBF path only):

  $ R "amx_wait_for Device.IP.Passthrough."

  $ init_passthrough_dm_paths
  passthrough-dm-(bbf|legacy) (re)

  $ sleep 5

Check tr181-passthrough daemon is running:

  $ verify_passthrough_daemon_running
  passthrough-daemon-running

Reset passthrough to factory defaults (idempotent after a prior run):

  $ reset_passthrough_to_defaults
  passthrough-disable-applied
  passthrough-mode-dhcps-dynamic
  passthrough-client-mac-cleared
  passthrough-reset-to-defaults

  $ sleep 10

Verify passthrough firewall baseline (disabled):

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

Display default Passthrough parameters:

  $ show_passthrough_datamodel
  Device.IP.(Passthrough|X_PRPLWARE-COM_Passthrough). (re)
  Device.IP.(Passthrough|X_PRPLWARE-COM_Passthrough).1. (re)
  Device.IP.(Passthrough|X_PRPLWARE-COM_Passthrough).1.Alias="(main|cpe-passthrough)" (re)
  Device.IP.(Passthrough|X_PRPLWARE-COM_Passthrough).1.Enable=0 (re)
  Device.IP.(Passthrough|X_PRPLWARE-COM_Passthrough).1.Mode="(DHCPServerDynamic|DHCPSDynamic|DHCPS-dynamic)" (re)
  Device.IP.(Passthrough|X_PRPLWARE-COM_Passthrough).1.Status="Disabled" (re)

Display default cpe-passthrough DHCPv4 pool (resolved by alias):

  $ resolve_cpe_passthrough_pool_index
  [0-9]+ (re)

  $ resolve_passthrough_dhcp_pool_index
  [0-9]+ (re)

  $ show_cpe_passthrough_pool_datamodel_defaults
  Device.DHCPv4.Server.Pool.[0-9]+. (re)
  Device.DHCPv4.Server.Pool.[0-9]+.Alias="(cpe-passthrough|cpe_passthrough|Passthrough)" (re)
  Device.DHCPv4.Server.Pool.[0-9]+.Enable=0 (re)
  Device.DHCPv4.Server.Pool.[0-9]+.Status="Disabled" (re)
