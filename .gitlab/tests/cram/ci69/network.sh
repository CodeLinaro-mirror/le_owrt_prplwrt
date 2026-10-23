# SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation
# Prepared by AI Codex for CI-69.
# Save the policy flag instead of assuming every caller starts with it enabled.
save_firewall() {
    firewall_enable=$(R "ba-cli -j -l 'Device.Firewall.Enable?'" |
        jq -er '.[0][] | .Enable | tostring') || return
}

cleanup_network() {
    R "ba-cli 'Device.Firewall.Enable=$firewall_enable'" >/dev/null || return
    R "ba-cli -j -l 'Device.Firewall.Enable?'" |
        jq -e --arg enabled "$firewall_enable" '.[0][] | (.Enable | tostring) == $enabled' >/dev/null
}

# Save the active LAN prefix and the address generated from it.
save_lan_prefix() {
    lan_prefix_path=$(R "ba-cli -j -l '${lan_ref}.IPv6Prefix.*.?'" |
        jq -er --arg prefix "$TESTBED_LAN_PREFIX" '
            [.[0] | to_entries[] | select(.value.Prefix == $prefix)] |
            .[0].key | ltrimstr("Device.")') || return
    lan_prefix_enable=$(R "ba-cli -j -l '${lan_prefix_path}Enable?'" |
        jq -er '.[0][] | .Enable | tostring') || return
    lan_address_path=$(R "ba-cli -j -l '${lan_ref}.IPv6Address.*.?'" |
        jq -er --arg prefix "Device.${lan_prefix_path%.}" '
            [.[0] | to_entries[] |
             select((.value.Prefix // "" | rtrimstr(".")) == $prefix)] |
            .[0].key | ltrimstr("Device.")') || return
    lan_ra_path=$(R "ba-cli -j -l 'RouterAdvertisement.InterfaceSetting.*.?'" |
        jq -er --arg interface "$lan_ref" '
            [.[0] | to_entries[] |
             select((.value.Interface // "" | rtrimstr(".")) == $interface)] |
            .[0].key') || return
    lan_manual_prefixes=$(R "ba-cli -j -l '${lan_ra_path}ManualPrefixes?'" |
        jq -er '.[0][] | .ManualPrefixes') || return
}

cleanup_npt() {
    cleanup_status=0
    if [ -n "${npt_created:-}" ]; then
        R "ba-cli 'NAT.NPTv6.InterfaceSetting.[Alias==\"ci69\"].-'" >/dev/null || cleanup_status=1
        if [ "$cleanup_status" -eq 0 ]; then unset npt_created; fi
    fi
    if [ -n "${lan_switched:-}" ]; then
        R "ba-cli '${lan_ra_path}ManualPrefixes=\"$lan_manual_prefixes\"'" >/dev/null || cleanup_status=1
        R "ba-cli '${lan_address_path}Prefix=\"Device.${lan_prefix_path%.}\"'" >/dev/null || cleanup_status=1
        R "ba-cli '${lan_prefix_path}Enable=$lan_prefix_enable'" >/dev/null || cleanup_status=1
        R "ba-cli -j -l '${lan_ra_path}ManualPrefixes?'" |
            jq -e --arg prefixes "$lan_manual_prefixes" '.[0][] | .ManualPrefixes == $prefixes' >/dev/null || cleanup_status=1
        if [ "$cleanup_status" -eq 0 ]; then unset lan_switched; fi
    fi
    if [ -n "${static_created:-}" ]; then
        R "ba-cli '${lan_ref}.IPv6Prefix.[Alias==\"ci69\"].-'" >/dev/null || cleanup_status=1
        if [ "$cleanup_status" -eq 0 ]; then unset static_created; fi
    fi
    cleanup_network || cleanup_status=1
    return "$cleanup_status"
}
