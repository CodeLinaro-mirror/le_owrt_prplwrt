Create the remote alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Step 1 — Verify DHCPv6 server is enabled on the LAN interface

  $ R "ba-cli 'Device.DHCPv6.Server.Enable?' | grep -Ev '^(>|$)' | grep 'Enable'"
  Device.DHCPv6.Server.Enable=1

Step 2 — Obtain an IA_NA lease using the simulated client

  $ sudo -E python3 "$TESTDIR/simulate_IANA_IAPD_ipv6_clients.py" -i "$TESTBED_LAN_INTERFACE" -t 5 --count 1 > /tmp/ipv6_client.log 2>&1
  $ sleep 2
  $ cat /tmp/ipv6_client.log | grep "Success! Leased" > /dev/null && echo "LEASED" || echo "NOT LEASED"
  LEASED

Record the assigned address and IAID from the simulators own log output:
 
  $ LEASED_ADDR=$(awk '/Leased Addr/ {print $NF}' /tmp/ipv6_client.log)
  $ echo "$LEASED_ADDR"
  [0-9a-fA-F:]+ (re)

  $ IAID_HEX=$(grep -oE 'IAID_HEX: 0x[0-9a-fA-F]+' /tmp/ipv6_client.log | tail -1 | awk '{print $2}')
  $ echo "$IAID_HEX"
  0x[0-9a-fA-F]+ (re)

  $ DUID=$(awk '/Client DUID/ {print $NF}' /tmp/ipv6_client.log)
  $ echo "$DUID"
  [0-9a-f:]+ (re)

Step 3 — Verify statefile format
Format: # <ifname> <hexduid> <hexiaid> <hostname> <ts> <id_hex> 128 <addr>/128
 
  $ R "head -n1 /tmp/odhcpd.leases"
  # br-lan * * * * * 128 */128 (glob)

Step 4 — Restart odhcpd, wait for interface init

  $ R "reboot" > /dev/null
  $ sleep 120

Step 5 — Assert lease survives restart

  $ R "ubus -S call dhcp ipv6leases | jsonfilter -e '@.device[\"br-lan\"].leases[0].duid'"
  *[0-9a-f]* (re)

Check for the restore log tag:
 
  $ R "logread | grep 'SUCCESSFULLY RESTORED' | grep 'DHCPv6 leases from state file'" > /dev/null && echo "LEASE RESTORED" || echo "LEASE NOT RESTORED"
  LEASE RESTORED

Step 6 — Client receives same address on RENEW

  $ sudo -E python3 "$TESTDIR/simulate_IANA_IAPD_ipv6_clients.py" -i "$TESTBED_LAN_INTERFACE" -t 5 --duid "$DUID" --iaid "$IAID_HEX" > /tmp/ipv6_client_t.log 2>&1
  $ sleep 2
  $ LEASED_ADDR2=$(awk '/Leased Addr/ {print $NF}' /tmp/ipv6_client_t.log)
  $ [ "$LEASED_ADDR" = "$LEASED_ADDR2" ] && echo "PASS" || echo "FAIL"
  PASS

Step 7 — Expired entry is not restored

  $ FAKE_DUID="000300010280f710dead"
  $ R "/etc/init.d/odhcpd stop"
  $ R "echo '# br-lan "$FAKE_DUID" 99999999 expired_client 1000000000 2 128 2001:db8:200:1::99/128' >> /tmp/odhcpd.leases"
  $ R "/etc/init.d/odhcpd start"
  $ sleep 2
 
Assert the expired entry was not restored:
 
  $ R "ubus -S call dhcp ipv6leases | jsonfilter -e '@.device[\"br-lan\"].leases'" | grep -c '2001:db8:200:1::99' || true
  0
  $ REAL_DUID=$(R "ubus -S call dhcp ipv6leases | jsonfilter -e '@.device[\"br-lan\"].leases[0].duid'")
  $ [ "$REAL_DUID" != "$FAKE_DUID" ] && echo "PASS" || echo "FAIL"
  PASS
 
Teardown & cleanup:

  $ sudo -E python3 "$TESTDIR/simulate_IANA_IAPD_ipv6_clients.py" -i "$TESTBED_LAN_INTERFACE" --duid "$DUID" --iaid "$IAID_HEX" -t 5 --release --iana > /dev/null 2>&1 || true
  $ sudo -E python3 "$TESTDIR/simulate_IANA_IAPD_ipv6_clients.py" -i "$TESTBED_LAN_INTERFACE" --duid "$DUID" --iaid "$IAID_HEX" -t 5 --release --iapd > /dev/null 2>&1 || true

  $ rm -f /tmp/ipv6_client.log
  $ rm -f /tmp/ipv6_client_t.log