#
# tr181-passthrough cram helpers (plugin: ${TESTDIR}/../../scripts/passthrough.sh; generic: ${TESTDIR}/../scripts/passthrough.sh)
# Requires: alias R="${CRAM_REMOTE_COMMAND:-}" before sourcing.
# amx_wait_for waits for ALL arguments with no timeout. Never pass BBF+legacy together.
#
# BBF northbound: Device.IP.Passthrough.{i}.*  (Mode: Manual | DHCPServerFixed | DHCPServerDynamic)
# Legacy fallback: Device.IP.X_PRPLWARE-COM_Passthrough.{i}.* (DHCPS-fixed / DHCPS-dynamic)
# Call init_passthrough_dm_paths once per cram file after sourcing.
#

PT_POOL_ALIAS_PRIMARY="cpe-passthrough"
PT_FW_POLL_SECS=2
PT_FW_POLL_TRIES=30
PT_POOL_ALIAS_LEGACY="cpe_passthrough"
PT_SYNTHETIC_MAC="AA:BB:CC:DD:EE:FF"
PT_LOGICAL_WAN_IF="Device.Logical.Interface.1."
PT_DM_ROOT=""
PT_MODE_FIXED=""
PT_MODE_DYNAMIC=""
PT_USE_BBF=0

_filter_ubus_device_lines() {
  grep -v '^>' | grep '^Device\.' | sed '/^$/d'
}

# Detect BBF vs legacy DM once per cram session.
init_passthrough_dm_paths() {
  if R "ubus-cli Device.IP.Passthrough.1.Enable? 2>&1" |
    _filter_ubus_device_lines | grep -q 'Device.IP.Passthrough.1.Enable='; then
    PT_DM_ROOT="Device.IP.Passthrough"
    # BBF 2.22 canonical names (product ODL). Accept short aliases only if DM rewrites them.
    PT_MODE_FIXED="DHCPServerFixed"
    PT_MODE_DYNAMIC="DHCPServerDynamic"
    PT_USE_BBF=1
    echo passthrough-dm-bbf
    return 0
  fi
  if R "ubus-cli Device.IP.X_PRPLWARE-COM_Passthrough.1.Enable? 2>&1" |
    _filter_ubus_device_lines | grep -q 'Device.IP.X_PRPLWARE-COM_Passthrough.1.Enable='; then
    PT_DM_ROOT="Device.IP.X_PRPLWARE-COM_Passthrough"
    PT_MODE_FIXED="DHCPS-fixed"
    PT_MODE_DYNAMIC="DHCPS-dynamic"
    PT_USE_BBF=0
    echo passthrough-dm-legacy
    return 0
  fi
  echo "init_passthrough_dm_paths: Passthrough DM not found" >&2
  return 1
}

_pt_require_dm() {
  if [ -z "$PT_DM_ROOT" ]; then
    init_passthrough_dm_paths >/dev/null || return 1
  fi
}

# Return Pool.{i} index where Alias is cpe-passthrough (or legacy cpe_passthrough).
resolve_cpe_passthrough_pool_index() {
  R "ubus-cli Device.DHCPv4.Server.Pool.*.Alias?" 2>&1 |
    _filter_ubus_device_lines |
    grep -E "Alias=\"(${PT_POOL_ALIAS_PRIMARY}|${PT_POOL_ALIAS_LEGACY})\"" |
    sed -n 's/.*Pool\.\([0-9]*\).*/\1/p' |
    head -1
}

resolve_passthrough_dhcp_pool_index() {
  local pool_index
  pool_index=$(
    R "ubus-cli Device.DHCPv4.Server.Pool.*.Alias?" 2>&1 |
      _filter_ubus_device_lines |
      grep 'Alias="Passthrough"' |
      sed -n 's/.*Pool\.\([0-9]*\).*/\1/p' |
      head -1
  )
  if [ -n "$pool_index" ]; then
    echo "$pool_index"
    return 0
  fi
  pool_index=$(resolve_cpe_passthrough_pool_index)
  if [ -n "$pool_index" ]; then
    echo "$pool_index"
    return 0
  fi
  R "ubus-cli Device.DHCPv4.Server.Pool.5.Alias?" 2>&1 |
    _filter_ubus_device_lines |
    grep -q 'Device\.DHCPv4\.Server\.Pool\.5\.' &&
    echo 5
}

verify_passthrough_daemon_running() {
  R "pgrep -af tr181-passthrough 2>/dev/null | grep -v grep | grep -q 'tr181-passthrough -D' && echo passthrough-daemon-running"
}

show_passthrough_datamodel() {
  _pt_require_dm || return 1
  # CRAM 010 asserts object/instance + Alias/Enable/Mode/Status only (BBF ODL has more params).
  R "ubus-cli ${PT_DM_ROOT}.?" 2>&1 |
    _filter_ubus_device_lines |
    grep -E "^Device\.IP\.(Passthrough|X_PRPLWARE-COM_Passthrough)\.($|1\.$|1\.(Alias|Enable|Mode|Status)=)" |
    LC_ALL=C sort
}

read_wan_ipv4() {
  local ip
  ip=$(
    R "ubus-cli Device.DHCPv4.Client.1.IPAddress? 2>/dev/null" |
      _filter_ubus_device_lines |
      sed -n 's/.*="\([^"]*\)"/\1/p'
  )
  if [ -n "$ip" ]; then
    echo "$ip"
    return 0
  fi
  if [ "$PT_USE_BBF" = 1 ]; then
    R "ubus-cli ${PT_DM_ROOT}.1.SourceInterface? 2>/dev/null" |
      _filter_ubus_device_lines | sed -n 's/.*="\([^"]*\)"/\1/p'
    return 0
  fi
  read_logical_wan_ipv4
}

read_logical_wan_ipv4() {
  R "ubus-cli ${PT_LOGICAL_WAN_IF}X_PRPLWARE-COM_WAN.IPv4Address?" 2>&1 |
    _filter_ubus_device_lines |
    sed -n 's/.*="\([^"]*\)"/\1/p'
}

read_passthrough_enable() {
  _pt_require_dm || return 1
  R "ubus-cli ${PT_DM_ROOT}.1.Enable?" 2>&1 |
    _filter_ubus_device_lines | grep '='
}

read_passthrough_status() {
  _pt_require_dm || return 1
  R "ubus-cli ${PT_DM_ROOT}.1.Status?" 2>&1 |
    _filter_ubus_device_lines | grep '='
}

read_passthrough_client_mac() {
  _pt_require_dm || return 1
  R "ubus-cli ${PT_DM_ROOT}.1.ClientMACAddress?" 2>&1 |
    _filter_ubus_device_lines | grep '='
}

read_passthrough_mode() {
  _pt_require_dm || return 1
  R "ubus-cli ${PT_DM_ROOT}.1.Mode?" 2>&1 |
    _filter_ubus_device_lines | grep '='
}

show_cpe_passthrough_pool_datamodel_defaults() {
  local pool_index
  pool_index=$(resolve_passthrough_dhcp_pool_index)
  if [ -z "$pool_index" ]; then
    echo "show_cpe_passthrough_pool_datamodel_defaults: pool alias not found" >&2
    return 1
  fi
  # CRAM 010 asserts object + Alias/Enable/Status only (full Pool.? dump is too wide).
  R "ubus-cli Device.DHCPv4.Server.Pool.${pool_index}.?" 2>&1 |
    _filter_ubus_device_lines |
    grep -E "^Device\.DHCPv4\.Server\.Pool\.${pool_index}\.($|(Alias|Enable|Status)=)" |
    LC_ALL=C sort
}

show_cpe_passthrough_pool_enabled_state() {
  local pool_index
  pool_index=$(resolve_passthrough_dhcp_pool_index)
  if [ -z "$pool_index" ]; then
    echo "show_cpe_passthrough_pool_enabled_state: pool alias not found" >&2
    return 1
  fi
  R "ubus-cli Device.DHCPv4.Server.Pool.${pool_index}.?" 2>&1 |
    _filter_ubus_device_lines |
    grep -E "^Device\.DHCPv4\.Server\.Pool\.${pool_index}\.(Alias|Chaddr|Enable|IPRouters|LeaseTime|MaxAddress|MinAddress|Status|StaticAddressNumberOfEntries)=" |
    LC_ALL=C sort
}

assert_wan_ipv4_matches_pool_min_max() {
  local pool_index wan_ipv4 pool_min pool_max min_line max_line
  pool_index=$(resolve_passthrough_dhcp_pool_index)
  if [ -z "$pool_index" ]; then
    echo "assert_wan_ipv4_matches_pool_min_max: pool alias not found" >&2
    return 1
  fi
  wan_ipv4=$(read_wan_ipv4 | head -1)
  min_line=$(R "ubus-cli Device.DHCPv4.Server.Pool.${pool_index}.MinAddress?" 2>&1 | _filter_ubus_device_lines)
  max_line=$(R "ubus-cli Device.DHCPv4.Server.Pool.${pool_index}.MaxAddress?" 2>&1 | _filter_ubus_device_lines)
  echo "wan-ipv4=${wan_ipv4:-unknown}"
  echo "$min_line"
  echo "$max_line"
  pool_min=$(echo "$min_line" | sed -n 's/.*="\([^"]*\)"/\1/p')
  pool_max=$(echo "$max_line" | sed -n 's/.*="\([^"]*\)"/\1/p')
  if [ -n "$pool_min" ] && [ "$pool_min" = "$pool_max" ]; then
    if [ -z "$wan_ipv4" ] || [ "$wan_ipv4" = "$pool_min" ]; then
      echo wan-ipv4-matches-pool-min-max
      return 0
    fi
  fi
  echo "assert_wan_ipv4_matches_pool_min_max: mismatch wan='${wan_ipv4}' min='${pool_min}' max='${pool_max}'" >&2
  return 1
}

# Backward-compatible alias used by older cram transcripts.
assert_logical_wan_ipv4_matches_pool_min_max() {
  assert_wan_ipv4_matches_pool_min_max
}

_pt_fw_remote_count() {
  R "$1" 2>/dev/null | head -1 | tr -d '[:space:]'
}

_pt_fw_filter_passthrough_appends() {
  _pt_fw_remote_count "iptables-save -t filter 2>/dev/null | grep -E '^-A (FORWARD_Passthrough|FORWARD_Passthrough_In|FORWARD_Passthrough_Out|INPUT_Passthrough) ' | wc -l"
}

_pt_fw_nat_passthrough_appends() {
  _pt_fw_remote_count "iptables-save -t nat 2>/dev/null | grep -E '^-A (PREROUTING_Passthrough|POSTROUTING_Passthrough) ' | wc -l"
}

_pt_fw_mangle_passthrough_appends() {
  _pt_fw_remote_count "iptables-save -t mangle 2>/dev/null | grep -E '^-A (PREROUTING_Passthrough|OUTPUT_Passthrough) ' | wc -l"
}

_pt_fw_mangle_prerouting_connmark_rules() {
  _pt_fw_remote_count "iptables-save -t mangle 2>/dev/null | grep '^-A PREROUTING_Passthrough ' | grep -E 'CONNMARK|set-mark' | wc -l"
}

_pt_fw_nat_prerouting_dnat_rules() {
  _pt_fw_remote_count "iptables-save -t nat 2>/dev/null | grep '^-A PREROUTING_Passthrough ' | grep -E 'DNAT|REDIRECT' | wc -l"
}

_pt_fw_filter_forward_out_accept_rules() {
  _pt_fw_remote_count "iptables-save -t filter 2>/dev/null | grep '^-A FORWARD_Passthrough_Out ' | grep ACCEPT | wc -l"
}

_pt_fw_forward_passthrough_jump_rules() {
  _pt_fw_remote_count "iptables-save -t filter 2>/dev/null | grep -- '-A FORWARD -j FORWARD_Passthrough' | wc -l"
}

_pt_fw_connmark_forward_dispatch_rules() {
  _pt_fw_remote_count "iptables-save -t filter 2>/dev/null | grep -E 'connmark --mark 0x0*2/0x0*2.*-j FORWARD_Passthrough|-j FORWARD_Passthrough.*connmark --mark 0x0*2/0x0*2' | wc -l"
}

_pt_fw_filter_disabled_ok() {
  case "$1" in
    0|2) return 0 ;;
    *) return 1 ;;
  esac
}

_pt_count_dm_passthrough_rules() {
  _pt_fw_remote_count "ubus-cli Firewall.Chain.*.Rule.*.Alias? 2>/dev/null | grep -v '^>' | grep -c 'Alias=\"pt-'"
}

_pt_fw_passthrough_enabled_ok() {
  local dm_rules=$1 mangle_cm=$2 nat_dnat=$3 fwd_accept=$4

  dm_rules=${dm_rules:-0}
  mangle_cm=${mangle_cm:-0}
  nat_dnat=${nat_dnat:-0}
  fwd_accept=${fwd_accept:-0}

  [ "$dm_rules" -ge 1 ] && return 0
  [ "$mangle_cm" -ge 1 ] && [ "$nat_dnat" -ge 1 ] && return 0
  [ "$fwd_accept" -ge 1 ] && return 0
  return 1
}

wait_until_passthrough_firewall_disabled() {
  R "i=${PT_FW_POLL_TRIES}; while [ \$i -gt 0 ]; do
    f=\$(iptables-save -t filter 2>/dev/null | grep -E '^-A (FORWARD_Passthrough|FORWARD_Passthrough_In|FORWARD_Passthrough_Out|INPUT_Passthrough) ' | wc -l | tr -d ' ');
    n=\$(iptables-save -t nat 2>/dev/null | grep -E '^-A (PREROUTING_Passthrough|POSTROUTING_Passthrough) ' | wc -l | tr -d ' ');
    m=\$(iptables-save -t mangle 2>/dev/null | grep -E '^-A (PREROUTING_Passthrough|OUTPUT_Passthrough) ' | wc -l | tr -d ' ');
    dm=\$(ubus-cli Firewall.Chain.*.Rule.*.Alias? 2>/dev/null | grep -v '^>' | grep -c 'Alias=\"pt-');
    if [ -z \"\$f\" ]; then f=0; fi; if [ -z \"\$n\" ]; then n=0; fi; if [ -z \"\$m\" ]; then m=0; fi; if [ -z \"\$dm\" ]; then dm=0; fi;
    if [ \"\$f\" = 0 -o \"\$f\" = 2 ] && [ \"\$n\" = 0 ] && [ \"\$m\" = 0 ] && [ \"\$dm\" = 0 ]; then
      echo passthrough-firewall-cleared; exit 0;
    fi;
    i=\$((i-1)); sleep ${PT_FW_POLL_SECS};
  done; exit 1"
}

wait_until_passthrough_firewall_enabled() {
  R "i=${PT_FW_POLL_TRIES}; while [ \$i -gt 0 ]; do
    dm=\$(ubus-cli Firewall.Chain.*.Rule.*.Alias? 2>/dev/null | grep -v '^>' | grep -c 'Alias=\"pt-');
    cm=\$(iptables-save -t mangle 2>/dev/null | grep '^-A PREROUTING_Passthrough ' | grep -E 'CONNMARK|set-mark' | wc -l | tr -d ' ');
    dn=\$(iptables-save -t nat 2>/dev/null | grep '^-A PREROUTING_Passthrough ' | grep -E 'DNAT|REDIRECT' | wc -l | tr -d ' ');
    ac=\$(iptables-save -t filter 2>/dev/null | grep '^-A FORWARD_Passthrough_Out ' | grep ACCEPT | wc -l | tr -d ' ');
    if [ -z \"\$dm\" ]; then dm=0; fi; if [ -z \"\$cm\" ]; then cm=0; fi; if [ -z \"\$dn\" ]; then dn=0; fi; if [ -z \"\$ac\" ]; then ac=0; fi;
    if [ \"\$dm\" -gt 0 ] 2>/dev/null || { [ \"\$cm\" -gt 0 ] 2>/dev/null && [ \"\$dn\" -gt 0 ] 2>/dev/null; } || [ \"\$ac\" -gt 0 ] 2>/dev/null; then
      echo passthrough-firewall-ready; exit 0;
    fi;
    i=\$((i-1)); sleep ${PT_FW_POLL_SECS};
  done; exit 1"
}

assert_passthrough_firewall_disabled() {
  local filter_appends nat_appends mangle_appends forward_jump connmark_jump dm_rules

  filter_appends=$(_pt_fw_filter_passthrough_appends | tr -d '[:space:]')
  nat_appends=$(_pt_fw_nat_passthrough_appends | tr -d '[:space:]')
  mangle_appends=$(_pt_fw_mangle_passthrough_appends | tr -d '[:space:]')
  forward_jump=$(_pt_fw_forward_passthrough_jump_rules | tr -d '[:space:]')
  connmark_jump=$(_pt_fw_connmark_forward_dispatch_rules | tr -d '[:space:]')
  dm_rules=$(_pt_count_dm_passthrough_rules | tr -d '[:space:]')

  filter_appends=${filter_appends:-0}
  nat_appends=${nat_appends:-0}
  mangle_appends=${mangle_appends:-0}
  forward_jump=${forward_jump:-0}
  connmark_jump=${connmark_jump:-0}
  dm_rules=${dm_rules:-0}

  if _pt_fw_filter_disabled_ok "$filter_appends" &&
     [ "$nat_appends" -eq 0 ] && [ "$mangle_appends" -eq 0 ] && [ "$dm_rules" -eq 0 ] &&
     [ "$forward_jump" -ge 1 ] && [ "$connmark_jump" -ge 1 ]; then
    echo passthrough-firewall-disabled
    echo "filter-passthrough-appends=${filter_appends}"
    echo "nat-passthrough-appends=${nat_appends}"
    echo "mangle-passthrough-appends=${mangle_appends}"
    echo "forward-passthrough-jump=${forward_jump}"
    echo "connmark-forward-dispatch=${connmark_jump}"
    echo "dm-passthrough-rules=${dm_rules}"
    return 0
  fi
  echo "assert_passthrough_firewall_disabled: filter=${filter_appends} nat=${nat_appends} mangle=${mangle_appends} forward_jump=${forward_jump} connmark_jump=${connmark_jump} dm_rules=${dm_rules}" >&2
  return 1
}

assert_passthrough_firewall_enabled() {
  local dm_rules mangle_cm nat_dnat fwd_accept

  dm_rules=$(_pt_count_dm_passthrough_rules | tr -d '[:space:]')
  mangle_cm=$(_pt_fw_mangle_prerouting_connmark_rules | tr -d '[:space:]')
  nat_dnat=$(_pt_fw_nat_prerouting_dnat_rules | tr -d '[:space:]')
  fwd_accept=$(_pt_fw_filter_forward_out_accept_rules | tr -d '[:space:]')

  if _pt_fw_passthrough_enabled_ok "$dm_rules" "$mangle_cm" "$nat_dnat" "$fwd_accept"; then
    echo passthrough-firewall-enabled
    echo "dm-passthrough-rules=${dm_rules:-0}"
    echo "mangle-prerouting-connmark=${mangle_cm:-0}"
    echo "nat-prerouting-dnat=${nat_dnat:-0}"
    echo "filter-forward-out-accept=${fwd_accept:-0}"
    return 0
  fi
  echo "assert_passthrough_firewall_enabled: dm_rules=${dm_rules:-0} connmark=${mangle_cm:-0} dnat=${nat_dnat:-0} accept=${fwd_accept:-0}" >&2
  return 1
}

wait_until_passthrough_enable() {
  _pt_require_dm || return 1
  R "i=30; while [ \$i -gt 0 ]; do
    line=\$(ubus-cli ${PT_DM_ROOT}.1.Enable? 2>&1 | grep -v '^>' | grep '=');
    echo \"\$line\" | grep -q 'Enable=${1}' && echo \"\$line\" && exit 0;
    i=\$((i-1)); sleep 2;
  done; exit 1"
}

wait_until_passthrough_status_enabled() {
  _pt_require_dm || return 1
  R "i=60; while [ \$i -gt 0 ]; do
    line=\$(ubus-cli ${PT_DM_ROOT}.1.Status? 2>&1 | grep -v '^>' | grep '=');
    echo \"\$line\" | grep -q 'Status=\"Enabled\"' && echo \"\$line\" && exit 0;
    i=\$((i-1)); sleep 5;
  done; exit 1"
}

wait_until_passthrough_status_disabled() {
  _pt_require_dm || return 1
  R "i=30; while [ \$i -gt 0 ]; do
    line=\$(ubus-cli ${PT_DM_ROOT}.1.Status? 2>&1 | grep -v '^>' | grep '=');
    echo \"\$line\" | grep -q 'Status=\"Disabled\"' && echo \"\$line\" && exit 0;
    i=\$((i-1)); sleep 2;
  done; exit 1"
}

wait_until_wan_ipv4_available() {
  R "i=60; while [ \$i -gt 0 ]; do
    ip=\$(ubus-cli Device.DHCPv4.Client.1.IPAddress? 2>/dev/null | grep -v '^>' | sed -n 's/.*=\"\\([^\"]*\\)\"/\\1/p');
    if [ -z \"\$ip\" ]; then
      ip=\$(ubus-cli ${PT_LOGICAL_WAN_IF}X_PRPLWARE-COM_WAN.IPv4Address? 2>/dev/null | grep -v '^>' | sed -n 's/.*=\"\\([^\"]*\\)\"/\\1/p');
    fi;
    if [ -n \"\$ip\" ]; then echo \"wan-ipv4-ready=\$ip\"; exit 0; fi;
    i=\$((i-1)); sleep 5;
  done; exit 1"
}

verify_passthrough_firewall_chains_present() {
  R "ubus-cli Firewall.Chain.*.Name? 2>/dev/null | grep -v '^>' | grep -q 'Name=\"FORWARD_Passthrough\"' && echo passthrough-firewall-chains-present"
}

apply_passthrough_disable() {
  _pt_require_dm || return 1
  R "ubus-cli ${PT_DM_ROOT}.1.Enable=0 2>&1 | grep -v '^>' | grep -q Device.IP && echo passthrough-disable-applied"
}

apply_passthrough_enable() {
  _pt_require_dm || return 1
  R "ubus-cli ${PT_DM_ROOT}.1.Enable=1 2>&1 | grep -v '^>' | grep -q Device.IP && echo passthrough-enable-applied"
}

apply_passthrough_dhcps_fixed_mode() {
  _pt_require_dm || return 1
  R "ubus-cli ${PT_DM_ROOT}.1.Mode=\"${PT_MODE_FIXED}\" 2>&1 | grep -v '^>' | grep -q Device.IP && echo passthrough-mode-dhcps-fixed"
}

apply_passthrough_dhcps_dynamic_mode() {
  _pt_require_dm || return 1
  R "ubus-cli ${PT_DM_ROOT}.1.Mode=\"${PT_MODE_DYNAMIC}\" 2>&1 | grep -v '^>' | grep -q Device.IP && echo passthrough-mode-dhcps-dynamic"
}

apply_passthrough_clear_client_mac() {
  _pt_require_dm || return 1
  R "ubus-cli ${PT_DM_ROOT}.1.ClientMACAddress=\"\" 2>&1 | grep -v '^>' | grep -q Device.IP && echo passthrough-client-mac-cleared"
}

apply_passthrough_client_mac() {
  local mac="${1:-$PT_SYNTHETIC_MAC}"
  _pt_require_dm || return 1
  R "ubus-cli ${PT_DM_ROOT}.1.ClientMACAddress=\"${mac}\" 2>&1 | grep -v '^>' | grep -q Device.IP && echo passthrough-client-mac-configured"
}

apply_passthrough_synthetic_client_mac() {
  apply_passthrough_client_mac "$PT_SYNTHETIC_MAC"
}

reset_passthrough_to_defaults() {
  apply_passthrough_disable
  wait_until_passthrough_enable 0 >/dev/null
  wait_until_passthrough_status_disabled >/dev/null
  sleep 5
  if ! wait_until_passthrough_firewall_disabled >/dev/null; then
    apply_passthrough_disable >/dev/null 2>&1
    sleep 10
    wait_until_passthrough_firewall_disabled >/dev/null
  fi
  apply_passthrough_dhcps_dynamic_mode
  apply_passthrough_clear_client_mac
  echo passthrough-reset-to-defaults
}

# --- Security (rp_filter + IPv4SpoofingProtection) ---

read_rp_filter_all() {
  R "cat /proc/sys/net/ipv4/conf/all/rp_filter 2>/dev/null" | tr -d '[:space:]'
}

read_rp_filter_lan() {
  local dev="${1:-br-lan}"
  R "cat /proc/sys/net/ipv4/conf/${dev}/rp_filter 2>/dev/null" | tr -d '[:space:]'
}

show_lan_ipv4_spoofing_protection() {
  # ubus-cli [Alias=='lan'] is not implemented on this image; resolve lan index first.
  local idx
  idx=$(
    R "ubus-cli Device.Firewall.InterfaceSetting.*.Alias?" 2>&1 |
      _filter_ubus_device_lines |
      grep 'Alias="lan"' |
      sed -n 's/.*InterfaceSetting\.\([0-9]*\)\.Alias=.*/\1/p' |
      head -1
  )
  R "ubus-cli Device.Firewall.InterfaceSetting.${idx}.IPv4SpoofingProtection?" 2>&1 |
    _filter_ubus_device_lines | grep 'IPv4SpoofingProtection='
}

assert_rp_filter_when_pt_enabled() {
  local rp_all rp_lan
  rp_all=$(read_rp_filter_all)
  rp_lan=$(read_rp_filter_lan br-lan)
  echo "rp-filter-all=${rp_all:-empty}"
  echo "rp-filter-lan=${rp_lan:-empty}"
  if [ "$rp_all" = "0" ]; then
    echo passthrough-rp-filter-disabled-when-enabled
    return 0
  fi
  echo "assert_rp_filter_when_pt_enabled: expected all=0 got all=${rp_all} lan=${rp_lan}" >&2
  return 1
}

assert_rp_filter_restored_when_pt_disabled() {
  local rp_all
  rp_all=$(read_rp_filter_all)
  echo "rp-filter-all=${rp_all:-empty}"
  if [ "$rp_all" = "1" ]; then
    echo passthrough-rp-filter-restored-when-disabled
    return 0
  fi
  echo "assert_rp_filter_restored_when_pt_disabled: expected all=1 got all=${rp_all}" >&2
  return 1
}

assert_lan_ipv4_spoofing_protection_enabled() {
  show_lan_ipv4_spoofing_protection | grep -q 'IPv4SpoofingProtection=1' &&
    echo passthrough-lan-spoofing-protection-enabled
}

# --- 2-node helpers (runner = TARGET_LAN_TEST_HOST / TESTBED_LAN_INTERFACE) ---
# Same variables as .gitlab/testbed.yml and 015-nat-portmapping.t.

pt_cram_runner_lan_mac() {
  local ifc="${TESTBED_LAN_INTERFACE:-enp2s0}"
  ip link show "$ifc" 2>/dev/null | awk '/link\/ether/ {print $2; exit}'
}

pt_cram_verify_runner_lan_reachable() {
  local host="${TARGET_LAN_TEST_HOST:-192.168.1.2}"
  ping -c3 -W1 "$host"
}

pt_cram_bind_runner_public_ip() {
  local pub_ip="$1"
  local ifc="${TESTBED_LAN_INTERFACE:-enp2s0}"
  [ -n "$pub_ip" ] || return 1
  sudo ip addr add "${pub_ip}/32" dev "$ifc" 2>/dev/null || true
  echo passthrough-runner-bound-public-ip
}

pt_cram_unbind_runner_public_ip() {
  local pub_ip="$1"
  local ifc="${TESTBED_LAN_INTERFACE:-enp2s0}"
  [ -n "$pub_ip" ] || return 0
  sudo ip addr del "${pub_ip}/32" dev "$ifc" 2>/dev/null || true
  echo passthrough-runner-unbound-public-ip
}

read_passthrough_pool_public_ip() {
  local pool_index
  pool_index=$(resolve_passthrough_dhcp_pool_index)
  [ -n "$pool_index" ] || return 1
  R "ubus-cli Device.DHCPv4.Server.Pool.${pool_index}.MinAddress?" 2>&1 |
    _filter_ubus_device_lines |
    sed -n 's/.*="\([^"]*\)"/\1/p'
}

# --- ODL + FIB/route assertions (prpl guidance: focus on DM/ODL output + board routes) ---

assert_odl_mode_enum_on_dut() {
  # Product definition must ship BBF 2.22 Mode enum on the board.
  R "grep -E 'DHCPServerFixed|DHCPServerDynamic' /etc/amx/tr181-passthrough/tr181-passthrough_definition.odl 2>/dev/null | head -3" |
    grep -q DHCPServerFixed && echo odl-mode-enum-bbf-present
}

assert_passthrough_policy_fib_enabled() {
  # Policy rule: from <P> iif br-lan lookup <T> (typically table 100).
  local rules routes g32
  rules=$(R "ip -4 rule list 2>/dev/null | grep -E 'iif br-lan.*lookup' | head -5" | tr '\n' ' ')
  routes=$(R "ip -4 route show table 100 2>/dev/null; ip -4 route show table all 2>/dev/null | grep -E 'table 10[0-9]' | head -10" | tr '\n' ' ')
  g32=$(R "ip -4 addr show br-lan 2>/dev/null | grep -E 'inet .*/32' || true" | tr '\n' ' ')
  echo "policy-rules=${rules:-none}"
  echo "policy-routes=${routes:-none}"
  echo "lan-slash32=${g32:-none}"
  echo "$rules" | grep -q 'iif br-lan' || {
    echo "assert_passthrough_policy_fib_enabled: missing iif br-lan policy rule" >&2
    return 1
  }
  echo "$routes" | grep -qE 'default.*(via|dev)' || {
    echo "assert_passthrough_policy_fib_enabled: missing policy-table default" >&2
    return 1
  }
  echo "$g32" | grep -q '/32' || {
    echo "assert_passthrough_policy_fib_enabled: missing public-lan G/32 on br-lan" >&2
    return 1
  }
  echo passthrough-policy-fib-enabled
}

assert_passthrough_policy_fib_cleared() {
  local rules g32
  rules=$(R "ip -4 rule list 2>/dev/null | grep -E 'iif br-lan.*lookup' || true")
  g32=$(R "ip -4 addr show br-lan 2>/dev/null | grep -E 'inet 192\.168\.0\.[0-9]+/32' || true" | tr '\n' ' ')
  echo "policy-rules-after-disable=${rules:-none}"
  echo "lan-slash32-after-disable=${g32:-none}"
  # Soft: some platforms leave empty table; rule and G/32 must not remain for PT client.
  if echo "$rules" | grep -q 'iif br-lan' && echo "$g32" | grep -q '/32'; then
    echo "assert_passthrough_policy_fib_cleared: stale policy+G/32 after disable" >&2
    return 1
  fi
  echo passthrough-policy-fib-cleared
}

show_passthrough_northbound_refs() {
  # One path per ubus-cli call — multi-path get returns empty/errors on this Ambiorix build.
  _pt_require_dm || return 1
  {
    R "ubus-cli ${PT_DM_ROOT}.1.SourceInterface?" 2>&1
    R "ubus-cli ${PT_DM_ROOT}.1.DestinationInterface?" 2>&1
    R "ubus-cli ${PT_DM_ROOT}.1.RouterRef?" 2>&1
    R "ubus-cli ${PT_DM_ROOT}.1.Status?" 2>&1
    R "ubus-cli ${PT_DM_ROOT}.1.Mode?" 2>&1
  } | _filter_ubus_device_lines | grep '^Device.IP' | LC_ALL=C sort
}
