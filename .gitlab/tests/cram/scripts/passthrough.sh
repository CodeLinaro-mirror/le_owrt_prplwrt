#
# tr181-passthrough cram helpers (source from cram/*.t: . "${TESTDIR}/scripts/passthrough.sh")
# Requires: alias R="${CRAM_REMOTE_COMMAND:-}" before sourcing.
#
# Naming:
#   show_*    — dump DM trees/fields for cram expected output
#   read_*    — read a single parameter value
#   resolve_* — find dynamic instance index (e.g. pool by alias)
#   apply_*   — write configuration on the DUT
#   wait_until_* — poll until a condition is met
#   verify_* / assert_* — checks; echo a stable token on success
#   wait_until_passthrough_firewall_* — poll iptables-save until rules appear/clear
#

PT_POOL_ALIAS_PRIMARY="cpe-passthrough"
PT_FW_POLL_SECS=2
PT_FW_POLL_TRIES=30
PT_POOL_ALIAS_LEGACY="cpe_passthrough"
PT_SYNTHETIC_MAC="AA:BB:CC:DD:EE:FF"
PT_LOGICAL_WAN_IF="Device.Logical.Interface.1."

_filter_ubus_device_lines() {
  grep -v '^>' | grep '^Device\.' | sed '/^$/d'
}

# Return Pool.{i} index where Alias is cpe-passthrough (or legacy cpe_passthrough).
resolve_cpe_passthrough_pool_index() {
  R "ubus-cli Device.DHCPv4.Server.Pool.*.Alias?" 2>&1 |
    _filter_ubus_device_lines |
    grep -E "Alias=\"(${PT_POOL_ALIAS_PRIMARY}|${PT_POOL_ALIAS_LEGACY})\"" |
    sed -n 's/.*Pool\.\([0-9]*\).*/\1/p' |
    head -1
}

# Pool the passthrough manager uses: Alias Passthrough, then cpe-passthrough, then Pool.5.
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
  R "ubus-cli Device.IP.X_PRPLWARE-COM_Passthrough.?" 2>&1 |
    _filter_ubus_device_lines | grep '^Device.IP' | LC_ALL=C sort
}

read_logical_wan_ipv4() {
  R "ubus-cli ${PT_LOGICAL_WAN_IF}X_PRPLWARE-COM_WAN.IPv4Address?" 2>&1 |
    _filter_ubus_device_lines |
    sed -n 's/.*="\([^"]*\)"/\1/p'
}

read_passthrough_enable() {
  R "ubus-cli Device.IP.X_PRPLWARE-COM_Passthrough.1.Enable?" 2>&1 |
    _filter_ubus_device_lines | grep '='
}

read_passthrough_status() {
  R "ubus-cli Device.IP.X_PRPLWARE-COM_Passthrough.1.Status?" 2>&1 |
    _filter_ubus_device_lines | grep '='
}

read_passthrough_client_mac() {
  R "ubus-cli Device.IP.X_PRPLWARE-COM_Passthrough.1.ClientMACAddress?" 2>&1 |
    _filter_ubus_device_lines | grep '='
}

read_passthrough_mode() {
  R "ubus-cli Device.IP.X_PRPLWARE-COM_Passthrough.1.Mode?" 2>&1 |
    _filter_ubus_device_lines | grep '='
}

# Full Pool.{i}.? dump while passthrough is disabled (factory/default pool state).
show_cpe_passthrough_pool_datamodel_defaults() {
  local pool_index
  pool_index=$(resolve_passthrough_dhcp_pool_index)
  if [ -z "$pool_index" ]; then
    echo "show_cpe_passthrough_pool_datamodel_defaults: pool alias not found" >&2
    return 1
  fi
  R "ubus-cli Device.DHCPv4.Server.Pool.${pool_index}.?" 2>&1 |
    _filter_ubus_device_lines |
    grep -vE "Device\\.DHCPv4\\.Server\\.Pool\\.${pool_index}\\.Option\\.[0-9]+\\." |
    LC_ALL=C sort
}

# Key cpe-passthrough pool fields after passthrough enable.
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

# Assert Logical.Interface WAN IPv4Address == Pool MinAddress == Pool MaxAddress.
assert_logical_wan_ipv4_matches_pool_min_max() {
  local pool_index wan_line min_line max_line wan_ipv4 pool_min pool_max
  pool_index=$(resolve_passthrough_dhcp_pool_index)
  if [ -z "$pool_index" ]; then
    echo "assert_logical_wan_ipv4_matches_pool_min_max: pool alias not found" >&2
    return 1
  fi
  wan_line=$(R "ubus-cli ${PT_LOGICAL_WAN_IF}X_PRPLWARE-COM_WAN.IPv4Address?" 2>&1 | _filter_ubus_device_lines)
  min_line=$(R "ubus-cli Device.DHCPv4.Server.Pool.${pool_index}.MinAddress?" 2>&1 | _filter_ubus_device_lines)
  max_line=$(R "ubus-cli Device.DHCPv4.Server.Pool.${pool_index}.MaxAddress?" 2>&1 | _filter_ubus_device_lines)
  echo "$wan_line"
  echo "$min_line"
  echo "$max_line"
  wan_ipv4=$(echo "$wan_line" | sed -n 's/.*="\([^"]*\)"/\1/p')
  pool_min=$(echo "$min_line" | sed -n 's/.*="\([^"]*\)"/\1/p')
  pool_max=$(echo "$max_line" | sed -n 's/.*="\([^"]*\)"/\1/p')
  if [ -n "$wan_ipv4" ] && [ "$wan_ipv4" = "$pool_min" ] && [ "$wan_ipv4" = "$pool_max" ]; then
    echo logical-wan-ipv4-matches-pool-min-max
    return 0
  fi
  echo "assert_logical_wan_ipv4_matches_pool_min_max: mismatch wan='${wan_ipv4}' min='${pool_min}' max='${pool_max}'" >&2
  return 1
}

# --- Passthrough firewall (iptables-save); all R commands must be single-line. ---

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

# Disabled baseline: empty passthrough chains (0) or static In/Out call rules (2).
_pt_fw_filter_disabled_ok() {
  case "$1" in
    0|2) return 0 ;;
    *) return 1 ;;
  esac
}

# Passthrough manager rules are named pt-* in TR-181 Firewall.Chain objects.
_pt_count_dm_passthrough_rules() {
  _pt_fw_remote_count "ubus-cli Firewall.Chain.*.Rule.*.Alias? 2>/dev/null | grep -v '^>' | grep -c 'Alias=\"pt-'"
}

# Enabled when pt-* DM rules exist and/or direct iptables rules in passthrough chains.
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

# Passthrough disabled: no pt-* manager rules; static chain jump rules remain.
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
  R "ubus-cli Firewall.Chain.*.Rule.*.Alias? 2>/dev/null | grep -v '^>' | grep 'Alias=\"pt-'" >&2 || true
  return 1
}

# Passthrough enabled: pt-* DM rules and/or direct iptables in static passthrough chains.
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
  R "i=30; while [ \$i -gt 0 ]; do
    line=\$(ubus-cli Device.IP.X_PRPLWARE-COM_Passthrough.1.Enable? 2>&1 | grep -v '^>' | grep '=');
    echo \"\$line\" | grep -q 'Enable=${1}' && echo \"\$line\" && exit 0;
    i=\$((i-1)); sleep 2;
  done; exit 1"
}

wait_until_passthrough_status_active() {
  R "i=30; while [ \$i -gt 0 ]; do
    line=\$(ubus-cli Device.IP.X_PRPLWARE-COM_Passthrough.1.Status? 2>&1 | grep -v '^>' | grep '=');
    echo \"\$line\" | grep -Eq 'Status=\"(Enabled|Pending|Error|Error_Misconfigured)\"' && echo \"\$line\" && exit 0;
    i=\$((i-1)); sleep 2;
  done; exit 1"
}

wait_until_passthrough_status_enabled() {
  R "i=60; while [ \$i -gt 0 ]; do
    line=\$(ubus-cli Device.IP.X_PRPLWARE-COM_Passthrough.1.Status? 2>&1 | grep -v '^>' | grep '=');
    echo \"\$line\" | grep -q 'Status=\"Enabled\"' && echo \"\$line\" && exit 0;
    i=\$((i-1)); sleep 5;
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

wait_until_passthrough_status_disabled() {
  R "i=30; while [ \$i -gt 0 ]; do
    line=\$(ubus-cli Device.IP.X_PRPLWARE-COM_Passthrough.1.Status? 2>&1 | grep -v '^>' | grep '=');
    echo \"\$line\" | grep -q 'Status=\"Disabled\"' && echo \"\$line\" && exit 0;
    i=\$((i-1)); sleep 2;
  done; exit 1"
}

apply_passthrough_disable() {
  R "ubus-cli Device.IP.X_PRPLWARE-COM_Passthrough.1.Enable=0 2>&1 | grep -v '^>' | grep -q Device.IP && echo passthrough-disable-applied"
}

apply_passthrough_enable() {
  R "ubus-cli Device.IP.X_PRPLWARE-COM_Passthrough.1.Enable=1 2>&1 | grep -v '^>' | grep -q Device.IP && echo passthrough-enable-applied"
}

apply_passthrough_dhcps_fixed_mode() {
  R "ubus-cli Device.IP.X_PRPLWARE-COM_Passthrough.1.Mode=\"DHCPS-fixed\" 2>&1 | grep -v '^>' | grep -q Device.IP && echo passthrough-mode-dhcps-fixed"
}

apply_passthrough_dhcps_dynamic_mode() {
  R "ubus-cli Device.IP.X_PRPLWARE-COM_Passthrough.1.Mode=\"DHCPS-dynamic\" 2>&1 | grep -v '^>' | grep -q Device.IP && echo passthrough-mode-dhcps-dynamic"
}

apply_passthrough_clear_client_mac() {
  R "ubus-cli Device.IP.X_PRPLWARE-COM_Passthrough.1.ClientMACAddress=\"\" 2>&1 | grep -v '^>' | grep -q Device.IP && echo passthrough-client-mac-cleared"
}

apply_passthrough_synthetic_client_mac() {
  R "ubus-cli Device.IP.X_PRPLWARE-COM_Passthrough.1.ClientMACAddress=\"${PT_SYNTHETIC_MAC}\" 2>&1 | grep -v '^>' | grep -q Device.IP && echo passthrough-client-mac-configured"
}

# Idempotent reset after a prior cram run or manual enable (disable → defaults → firewall baseline).
reset_passthrough_to_defaults() {
  apply_passthrough_disable
  wait_until_passthrough_enable 0
  wait_until_passthrough_status_disabled
  sleep 5
  if ! wait_until_passthrough_firewall_disabled >/dev/null; then
    R "ubus-cli Device.IP.X_PRPLWARE-COM_Passthrough.1.Enable=0" >/dev/null 2>&1
    sleep 10
    wait_until_passthrough_firewall_disabled >/dev/null
  fi
  apply_passthrough_dhcps_dynamic_mode
  apply_passthrough_clear_client_mac
  echo passthrough-reset-to-defaults
}
