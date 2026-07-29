DHCPv6 Server - Prefix Delegation and Route Verification

Verify that odhcpd handles IA_NA and IA_PD requests properly, populates
the local lease database, creates kernel IPv6 routes, and exposes corresponding
TR-181 IPv6Forwarding objects.

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Verify scapy is available on the test host:

  $ python3 -c "import scapy.all" >/dev/null 2>&1

Set test constants:

  $ CLIENT_DUID="00:03:00:01:00:11:22:33:44:55"
  $ CLIENT_IAID_NA="0x87654321"
  $ CLIENT_IAID_PD="0x12345678"
  $ CLIENT_NAME="odhcpd_pd_client"
  $ TIMEOUT=10

# Step 1 - Verify DHCPv6 Server is enabled and running

Verify odhcpd is running on the HGW:

  $ R "pidof odhcpd >/dev/null && echo RUNNING"
  RUNNING

Verify the DHCPv6 server is enabled in the data model:

  $ R "ba-cli 'Device.DHCPv6.Server.Enable?' | grep -Ev '^(>|$)' | grep Enable"
  Device.DHCPv6.Server.Enable=1

Save original IAPDEnable value for cleanup:

  $ IAPD_ENABLE_ORIG=$(R "ba-cli 'Device.DHCPv6.Server.Pool.1.IAPDEnable?' | grep -Ev '^(>|$)' | grep IAPDEnable | cut -d= -f2")

# Step 2 - Enable Prefix Delegation

  $ R "ba-cli 'Device.DHCPv6.Server.Pool.1.IAPDEnable=1'" >/dev/null
  $ sleep 3

Verify valid delegated prefix is configured on the server pool:

  $ PREFIX_OBJ=$(R 'ba-cli "Device.DHCPv6.Server.Pool.1.IAPDPrefixes?" | sed -n "s/.*=\"\(.*\)\"/\1/p"')
  $ PREFIX=$(R "ba-cli '${PREFIX_OBJ}.Prefix?' | sed -n 's/.*=\"\\(.*\\)\"/\\1/p'")
  $ echo "$PREFIX"
  [0-9a-fA-F:]+/[0-9]+ (re)

# Step 3 - Start DHCPv6 clients for IA_NA and IA_PD

Request IA_NA address:

  $ sudo -E python3 "$TESTDIR/simulate_IANA_IAPD_ipv6_clients.py" -i "$TESTBED_LAN_INTERFACE" --duid "$CLIENT_DUID" --iaid "$CLIENT_IAID_NA" -n "$CLIENT_NAME" --timeout "$TIMEOUT" > /tmp/odhcpd-iana-client.log 2>&1

  $ grep -F "[SUCCESS]" /tmp/odhcpd-iana-client.log
  *odhcpd_pd_client*SUCCESS* (glob)

Request IA_PD prefix:

  $ sudo -E python3 "$TESTDIR/simulate_IANA_IAPD_ipv6_clients.py" -i "$TESTBED_LAN_INTERFACE" --duid "$CLIENT_DUID" --iaid "$CLIENT_IAID_PD" -n "$CLIENT_NAME" --pd --pd-prefix-len 64 --timeout "$TIMEOUT" > /tmp/odhcpd-iapd-client.log 2>&1

  $ grep -F "[SUCCESS]" /tmp/odhcpd-iapd-client.log
  *odhcpd_pd_client*SUCCESS* (glob)

Extract leased parameters:

  $ IANA_ADDRESS=$(awk '/Leased Addr\/Prefix:/{print $NF}' /tmp/odhcpd-iana-client.log)
  $ IAPD_PREFIX=$(awk '/Leased Addr\/Prefix:/{print $NF}' /tmp/odhcpd-iapd-client.log)

Verify extracted lease formats:

  $ echo "$IANA_ADDRESS"
  [0-9a-fA-F:]+ (re)

  $ echo "$IAPD_PREFIX"
  [0-9a-fA-F:]+/[0-9]+ (re)

# Step 4 - Verify DHCPv6 lease persistence / database

  $ sleep 2

Verify leases file contains the requested IA_PD delegated prefix:

  $ R "cat /tmp/odhcpd.leases" | grep -q "$IAPD_PREFIX" && echo "IA_PD lease found" || echo "IA_PD lease missing"
  IA_PD lease found

Verify leases file contains the requested IA_NA IP address:

  $ R "cat /tmp/odhcpd.leases" | grep -q "$IANA_ADDRESS" && echo "IA_NA lease found" || echo "IA_NA lease missing"
  IA_NA lease found

Verify clients are recorded in ubus runtime state:

  $ LEASE_DUID=$(R "ubus -S call dhcp ipv6leases | jsonfilter -e '@.device[*].leases[@.hostname=\"${CLIENT_NAME}\"].duid'")
  $ [ -n "$LEASE_DUID" ] && echo "LEASE RECORDED" || echo "LEASE MISSING"
  LEASE RECORDED

# Step 5 - Verify Linux IPv6 routing table contains delegated prefix

  $ R "ip -6 route show" | grep -q "$IAPD_PREFIX" && echo "IA_PD prefix found in routing table" || echo "IA_PD prefix missing in routing table"
  IA_PD prefix found in routing table

# Step 6 - Verify TR-181 IPv6Forwarding object

  $ FORWARDING_OBJ=$(R "ba-cli 'Device.Routing.Router.1.IPv6Forwarding.*.DestIPPrefix?' | grep '$IAPD_PREFIX' | cut -d= -f1 | sed 's/.DestIPPrefix$//'") && echo "IA_PD route exists in TR-181 IPv6Forwarding object" || echo "IA_PD route does not exist in TR-181 IPv6Forwarding object"
  IA_PD route exists in TR-181 IPv6Forwarding object

  $ R "ba-cli '${FORWARDING_OBJ}.Enable?'" | grep -q "Enable=1" && echo "IA_PD route Enabled in TR-181 IPv6Forwarding object" || echo "IA_PD route Disabled in TR-181 IPv6Forwarding object"
  IA_PD route Enabled in TR-181 IPv6Forwarding object

  $ R "ba-cli '${FORWARDING_OBJ}.Status?'" | grep -q 'Status="Enabled"' && echo "IA_PD route Status is Enabled in TR-181 IPv6Forwarding object" || echo "IA_PD route Status is not Enabled in TR-181 IPv6Forwarding object"
  IA_PD route Status is Enabled in TR-181 IPv6Forwarding object

# Cleanup - Release DHCPv6 leases, restore original configuration, and remove logs

Release IA_NA lease:

  $ sudo -E python3 "$TESTDIR/simulate_IANA_IAPD_ipv6_clients.py" -i "$TESTBED_LAN_INTERFACE" --duid "$CLIENT_DUID" --iaid "$CLIENT_IAID_NA" -n "$CLIENT_NAME" --timeout "$TIMEOUT" --release --iana >/dev/null 2>&1

Release IA_PD lease:

  $ sudo -E python3 "$TESTDIR/simulate_IANA_IAPD_ipv6_clients.py" -i "$TESTBED_LAN_INTERFACE" --duid "$CLIENT_DUID" --iaid "$CLIENT_IAID_PD" -n "$CLIENT_NAME" --timeout "$TIMEOUT" --release --iapd >/dev/null 2>&1

Restore configuration and clean up log files:

  $ R "ba-cli 'Device.DHCPv6.Server.Pool.1.IAPDEnable=${IAPD_ENABLE_ORIG}'" >/dev/null
  $ rm -f /tmp/odhcpd-iapd-client.log /tmp/odhcpd-iana-client.log >/dev/null