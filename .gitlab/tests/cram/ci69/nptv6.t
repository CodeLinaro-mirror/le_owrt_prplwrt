Example NPTv6 test using the Kea/LAN fixture.
Requires firmware with NAT.NPTv6 and working kernel SNPT/DNPT support.
The DUT obtains PD with its normal DHCPv6 configuration.
The LAN client obtains its address and default route from the DUT's RA.

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias V6='python3 "$TESTDIR/ipv6.py"'
  $ . "$TESTDIR/network.sh"
  $ save_firewall || exit 1
  $ trap cleanup_npt EXIT
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

ExternalPrefix is a literal CIDR, explicitly set to the delegated /60.
First check translation and the return path with filtering disabled.

  $ R "ba-cli 'Device.Firewall.Enable=false'" >/dev/null
  $ R "ba-cli 'NAT.NPTv6.InterfaceSetting+{Alias=\"ci69\",Enable=true,Interface=\"$wan_ref\",X_PRPLWARE-COM_InternalInterfaces=\"$lan_ref\",InternalPrefix=\"$internal_prefix\",ExternalPrefix=\"$TESTBED_PD_PREFIX\"}'" >/dev/null
  $ npt_created=true

Wait for both translation targets.

  $ ready=false; for attempt in $(seq 1 5); do
  >   rules=$(R 'ip6tables-save -t mangle')
  >   if printf '%s\n' "$rules" | grep -- '-j SNPT' | grep -q -- "--src-pfx $internal_prefix" && printf '%s\n' "$rules" | grep -- '-j DNPT' | grep -q -- "--dst-pfx $internal_prefix"; then ready=true; break; fi
  >   sleep 1
  > done; "$ready"

Bind TCP to the new SLAAC address, since the previous address may remain valid.
The WAN server must observe a source from the external /60 and return the payload.

  $ V6 tcp lan-to-wan --source "$TESTBED_LAN_CLIENT_ADDRESS" --expect-peer-prefix "$TESTBED_PD_PREFIX"
  TCP payload and echo verified

Enable the firewall and wait for the forwarding bypass to disappear.
LAN-to-WAN TCP and its replies must pass the normal stateful policy.
Check the live conntrack entry against the translated source observed on WAN.

  $ R "ba-cli 'Device.Firewall.Enable=true'" >/dev/null
  $ R "ba-cli -j -l 'Device.Firewall.Enable?'" | jq -e '.[0][] | .Enable == 1 or .Enable == true' >/dev/null
  $ ready=false; for attempt in $(seq 1 5); do
  >   rules=$(R 'ip6tables -t filter -S FORWARD6_Firewall_Enable') || exit 1
  >   if ! printf '%s\n' "$rules" | grep -q -- '-j ACCEPT'; then ready=true; break; fi
  >   sleep 1
  > done; "$ready"
  $ V6 tcp lan-to-wan --source "$TESTBED_LAN_CLIENT_ADDRESS" --expect-peer-prefix "$TESTBED_PD_PREFIX" --check-conntrack
  Conntrack established and reply tuple verified
  TCP payload and echo verified

  $ cleanup_npt || exit 1
  $ R "ba-cli -j -l '${lan_prefix_path}Enable?'" | jq -e --arg enabled "$lan_prefix_enable" '.[0][] | (.Enable | tostring) == $enabled' >/dev/null
  $ R "ba-cli -j -l '${lan_address_path}Prefix?'" | jq -e --arg prefix "Device.${lan_prefix_path%.}" '.[0][] | .Prefix == $prefix' >/dev/null
  $ trap - EXIT
