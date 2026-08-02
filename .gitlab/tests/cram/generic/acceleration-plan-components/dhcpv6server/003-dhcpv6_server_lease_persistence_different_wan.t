DHCPv6 Server - Lease Persistence with Different WAN Configuration (PPW-1288)

Verify that after the DHCPv6 server restarts with a DIFFERENT WAN IPv6
configuration, odhcpd correctly reloads its lease file and re-issues:
1.An IANA address preserving the clients host portion (last 64 bits).
2.An IAPD prefix shifted by the exact same offset as the WAN prefix shift.

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Verify scapy is available on the test host:

  $ python3 -c "import scapy.all" >/dev/null 2>&1

Set test constants:

  $ CLIENT_DUID="00:03:00:01:bb:cc:dd:ee:ff:02"
  $ CLIENT_IAID_NA="0x33333333"
  $ CLIENT_IAID_PD="0x44444444"
  $ CLIENT_NAME="dhcpv6-diff-wan-client"
  $ TIMEOUT=10

Step 1 — Verify DHCPv6Server is up with initial WAN IPv6 configuration:

Verify odhcpd is running on the HGW:

  $ R "pidof odhcpd >/dev/null && echo RUNNING"
  RUNNING

Verify the DHCPv6 server is enabled in the data model:

  $ R "ba-cli 'Device.DHCPv6.Server.Enable?' | grep -Ev '^(>|$)' | grep Enable"
  Device.DHCPv6.Server.Enable=1

Save original IAPDEnable value for teardown:

  $ IAPD_ENABLE_ORIG=$(R "ba-cli 'Device.DHCPv6.Server.Pool.1.IAPDEnable?' | grep -Ev '^(>|$)' | grep IAPDEnable | cut -d= -f2")

Enable IAPD on the DHCPv6 server pool:

  $ R "ba-cli 'Device.DHCPv6.Server.Pool.1.IAPDEnable=1'" >/dev/null
  $ sleep 3

Step 2 — Start DHCPv6Client (dry-run mode) using IANA and IAPD:

Request IANA lease:

  $ sudo -E python3 "$TESTDIR/simulate_IANA_IAPD_ipv6_clients.py" -i "$TESTBED_LAN_INTERFACE" --duid "$CLIENT_DUID" --iaid "$CLIENT_IAID_NA" -n "$CLIENT_NAME" --timeout "$TIMEOUT" > /tmp/dhcpv6_iana_before.txt 2>&1
  $ grep -F "[SUCCESS]" /tmp/dhcpv6_iana_before.txt
  *dhcpv6-diff-wan-client*SUCCESS* (glob)

Request IAPD lease:

  $ sudo -E python3 "$TESTDIR/simulate_IANA_IAPD_ipv6_clients.py" -i "$TESTBED_LAN_INTERFACE" --duid "$CLIENT_DUID" --iaid "$CLIENT_IAID_PD" -n "$CLIENT_NAME" --pd --timeout "$TIMEOUT" > /tmp/dhcpv6_iapd_before.txt 2>&1
  $ grep -F "[SUCCESS]" /tmp/dhcpv6_iapd_before.txt
  *dhcpv6-diff-wan-client*SUCCESS* (glob)

Step 3 — Store initial IANA address and IAPD prefix:

  $ IANA_ADDR_BEFORE=$(awk '/Leased Addr\/Prefix:/{print $NF}' /tmp/dhcpv6_iana_before.txt)
  $ IAPD_PREFIX_BEFORE=$(awk '/Leased Addr\/Prefix:/{print $NF}' /tmp/dhcpv6_iapd_before.txt)

Confirm both initial leases are valid:

  $ [ -n "$IANA_ADDR_BEFORE" ] && [ "$IANA_ADDR_BEFORE" != "None" ] && echo "IANA OK" || echo "IANA FAIL"
  IANA OK

  $ [ -n "$IAPD_PREFIX_BEFORE" ] && [ "$IAPD_PREFIX_BEFORE" != "None" ] && echo "IAPD OK" || echo "IAPD FAIL"
  IAPD OK

Step 4 — Verify the Lease Data model:

  $ sleep 2

Verify active lease exists in ubus runtime state:

  $ LEASE_DUID=$(R "ubus -S call dhcp ipv6leases | jsonfilter -e '@.device[*].leases[@.hostname=\"${CLIENT_NAME}\"].duid'")
  $ [ -n "$LEASE_DUID" ] && echo "LEASE RECORDED" || echo "LEASE MISSING"
  LEASE RECORDED

Verify client entry is present in Data Model:

  $ R "ba-cli 'Device.DHCPv6.Server.Pool.lan.Client.?' 2>/dev/null | grep -c 'Client\.' || echo 0" | grep -qvE '^0$' && echo "CLIENT IN DM" || echo "NO CLIENT IN DM"
  CLIENT IN DM

Step 5 — Restart Gateway & Trigger DIFFERENT WAN IPv6 Prefix Allocation:

Store original parent prefix:

  $ ORIG_WAN_PREFIX=$(R "ba-cli 'Device.IP.Interface.2.IPv6Prefix.1.Prefix?' | sed -n 's/.*=\"\(.*\)\"/\1/p'")

Set a new shifted WAN delegated prefix (e.g., 2001:db8:300:100::/56):

  $ R "ba-cli 'Device.IP.Interface.2.IPv6Prefix.1.Prefix=\"2001:db8:300:100::/56\"'" >/dev/null

Reboot the HGW to trigger full state reload:

  $ R "reboot" >/dev/null
  $ sleep 120

Confirm odhcpd is back up:

  $ R "pidof odhcpd >/dev/null && echo RUNNING"
  RUNNING

Step 6 — Start DHCPv6Client using IANA and IAPD (post-reboot):

Request IANA again using the same DUID + IAID:

  $ sudo -E python3 "$TESTDIR/simulate_IANA_IAPD_ipv6_clients.py" -i "$TESTBED_LAN_INTERFACE" --duid "$CLIENT_DUID" --iaid "$CLIENT_IAID_NA" -n "$CLIENT_NAME" --timeout "$TIMEOUT" > /tmp/dhcpv6_iana_after.txt 2>&1
  $ grep -F "[SUCCESS]" /tmp/dhcpv6_iana_after.txt
  *dhcpv6-diff-wan-client*SUCCESS* (glob)

Request IAPD again using the same DUID + IAID:

  $ sudo -E python3 "$TESTDIR/simulate_IANA_IAPD_ipv6_clients.py" -i "$TESTBED_LAN_INTERFACE" --duid "$CLIENT_DUID" --iaid "$CLIENT_IAID_PD" -n "$CLIENT_NAME" --pd --timeout "$TIMEOUT" > /tmp/dhcpv6_iapd_after.txt 2>&1
  $ grep -F "[SUCCESS]" /tmp/dhcpv6_iapd_after.txt
  *dhcpv6-diff-wan-client*SUCCESS* (glob)

Step 7 — Verify IANA address and IAPD prefix match the NEW IPv6 configuration:

Extract post-reboot leased parameters:

  $ IANA_ADDR_AFTER=$(awk '/Leased Addr\/Prefix:/{print $NF}' /tmp/dhcpv6_iana_after.txt)
  $ IAPD_PREFIX_AFTER=$(awk '/Leased Addr\/Prefix:/{print $NF}' /tmp/dhcpv6_iapd_after.txt)

1. Verify host portion (last 64 bits) of IANA address remains IDENTICAL:

  $ python3 -c "
  > import ipaddress
  > b = ipaddress.IPv6Address('$IANA_ADDR_BEFORE')
  > a = ipaddress.IPv6Address('$IANA_ADDR_AFTER')
  > HOST_MASK = (1 << 64) - 1
  > if (int(b) & HOST_MASK) == (int(a) & HOST_MASK):
  >     print('IANA HOST MATCH: ' + str(a))
  > else:
  >     print('IANA HOST MISMATCH: before=' + str(b) + ' after=' + str(a))
  > "
  IANA HOST MATCH: * (glob)

2. Verify IAPD relative position offset matches the new WAN IPv6 prefix shift:

  $ python3 -c "
  > import ipaddress
  > iana_b = ipaddress.IPv6Address('$IANA_ADDR_BEFORE')
  > iana_a = ipaddress.IPv6Address('$IANA_ADDR_AFTER')
  > iapd_b = ipaddress.IPv6Network('$IAPD_PREFIX_BEFORE')
  > iapd_a = ipaddress.IPv6Network('$IAPD_PREFIX_AFTER')
  > wan_shift = int(iana_a) - int(iana_b)
  > expected_iapd = ipaddress.IPv6Network((int(iapd_b.network_address) + wan_shift, iapd_b.prefixlen), strict=False)
  > if expected_iapd == iapd_a:
  >     print('IAPD SHIFT MATCH: ' + str(iapd_a))
  > else:
  >     print('IAPD SHIFT MISMATCH: expected=' + str(expected_iapd) + ' got=' + str(iapd_a))
  > "
  IAPD SHIFT MATCH: * (glob)

Teardown & Cleanup:

  $ sudo -E python3 "$TESTDIR/simulate_IANA_IAPD_ipv6_clients.py" -i "$TESTBED_LAN_INTERFACE" --duid "$CLIENT_DUID" --iaid "$CLIENT_IAID_NA" -n "$CLIENT_NAME" --timeout "$TIMEOUT" --release --iana >/dev/null 2>&1 || true
  $ sudo -E python3 "$TESTDIR/simulate_IANA_IAPD_ipv6_clients.py" -i "$TESTBED_LAN_INTERFACE" --duid "$CLIENT_DUID" --iaid "$CLIENT_IAID_PD" -n "$CLIENT_NAME" --timeout "$TIMEOUT" --release --iapd >/dev/null 2>&1 || true
  $ R "ba-cli 'Device.DHCPv6.Server.Pool.1.IAPDEnable=${IAPD_ENABLE_ORIG}'" >/dev/null 2>&1 || true
  $ rm -f /tmp/dhcpv6_iana_before.txt /tmp/dhcpv6_iapd_before.txt /tmp/dhcpv6_iana_after.txt /tmp/dhcpv6_iapd_after.txt
