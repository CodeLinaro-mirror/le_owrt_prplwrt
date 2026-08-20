Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../../scripts/passthrough.sh"

  $ R logger -t cram "tr181-passthrough: ODL enum + policy FIB routes"

  $ init_passthrough_dm_paths
  passthrough-dm-(bbf|legacy) (re)

ODL on DUT must advertise BBF 2.22 Mode enum (product check-in gate):

  $ assert_odl_mode_enum_on_dut
  odl-mode-enum-bbf-present

Enable Fixed mode and wait for Status=Enabled:

  $ wait_until_wan_ipv4_available
  wan-ipv4-ready=[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ (re)

  $ apply_passthrough_dhcps_fixed_mode
  passthrough-mode-dhcps-fixed

  $ apply_passthrough_synthetic_client_mac
  passthrough-client-mac-configured

  $ apply_passthrough_enable
  passthrough-enable-applied

  $ sleep 25

  $ wait_until_passthrough_status_enabled
  Device.IP.(Passthrough|X_PRPLWARE-COM_Passthrough).1.Status="Enabled" (re)

  $ read_passthrough_mode
  Device.IP.(Passthrough|X_PRPLWARE-COM_Passthrough).1.Mode="(DHCPServerFixed|DHCPSFixed|DHCPS-fixed)" (re)

Northbound interface refs populated (Source/Destination/RouterRef):

  $ show_passthrough_northbound_refs
  Device.IP.(Passthrough|X_PRPLWARE-COM_Passthrough).1.DestinationInterface="Device\..*" (re)
  Device.IP.(Passthrough|X_PRPLWARE-COM_Passthrough).1.Mode="(DHCPServerFixed|DHCPSFixed|DHCPS-fixed)" (re)
  Device.IP.(Passthrough|X_PRPLWARE-COM_Passthrough).1.RouterRef="Device\..*" (re)
  Device.IP.(Passthrough|X_PRPLWARE-COM_Passthrough).1.SourceInterface="Device\..*" (re)
  Device.IP.(Passthrough|X_PRPLWARE-COM_Passthrough).1.Status="Enabled" (re)

Board routes: policy rule + table default + public-lan G/32 (prpl CRAM focus):

  $ assert_passthrough_policy_fib_enabled
  policy-rules=.*iif br-lan.* (re)
  policy-routes=.*default.* (re)
  lan-slash32=.*inet .*/32.* (re)
  passthrough-policy-fib-enabled

Teardown and confirm FIB cleaned:

  $ apply_passthrough_disable
  passthrough-disable-applied

  $ sleep 15

  $ wait_until_passthrough_status_disabled
  Device.IP.(Passthrough|X_PRPLWARE-COM_Passthrough).1.Status="Disabled" (re)

  $ assert_passthrough_policy_fib_cleared
  policy-rules-after-disable=.* (re)
  lan-slash32-after-disable=.* (re)
  passthrough-policy-fib-cleared
