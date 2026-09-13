Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Verify python can import scapy:

  $ python3 -c "import scapy.all" >/dev/null 2>&1

Pick test constants:

  $ PROBE_TIMEOUT=12
  $ MAC_A="aa:bb:cc:dd:ee:01"
  $ MAC_B="aa:bb:cc:dd:ee:02"
  $ HOSTNAME_A="cramhostA"
  $ HOSTNAME_B="cramhostB"
  $ HOSTNAME_A_HEX="6372616d686f737441"
  $ HOSTNAME_B_HEX="6372616d686f737442"

Test 1 - basic client options (option 12 hostname):

  $ sudo -E python3 "$TESTDIR/dhcpv4_option_probe.py" --iface "$TESTBED_LAN_INTERFACE" --chaddr "$MAC_A" --hostname "$HOSTNAME_A" --timeout "$PROBE_TIMEOUT" 2>/dev/null
  CLIENT_MAC=aa:bb:cc:dd:ee:01
  SENT_HOSTNAME=cramhostA
  RECEIVED_TAGS=.* (re)

  $ sleep 1

Verify client A appears in DHCPv4.Server.Pool.Client:

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.lan.Client.[Chaddr==\"$MAC_A\"].Chaddr?'" | grep -Ev '^(>|$)'
  Device\.DHCPv4\.Server\.Pool\.[0-9]+\.Client\.[0-9]+\.Chaddr=.* (re)

Verify option 12 (hostname) is recorded under client A:

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.lan.Client.[Chaddr==\"$MAC_A\"].Option.[Tag==12].Tag?'" | grep -Ev '^(>|$)'
  Device\.DHCPv4\.Server\.Pool\.[0-9]+\.Client\.[0-9]+\.Option\.[0-9]+\.Tag=12 (re)

Verify option 12 value matches hostname A hex encoding:

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.lan.Client.[Chaddr==\"$MAC_A\"].Option.[Tag==12].Value?'" | grep -Ev '^(>|$)'
  Device\.DHCPv4\.Server\.Pool\.[0-9]+\.Client\.[0-9]+\.Option\.[0-9]+\.Value="6372616d686f737441" (re)

Verify option 53 (DHCP Message Type) is recorded under client A:

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.lan.Client.[Chaddr==\"$MAC_A\"].Option.[Tag==53].Tag?'" | grep -Ev '^(>|$)'
  Device\.DHCPv4\.Server\.Pool\.[0-9]+\.Client\.[0-9]+\.Option\.[0-9]+\.Tag=53 (re)

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.lan.Client.[Chaddr==\"$MAC_A\"].Option.[Tag==53].Value?'" | grep -Ev '^(>|$)'
  Device\.DHCPv4\.Server\.Pool\.[0-9]+\.Client\.[0-9]+\.Option\.[0-9]+\.Value="03" (re)

Test 2 - multiple clients each with their own options (C-2 per FEAT-13 spec):

  $ sudo -E python3 "$TESTDIR/dhcpv4_option_probe.py" --iface "$TESTBED_LAN_INTERFACE" --chaddr "$MAC_B" --hostname "$HOSTNAME_B" --timeout "$PROBE_TIMEOUT" 2>/dev/null
  CLIENT_MAC=aa:bb:cc:dd:ee:02
  SENT_HOSTNAME=cramhostB
  RECEIVED_TAGS=.* (re)

  $ sleep 1

Verify client B appears in DHCPv4.Server.Pool.Client:

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.lan.Client.[Chaddr==\"$MAC_B\"].Chaddr?'" | grep -Ev '^(>|$)'
  Device\.DHCPv4\.Server\.Pool\.[0-9]+\.Client\.[0-9]+\.Chaddr=.* (re)

Both clients must appear simultaneously:

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.lan.Client.[Chaddr==\"$MAC_A\"].Chaddr?'" | grep -Ev '^(>|$)'
  Device\.DHCPv4\.Server\.Pool\.[0-9]+\.Client\.[0-9]+\.Chaddr=.* (re)

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.lan.Client.[Chaddr==\"$MAC_B\"].Chaddr?'" | grep -Ev '^(>|$)'
  Device\.DHCPv4\.Server\.Pool\.[0-9]+\.Client\.[0-9]+\.Chaddr=.* (re)

Client A must carry hostname A hex (option 12), not hostname B hex:

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.lan.Client.[Chaddr==\"$MAC_A\"].Option.[Tag==12].Value?'" | grep -Ev '^(>|$)'
  Device\.DHCPv4\.Server\.Pool\.[0-9]+\.Client\.[0-9]+\.Option\.[0-9]+\.Value="6372616d686f737441" (re)

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.lan.Client.[Chaddr==\"$MAC_A\"].Option.[Value==\"${HOSTNAME_B_HEX}\"].Value?'" | grep -Ev '^(>|$)'
  No data found

Client B must carry hostname B hex (option 12), not hostname A hex:

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.lan.Client.[Chaddr==\"$MAC_B\"].Option.[Tag==12].Value?'" | grep -Ev '^(>|$)'
  Device\.DHCPv4\.Server\.Pool\.[0-9]+\.Client\.[0-9]+\.Option\.[0-9]+\.Value="6372616d686f737442" (re)

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.lan.Client.[Chaddr==\"$MAC_B\"].Option.[Value==\"${HOSTNAME_A_HEX}\"].Value?'" | grep -Ev '^(>|$)'
  No data found

Verify option 53 (DHCP Message Type) is recorded under client B (C-1 per FEAT-13 spec):

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.lan.Client.[Chaddr==\"$MAC_B\"].Option.[Tag==53].Tag?'" | grep -Ev '^(>|$)'
  Device\.DHCPv4\.Server\.Pool\.[0-9]+\.Client\.[0-9]+\.Option\.[0-9]+\.Tag=53 (re)

Cleanup - release both leases and verify clients are marked inactive in DM:

  $ sudo -E python3 "$TESTDIR/dhcpv4_option_probe.py" --iface "$TESTBED_LAN_INTERFACE" --chaddr "$MAC_A" --hostname "$HOSTNAME_A" --release --timeout "$PROBE_TIMEOUT" 2>/dev/null
  CLIENT_MAC=aa:bb:cc:dd:ee:01
  SENT_HOSTNAME=cramhostA
  RECEIVED_TAGS=.* (re)
  RELEASED=.* (re)

  $ sudo -E python3 "$TESTDIR/dhcpv4_option_probe.py" --iface "$TESTBED_LAN_INTERFACE" --chaddr "$MAC_B" --hostname "$HOSTNAME_B" --release --timeout "$PROBE_TIMEOUT" 2>/dev/null
  CLIENT_MAC=aa:bb:cc:dd:ee:02
  SENT_HOSTNAME=cramhostB
  RECEIVED_TAGS=.* (re)
  RELEASED=.* (re)

  $ sleep 1

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.lan.Client.[Chaddr==\"$MAC_A\"].Active?'" | grep -Ev '^(>|$)'
  Device\.DHCPv4\.Server\.Pool\.[0-9]+\.Client\.[0-9]+\.Active=0 (re)

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.lan.Client.[Chaddr==\"$MAC_B\"].Active?'" | grep -Ev '^(>|$)'
  Device\.DHCPv4\.Server\.Pool\.[0-9]+\.Client\.[0-9]+\.Active=0 (re)
