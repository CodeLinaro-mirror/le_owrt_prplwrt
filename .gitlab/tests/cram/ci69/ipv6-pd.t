Kea and the LAN namespace are provided by testbed-qemu.
The DUT obtains its delegated prefix through DHCPv6.
The LAN client obtains its address and default route through RA/SLAAC.
The DUT uses its default DHCPv6 configuration.

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias V6='python3 "$TESTDIR/ipv6.py"'
  $ . "$TESTDIR/network.sh"
  $ save_firewall || exit 1
  $ trap cleanup_network EXIT

Wait for SLAAC on the separate LAN client.

  $ V6 wait-lan > "$CRAMTMP/lan.env" || exit 1
  $ . "$CRAMTMP/lan.env"

  $ V6 kea status-get | jq -r '.result'
  0
  $ V6 kea config-get | jq -r '.arguments.Dhcp6.subnet6[0]["pd-pools"][0] | "\(.prefix)/\(.["delegated-len"])"'
  2001:2:0:9600::/60

Both directions must route through the DUT, with no controller LAN shortcut.

  $ ip -j -6 route get "$TESTBED_LAN_CLIENT_ADDRESS" from "$TESTBED_WAN_ADDRESS" | jq -e '.[0] | .dev == "br-wan" and (.gateway | startswith("fe80:"))' >/dev/null
  $ "$TESTBED_LAN_CLIENT_EXEC" ip -j -6 route get "$TESTBED_WAN_ADDRESS" | jq -e --arg gw "$TESTBED_LAN_GATEWAY" '.[0].gateway == $gw' >/dev/null

Disable the firewall explicitly for this bidirectional routing test.
The fixture itself leaves firewall policy to the tests.

  $ R "ba-cli 'Device.Firewall.Enable=false'" >/dev/null
  $ sleep 2
  $ "$TESTBED_LAN_CLIENT_EXEC" ping -6 -n -c 3 -W 3 "$TESTBED_WAN_ADDRESS" >/dev/null
  $ ping -6 -n -c 3 -W 3 -I "$TESTBED_WAN_ADDRESS" "$TESTBED_LAN_CLIENT_ADDRESS" >/dev/null
  $ V6 tcp lan-to-wan
  TCP payload and echo verified
  $ V6 tcp wan-to-lan
  TCP payload and echo verified

  $ cleanup_network
  $ trap - EXIT
