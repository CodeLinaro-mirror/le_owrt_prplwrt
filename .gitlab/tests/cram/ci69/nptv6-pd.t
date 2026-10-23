Follow a delegated prefix through the vendor ExternalPrefixRef parameter.
Kea changes the PD pool; the DHCPv6 client renews through the datamodel.
The NPT setting must keep the same reference and adopt the newly delegated /60.
LAN addressing stays static, and the firewall remains enabled during traffic checks.

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias V6='python3 "$TESTDIR/ipv6.py"'
  $ . "$TESTDIR/network.sh"
  $ wait_pd() {
  >   for attempt in $(seq 1 45); do
  >     R "ba-cli -j -l '${pd_ref}.Prefix?'" |
  >       jq -e --arg prefix "$1" '.[0][] | .Prefix == $prefix' >/dev/null && return 0
  >     sleep 1
  >   done
  >   echo "Delegated prefix did not become $1" >&2; return 1
  > }
  $ cleanup_pd_npt() {
  >   cleanup_result=0
  >   if [ -n "${kea_changed:-}" ]; then
  >     V6 kea config-set "$(cat "$CRAMTMP/kea-original.json")" >/dev/null &&
  >       R "ba-cli '${dhcp_ref}.Renew()'" >/dev/null &&
  >       wait_pd "$TESTBED_PD_PREFIX" || cleanup_result=1
  >   fi
  >   cleanup_npt || cleanup_result=1
  >   return "$cleanup_result"
  > }
  $ save_firewall || exit 1
  $ V6 kea config-get | jq -e '.arguments | {Dhcp6}' > "$CRAMTMP/kea-original.json" || exit 1
  $ trap cleanup_pd_npt EXIT
  $ V6 wait-lan > "$CRAMTMP/lan.env" || exit 1
  $ . "$CRAMTMP/lan.env"

Find the interfaces and save the LAN prefix/address association.

  $ wan_ref=$(R "ba-cli -j -l 'Device.IP.Interface.[Name==\"eth1\"].Name?'" |
  >   jq -er '.[0] | keys[0] | rtrimstr(".")') || exit 1
  $ lan_ref=$(R "ba-cli -j -l 'Device.IP.Interface.[Name==\"br-lan\"].Name?'" |
  >   jq -er '.[0] | keys[0] | rtrimstr(".")') || exit 1
  $ save_lan_prefix || exit 1

Replace the delegated LAN subnet with a static benchmark /64 through the datamodel.
The existing auto-configured router address follows the new prefix.
RA advertises this /64, while NPT translates the encompassing /60.

  $ internal_prefix=2001:2:0:6900::/60
  $ lan_prefix=2001:2:0:6902::/64
  $ R "ba-cli '${lan_ref}.IPv6Prefix+{Alias=\"ci69\",Enable=true,Prefix=\"$lan_prefix\",OnLink=true,Autonomous=true}'" >/dev/null
  $ static_created=true
  $ static_ref=$(R "ba-cli -j -l '${lan_ref}.IPv6Prefix.[Alias==\"ci69\"].Prefix?'" | jq -er '.[0] | keys[0] | rtrimstr(".")')
  $ lan_switched=true
  $ R "ba-cli '${lan_prefix_path}Enable=false'" >/dev/null
  $ R "ba-cli '${lan_address_path}Prefix=\"$static_ref\"'" >/dev/null
  $ R "ba-cli '${lan_ra_path}ManualPrefixes=\"$static_ref.\"'" >/dev/null
  $ R "ba-cli -j -l '${lan_prefix_path}Enable?'" | jq -e '.[0][] | .Enable == 0 or .Enable == false' >/dev/null
  $ R "ba-cli -j -l '${lan_address_path}Prefix?'" | jq -e --arg prefix "$static_ref" '.[0][] | .Prefix == $prefix' >/dev/null
  $ V6 wait-lan --prefix "$lan_prefix" > "$CRAMTMP/lan.env" || exit 1
  $ . "$CRAMTMP/lan.env"

Find the current delegated prefix and the DHCPv6 client on its WAN interface.

  $ pd_ref=$(R "ba-cli -j -l '${wan_ref}.IPv6Prefix.[Origin==\"PrefixDelegation\"].Prefix?'" |
  >   jq -er --arg prefix "$TESTBED_PD_PREFIX" '.[0] | to_entries[] | select(.value.Prefix == $prefix) | .key | rtrimstr(".")') || exit 1
  $ dhcp_ref=$(R "ba-cli -j -l 'Device.DHCPv6.Client.[Interface==\"$wan_ref\"].Enable?'" |
  >   jq -er '.[0] | keys[0] | rtrimstr(".")') || exit 1

Configure only the reference, without writing ExternalPrefix or Interface.
The firewall must obtain both from the referenced object.

  $ R "ba-cli 'Device.Firewall.Enable=true'" >/dev/null
  $ R "ba-cli 'NAT.NPTv6.InterfaceSetting+{Alias=\"ci69\",Enable=true,X_PRPLWARE-COM_ExternalPrefixRef=\"$pd_ref\",X_PRPLWARE-COM_InternalInterfaces=\"$lan_ref\",InternalPrefix=\"$internal_prefix\"}'" >/dev/null
  $ npt_created=true
  $ wait_npt_prefix() {
  >   for attempt in $(seq 1 5); do
  >     rules=$(R 'ip6tables-save -t mangle') || return
  >     if printf '%s\n' "$rules" | grep -- '-j SNPT' | grep -q -- "--dst-pfx $1" &&
  >        printf '%s\n' "$rules" | grep -- '-j DNPT' | grep -q -- "--src-pfx $1"; then return 0; fi
  >     sleep 1
  >   done
  >   echo "NPT rules did not adopt $1" >&2; return 1
  > }
  $ wait_npt_prefix "$TESTBED_PD_PREFIX" || exit 1
  $ R "ba-cli -j -l 'NAT.NPTv6.InterfaceSetting.[Alias==\"ci69\"].?'" |
  >   jq -e --arg prefix "$TESTBED_PD_PREFIX" --arg interface "$wan_ref" '.[0][] | .ExternalPrefix == $prefix and .Interface == $interface and .Status == "Enabled"' >/dev/null
  $ ready=false; for attempt in $(seq 1 5); do
  >   rules=$(R 'ip6tables -t filter -S FORWARD6_Firewall_Enable') || exit 1
  >   if ! printf '%s\n' "$rules" | grep -q -- '-j ACCEPT'; then ready=true; break; fi
  >   sleep 1
  > done; "$ready"
  $ V6 tcp lan-to-wan --source "$TESTBED_LAN_CLIENT_ADDRESS" --expect-peer-prefix "$TESTBED_PD_PREFIX" --check-conntrack
  Conntrack established and reply tuple verified
  TCP payload and echo verified

Replace Kea's /60 pool, then request a DHCPv6 renewal.
Allow a complete T1 interval for DHCP state to settle.
Rule regeneration has its own five-second wait.

  $ new_prefix=2001:2:0:9700::/60
  $ jq --arg prefix "${new_prefix%/*}" '.Dhcp6.subnet6[0]["pd-pools"][0].prefix = $prefix' "$CRAMTMP/kea-original.json" > "$CRAMTMP/kea-new.json"
  $ kea_changed=true
  $ V6 kea config-set "$(cat "$CRAMTMP/kea-new.json")" | jq -r .result
  0
  $ R "ba-cli '${dhcp_ref}.Renew()'" >/dev/null
  $ wait_pd "$new_prefix" || exit 1
  $ wait_npt_prefix "$new_prefix" || exit 1

The same reference now supplies the new prefix; old NPT rules must be gone.
Kea's lease hook must route replies through the DUT for the new prefix.

  $ R "ba-cli -j -l 'NAT.NPTv6.InterfaceSetting.[Alias==\"ci69\"].?'" |
  >   jq -e --arg prefix "$new_prefix" --arg ref "$pd_ref" --arg interface "$wan_ref" '.[0][] | .ExternalPrefix == $prefix and .["X_PRPLWARE-COM_ExternalPrefixRef"] == $ref and .Interface == $interface and .Status == "Enabled"' >/dev/null
  $ ! R 'ip6tables-save -t mangle' | grep -F -- "$TESTBED_PD_PREFIX"
  $ V6 tcp lan-to-wan --source "$TESTBED_LAN_CLIENT_ADDRESS" --expect-peer-prefix "$new_prefix" --check-conntrack
  Conntrack established and reply tuple verified
  TCP payload and echo verified

Restore the original Kea pool and DUT configuration for subsequent tests.

  $ cleanup_pd_npt || exit 1
  $ trap - EXIT
