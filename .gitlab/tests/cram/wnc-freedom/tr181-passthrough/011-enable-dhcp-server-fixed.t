Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../../scripts/passthrough.sh"

  $ R logger -t cram "tr181-passthrough: enable DHCPServerFixed"

  $ init_passthrough_dm_paths
  passthrough-dm-(bbf|legacy) (re)

Wait for WAN IPv4 and passthrough firewall chains before enable:

  $ wait_until_wan_ipv4_available
  wan-ipv4-ready=[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ (re)

  $ verify_passthrough_firewall_chains_present
  passthrough-firewall-chains-present

Assign DHCPSFixed mode and synthetic MAC (before enable):

  $ apply_passthrough_dhcps_fixed_mode
  passthrough-mode-dhcps-fixed

  $ apply_passthrough_synthetic_client_mac
  passthrough-client-mac-configured

  $ sleep 5

  $ read_passthrough_mode
  Device.IP.(Passthrough|X_PRPLWARE-COM_Passthrough).1.Mode="(DHCPServerFixed|DHCPSFixed|DHCPS-fixed)" (re)

  $ read_passthrough_client_mac
  Device.IP.(Passthrough|X_PRPLWARE-COM_Passthrough).1.ClientMACAddress="AA:BB:CC:DD:EE:FF" (re)

Enable passthrough:

  $ apply_passthrough_enable
  passthrough-enable-applied

  $ sleep 20

Check passthrough status after enable:

  $ wait_until_passthrough_enable 1
  Device.IP.(Passthrough|X_PRPLWARE-COM_Passthrough).1.Enable=1 (re)

  $ wait_until_passthrough_status_enabled
  Device.IP.(Passthrough|X_PRPLWARE-COM_Passthrough).1.Status="Enabled" (re)

Verify passthrough firewall rules after enable:

  $ sleep 15

  $ wait_until_passthrough_firewall_enabled
  passthrough-firewall-ready

  $ assert_passthrough_firewall_enabled
  passthrough-firewall-enabled
  dm-passthrough-rules=[0-9]+ (re)
  mangle-prerouting-connmark=[0-9]+ (re)
  nat-prerouting-dnat=[0-9]+ (re)
  filter-forward-out-accept=[0-9]+ (re)

Fetch cpe-passthrough pool after enable:

  $ sleep 10

  $ show_cpe_passthrough_pool_enabled_state
  Device.DHCPv4.Server.Pool.[0-9]+.Alias="(cpe-passthrough|cpe_passthrough|Passthrough)" (re)
  Device.DHCPv4.Server.Pool.[0-9]+.Chaddr="(AA:BB:CC:DD:EE:FF|)" (re)
  Device.DHCPv4.Server.Pool.[0-9]+.Enable=1 (re)
  Device.DHCPv4.Server.Pool.[0-9]+.IPRouters="[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" (re)
  Device.DHCPv4.Server.Pool.[0-9]+.LeaseTime=[0-9]+ (re)
  Device.DHCPv4.Server.Pool.[0-9]+.MaxAddress="[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" (re)
  Device.DHCPv4.Server.Pool.[0-9]+.MinAddress="[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" (re)
  Device.DHCPv4.Server.Pool.[0-9]+.StaticAddressNumberOfEntries=[0-9]+ (re)
  Device.DHCPv4.Server.Pool.[0-9]+.Status="(Enabled|Disabled)" (re)

Compare WAN IPv4 with pool MinAddress/MaxAddress:

  $ assert_wan_ipv4_matches_pool_min_max
  wan-ipv4=[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ (re)
  Device.DHCPv4.Server.Pool.[0-9]+.MinAddress="[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" (re)
  Device.DHCPv4.Server.Pool.[0-9]+.MaxAddress="[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" (re)
  wan-ipv4-matches-pool-min-max
