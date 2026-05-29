Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/scripts/passthrough.sh"

  $ R logger -t cram "Starting tr181-passthrough test ..."

Wait for Passthrough datamodel availability:

  $ R "amx_wait_for "Device.IP.X_PRPLWARE-COM_Passthrough." "

  $ sleep 10

Check tr181-passthrough daemon is running:

  $ R logger -t cram "Check tr181-passthrough daemon is running"

  $ verify_passthrough_daemon_running
  passthrough-daemon-running

Reset passthrough to factory defaults (idempotent after a prior run):

  $ R logger -t cram "Reset passthrough to factory defaults"

  $ reset_passthrough_to_defaults
  passthrough-disable-applied
  Device.IP.X_PRPLWARE-COM_Passthrough.1.Enable=0
  Device.IP.X_PRPLWARE-COM_Passthrough.1.Status="Disabled"
  passthrough-mode-dhcps-dynamic
  passthrough-client-mac-cleared
  passthrough-reset-to-defaults

  $ sleep 10

Verify passthrough firewall baseline (disabled):

  $ R logger -t cram "Verify passthrough firewall cleared after reset"

  $ sleep 5

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

  $ R logger -t cram "Display default Passthrough parameters"

  $ show_passthrough_datamodel
  Device.IP.X_PRPLWARE-COM_Passthrough.
  Device.IP.X_PRPLWARE-COM_Passthrough.1.
  Device.IP.X_PRPLWARE-COM_Passthrough.1.Alias="main"
  Device.IP.X_PRPLWARE-COM_Passthrough.1.ClientLeaseDuration=300
  Device.IP.X_PRPLWARE-COM_Passthrough.1.ClientMACAddress=""
  Device.IP.X_PRPLWARE-COM_Passthrough.1.CurrentPassthroughHost=""
  Device.IP.X_PRPLWARE-COM_Passthrough.1.Enable=0
  Device.IP.X_PRPLWARE-COM_Passthrough.1.LogicalInterfaceReference="(Device\.Logical\.Interface\.[0-9]+\.|)" (re)
  Device.IP.X_PRPLWARE-COM_Passthrough.1.Mode="DHCPS-dynamic"
  Device.IP.X_PRPLWARE-COM_Passthrough.1.RouterReference="Device.Routing.Router.2."
  Device.IP.X_PRPLWARE-COM_Passthrough.1.Status="Disabled"

Display default cpe-passthrough DHCPv4 pool (resolved by alias):

  $ R logger -t cram "Display default cpe-passthrough pool parameters"

  $ resolve_cpe_passthrough_pool_index
  [0-9]+ (re)

  $ resolve_passthrough_dhcp_pool_index
  [0-9]+ (re)

  $ show_cpe_passthrough_pool_datamodel_defaults
  Device.DHCPv4.Server.Pool.[0-9]+. (re)
  Device.DHCPv4.Server.Pool.[0-9]+.Alias="(cpe-passthrough|cpe_passthrough)" (re)
  Device.DHCPv4.Server.Pool.[0-9]+.AllowedDevices="All" (re)
  Device.DHCPv4.Server.Pool.[0-9]+.AssignedLeasesNumberOfEntries=0 (re)
  Device.DHCPv4.Server.Pool.[0-9]+.Chaddr="" (re)
  Device.DHCPv4.Server.Pool.[0-9]+.ChaddrExclude=0 (re)
  Device.DHCPv4.Server.Pool.[0-9]+.ChaddrMask="" (re)
  Device.DHCPv4.Server.Pool.[0-9]+.ClientID="" (re)
  Device.DHCPv4.Server.Pool.[0-9]+.ClientIDExclude=0 (re)
  Device.DHCPv4.Server.Pool.[0-9]+.ClientNumberOfEntries=0 (re)
  Device.DHCPv4.Server.Pool.[0-9]+.DNSServers="" (re)
  Device.DHCPv4.Server.Pool.[0-9]+.DomainName="" (re)
  Device.DHCPv4.Server.Pool.[0-9]+.Enable=0 (re)
  Device.DHCPv4.Server.Pool.[0-9]+.IPRouters="" (re)
  Device.DHCPv4.Server.Pool.[0-9]+.Interface="Device.IP.Interface.3." (re)
  Device.DHCPv4.Server.Pool.[0-9]+.LeaseTime=300 (re)
  Device.DHCPv4.Server.Pool.[0-9]+.MaxAddress="" (re)
  Device.DHCPv4.Server.Pool.[0-9]+.MinAddress="" (re)
  Device.DHCPv4.Server.Pool.[0-9]+.OptionNumberOfEntries=(0|2) (re)
  Device.DHCPv4.Server.Pool.[0-9]+.Order=1 (re)
  Device.DHCPv4.Server.Pool.[0-9]+.ReservedAddresses="" (re)
  Device.DHCPv4.Server.Pool.[0-9]+.StaticAddressNumberOfEntries=0 (re)
  Device.DHCPv4.Server.Pool.[0-9]+.Status="Disabled" (re)
  Device.DHCPv4.Server.Pool.[0-9]+.SubnetMask="255.255.255.255" (re)
  Device.DHCPv4.Server.Pool.[0-9]+.UserClassID="" (re)
  Device.DHCPv4.Server.Pool.[0-9]+.UserClassIDExclude=0 (re)
  Device.DHCPv4.Server.Pool.[0-9]+.VendorClassID="" (re)
  Device.DHCPv4.Server.Pool.[0-9]+.VendorClassIDExclude=0 (re)
  Device.DHCPv4.Server.Pool.[0-9]+.VendorClassIDMode="Exact" (re)
  Device.DHCPv4.Server.Pool.[0-9]+.WINSServers="" (re)

Assign DHCPS-fixed mode and synthetic MAC (before enable):

  $ R logger -t cram "Wait for WAN IPv4 and passthrough firewall chains before enable"

  $ wait_until_wan_ipv4_available
  wan-ipv4-ready=[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ (re)

  $ verify_passthrough_firewall_chains_present
  passthrough-firewall-chains-present

  $ R logger -t cram "Assign DHCPS-fixed mode and synthetic ClientMACAddress"

  $ apply_passthrough_dhcps_fixed_mode
  passthrough-mode-dhcps-fixed

  $ apply_passthrough_synthetic_client_mac
  passthrough-client-mac-configured

  $ sleep 5

  $ read_passthrough_mode
  Device.IP.X_PRPLWARE-COM_Passthrough.1.Mode="DHCPS-fixed"

  $ read_passthrough_client_mac
  Device.IP.X_PRPLWARE-COM_Passthrough.1.ClientMACAddress="AA:BB:CC:DD:EE:FF"

Enable passthrough:

  $ R logger -t cram "Enable passthrough"

  $ apply_passthrough_enable
  passthrough-enable-applied

  $ sleep 20

Check passthrough status after enable:

  $ R logger -t cram "Check passthrough status after enable"

  $ wait_until_passthrough_enable 1
  Device.IP.X_PRPLWARE-COM_Passthrough.1.Enable=1

  $ wait_until_passthrough_status_enabled
  Device.IP.X_PRPLWARE-COM_Passthrough.1.Status="Enabled"

Verify passthrough firewall rules after enable:

  $ R logger -t cram "Verify passthrough firewall rules after enable"

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

  $ R logger -t cram "Fetch cpe-passthrough pool by alias"

  $ sleep 10

  $ show_cpe_passthrough_pool_enabled_state
  Device.DHCPv4.Server.Pool.[0-9]+.Alias="(cpe-passthrough|cpe_passthrough)" (re)
  Device.DHCPv4.Server.Pool.[0-9]+.Chaddr="(AA:BB:CC:DD:EE:FF|)" (re)
  Device.DHCPv4.Server.Pool.[0-9]+.Enable=1 (re)
  Device.DHCPv4.Server.Pool.[0-9]+.IPRouters="([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+|)" (re)
  Device.DHCPv4.Server.Pool.[0-9]+.LeaseTime=300 (re)
  Device.DHCPv4.Server.Pool.[0-9]+.MaxAddress="[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" (re)
  Device.DHCPv4.Server.Pool.[0-9]+.MinAddress="[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" (re)
  Device.DHCPv4.Server.Pool.[0-9]+.StaticAddressNumberOfEntries=(0|1) (re)
  Device.DHCPv4.Server.Pool.[0-9]+.Status="(Enabled|Disabled)" (re)

Compare Logical.Interface WAN IPv4 with pool MinAddress/MaxAddress:

  $ R logger -t cram "Compare Logical.Interface WAN IPv4 with pool MinAddress and MaxAddress"

  $ sleep 10

  $ assert_logical_wan_ipv4_matches_pool_min_max
  Device.Logical.Interface.1.X_PRPLWARE-COM_WAN.IPv4Address="[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" (re)
  Device.DHCPv4.Server.Pool.[0-9]+.MinAddress="[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" (re)
  Device.DHCPv4.Server.Pool.[0-9]+.MaxAddress="[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" (re)
  logical-wan-ipv4-matches-pool-min-max

Disable passthrough and verify firewall cleared:

  $ R logger -t cram "Disable passthrough and verify firewall rules cleared"

  $ apply_passthrough_disable
  passthrough-disable-applied

  $ wait_until_passthrough_enable 0
  Device.IP.X_PRPLWARE-COM_Passthrough.1.Enable=0

  $ wait_until_passthrough_status_disabled
  Device.IP.X_PRPLWARE-COM_Passthrough.1.Status="Disabled"

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

  $ R logger -t cram "tr181-passthrough test finished!"

