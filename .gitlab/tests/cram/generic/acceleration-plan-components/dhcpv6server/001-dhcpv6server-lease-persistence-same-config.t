DHCPv6 Server - Lease Persistence with Same WAN Configuration (Requirement 1)

Verify that after the DHCPv6 server restarts with the same WAN IPv6
configuration, odhcpd correctly reloads its lease file and re-issues
the exact same IANA address and IAPD prefix to the same LAN client
(identified by DUID + IAID).

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Verify scapy is available on the test host:

  $ python3 -c "import scapy.all" >/dev/null 2>&1

Set test constants - fixed DUID and IAID give the simulated client a
deterministic identity across all simulator runs in this test:

  $ CLIENT_DUID="00:03:00:01:aa:bb:cc:dd:ee:01"
  $ CLIENT_IAID_NA="0x11111111"
  $ CLIENT_IAID_PD="0x22222222"
  $ CLIENT_NAME="dhcpv6-client-test"
  $ TIMEOUT=10

Step 1 - Verify DHCPv6Server is up with WAN IPv6 configuration:

Verify odhcpd is running on the HGW:

  $ R "pidof odhcpd >/dev/null && echo RUNNING"
  RUNNING

Verify the DHCPv6 server is enabled in the data model:

  $ R "ba-cli 'Device.DHCPv6.Server.Enable?' | grep -Ev '^(>|$)' | grep Enable"
  Device.DHCPv6.Server.Enable=1

Save the original IAPDEnable value so it can be restored during cleanup:

  $ IAPD_ENABLE_ORIG=$(R "ba-cli 'Device.DHCPv6.Server.Pool.1.IAPDEnable?' | grep -Ev '^(>|$)' | grep IAPDEnable | cut -d= -f2")

Enable IAPD on the DHCPv6 server pool (allows prefix delegation to LAN clients):

  $ R "ba-cli 'Device.DHCPv6.Server.Pool.1.IAPDEnable=1'" >/dev/null
  $ sleep 3

Step 2 - Start DHCPv6Client using IANA:

  $ sudo -E python3 "$TESTDIR/simulate_IANA_IAPD_ipv6_clients.py" -i "$TESTBED_LAN_INTERFACE" --duid "$CLIENT_DUID" --iaid "$CLIENT_IAID_NA" -n "$CLIENT_NAME" --timeout "$TIMEOUT" > /tmp/dhcpv6_iana_before.txt 2>&1

Verify the IANA Solicit/Advertise/Request/Reply exchange completed successfully:

  $ grep -F "[SUCCESS]" /tmp/dhcpv6_iana_before.txt
  *dhcpv6-client-test*SUCCESS* (glob)

Step 2b - Start DHCPv6Client using IAPD:

  $ sudo -E python3 "$TESTDIR/simulate_IANA_IAPD_ipv6_clients.py" -i "$TESTBED_LAN_INTERFACE" --duid "$CLIENT_DUID" --iaid "$CLIENT_IAID_PD" -n "$CLIENT_NAME" --pd --timeout "$TIMEOUT" > /tmp/dhcpv6_iapd_before.txt 2>&1

Verify the IAPD Solicit/Advertise/Request/Reply exchange completed successfully:

  $ grep -F "[SUCCESS]" /tmp/dhcpv6_iapd_before.txt
  *dhcpv6-client-test*SUCCESS* (glob)

Step 3 - Store IANA address and IAPD prefix:

Extract the leased IANA address from the simulator summary output:

  $ IANA_ADDR_BEFORE=$(awk '/Leased Addr\/Prefix:/{print $NF}' /tmp/dhcpv6_iana_before.txt)

Extract the leased IAPD prefix from the simulator summary output:

  $ IAPD_PREFIX_BEFORE=$(awk '/Leased Addr\/Prefix:/{print $NF}' /tmp/dhcpv6_iapd_before.txt)

Confirm the IANA address is a valid non-empty value (not "None"):

  $ [ -n "$IANA_ADDR_BEFORE" ] && [ "$IANA_ADDR_BEFORE" != "None" ] && echo "IANA OK" || echo "IANA FAIL"
  IANA OK

Confirm the IAPD prefix is a valid non-empty value (not "None"):

  $ [ -n "$IAPD_PREFIX_BEFORE" ] && [ "$IAPD_PREFIX_BEFORE" != "None" ] && echo "IAPD OK" || echo "IAPD FAIL"
  IAPD OK

Step 4 - Verify the Lease Data model:

Wait for odhcpd to record the lease in its internal state:

  $ sleep 2

Verify the lease is recorded in odhcpd runtime lease table via ubus:

  $ LEASE_DUID=$(R "ubus -S call dhcp ipv6leases | jsonfilter -e '@.device[*].leases[@.hostname=\"${CLIENT_NAME}\"].duid'")
  $ [ -n "$LEASE_DUID" ] && echo "LEASE RECORDED" || echo "LEASE MISSING"
  LEASE RECORDED

Verify the DHCPv6 server pool reflects an active client entry in the data model:

  $ R "ba-cli 'Device.DHCPv6.Server.Pool.lan.Client.?' 2>/dev/null | grep -c 'Client\.' || echo 0" | grep -qvE '^0$' && echo "CLIENT IN DM" || echo "NO CLIENT IN DM"
  CLIENT IN DM

Step 5 - Restart the gateway (same WAN IPv6 configuration):

Reboot DUT:

  $ R "reboot"
  $ sleep 120

Confirm odhcpd came back up after the restart:

  $ R "pidof odhcpd >/dev/null && echo RUNNING"
  RUNNING

Step 6 - Start DHCPv6Client again - same identity after restart:

Run IANA simulation again with the identical DUID + IAID:

  $ sudo -E python3 "$TESTDIR/simulate_IANA_IAPD_ipv6_clients.py" -i "$TESTBED_LAN_INTERFACE" --duid "$CLIENT_DUID" --iaid "$CLIENT_IAID_NA" -n "$CLIENT_NAME" --timeout "$TIMEOUT" > /tmp/dhcpv6_iana_after.txt 2>&1

Verify IANA exchange succeeded after restart:

  $ grep -F "[SUCCESS]" /tmp/dhcpv6_iana_after.txt
  *dhcpv6-client-test*SUCCESS* (glob)

Run IAPD simulation again with the identical DUID + IAID:

  $ sudo -E python3 "$TESTDIR/simulate_IANA_IAPD_ipv6_clients.py" -i "$TESTBED_LAN_INTERFACE" --duid "$CLIENT_DUID" --iaid "$CLIENT_IAID_PD" -n "$CLIENT_NAME" --pd --timeout "$TIMEOUT" > /tmp/dhcpv6_iapd_after.txt 2>&1

Verify IAPD exchange succeeded after restart:

  $ grep -F "[SUCCESS]" /tmp/dhcpv6_iapd_after.txt
  *dhcpv6-client-test*SUCCESS* (glob)

Step 7 - Verify IANA address and IAPD prefix are identical to pre-restart values:

Extract post-restart leased IANA address:

  $ IANA_ADDR_AFTER=$(awk '/Leased Addr\/Prefix:/{print $NF}' /tmp/dhcpv6_iana_after.txt)

Extract post-restart leased IAPD prefix:

  $ IAPD_PREFIX_AFTER=$(awk '/Leased Addr\/Prefix:/{print $NF}' /tmp/dhcpv6_iapd_after.txt)

Verify the IANA address is the same before and after restart:

  $ [ "$IANA_ADDR_BEFORE" = "$IANA_ADDR_AFTER" ] && echo "IANA SAME: $IANA_ADDR_BEFORE" || echo "IANA CHANGED: was=$IANA_ADDR_BEFORE now=$IANA_ADDR_AFTER"
  IANA SAME: * (glob)

Verify the IAPD prefix is the same before and after restart:

  $ [ "$IAPD_PREFIX_BEFORE" = "$IAPD_PREFIX_AFTER" ] && echo "IAPD SAME: $IAPD_PREFIX_BEFORE" || echo "IAPD CHANGED: was=$IAPD_PREFIX_BEFORE now=$IAPD_PREFIX_AFTER"
  IAPD SAME: * (glob)

Cleanup:

Release the active IANA and IAPD leases using the simulated client DUID and respective IAIDs:

  $ sudo -E python3 "$TESTDIR/simulate_IANA_IAPD_ipv6_clients.py" -i "$TESTBED_LAN_INTERFACE" --duid "$CLIENT_DUID" --iaid "$CLIENT_IAID_NA" -n "$CLIENT_NAME" --timeout "$TIMEOUT" --release --iana >/dev/null 2>&1
  $ sudo -E python3 "$TESTDIR/simulate_IANA_IAPD_ipv6_clients.py" -i "$TESTBED_LAN_INTERFACE" --duid "$CLIENT_DUID" --iaid "$CLIENT_IAID_PD" -n "$CLIENT_NAME" --timeout "$TIMEOUT" --release --iapd >/dev/null 2>&1

Remove temporary log files:

  $ rm -f /tmp/dhcpv6_iana_before.txt /tmp/dhcpv6_iapd_before.txt /tmp/dhcpv6_iana_after.txt /tmp/dhcpv6_iapd_after.txt

Restore IAPDEnable to its original value:

  $ R "ba-cli 'Device.DHCPv6.Server.Pool.1.IAPDEnable=${IAPD_ENABLE_ORIG}'" >/dev/null
