DHCPv6 Server - IAPD Release and Route Cleanup

Verify that when a LAN client releases its DHCPv6 IAPD lease, odhcpd removes
the lease from its state file, deletes the corresponding kernel IPv6 route,
and cleans up the TR-181 IPv6Forwarding data model object.

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Verify scapy is available on the test host:

  $ python3 -c "import scapy.all" >/dev/null 2>&1

Set test constants:

  $ CLIENT_DUID="00:03:00:01:00:11:22:33:44:55"
  $ CLIENT_IAID_PD="0x12345678"
  $ CLIENT_NAME="iapd_client"
  $ TIMEOUT=10

Step 1 — Verify DHCPv6 Server is enabled and running

Verify odhcpd is running on the HGW:

  $ R "pidof odhcpd >/dev/null && echo RUNNING"
  RUNNING

Verify the DHCPv6 server is enabled in the data model:

  $ R "ba-cli 'Device.DHCPv6.Server.Enable?' | grep -Ev '^(>|$)' | grep Enable"
  Device.DHCPv6.Server.Enable=1

Save original IAPDEnable value for cleanup:

  $ IAPD_ENABLE_ORIG=$(R "ba-cli 'Device.DHCPv6.Server.Pool.1.IAPDEnable?' | grep -Ev '^(>|$)' | grep IAPDEnable | cut -d= -f2")

Enable Prefix Delegation:

  $ R "ba-cli 'Device.DHCPv6.Server.Pool.1.IAPDEnable=1'" >/dev/null
  $ sleep 3

Step 2 — Request IA_PD prefix allocation

  $ sudo -E python3 "$TESTDIR/simulate_IANA_IAPD_ipv6_clients.py" -i "$TESTBED_LAN_INTERFACE" --duid "$CLIENT_DUID" --iaid "$CLIENT_IAID_PD" -n "$CLIENT_NAME" --pd --pd-prefix-len 64 --timeout "$TIMEOUT" > /tmp/c7_iapd_alloc.log 2>&1

  $ grep -F "[SUCCESS]" /tmp/c7_iapd_alloc.log
  *iapd_client*SUCCESS* (glob)

Extract leased IAPD prefix:

  $ IAPD_PREFIX=$(awk '/Leased Addr\/Prefix:/{print $NF}' /tmp/c7_iapd_alloc.log)
  $ echo "$IAPD_PREFIX"
  [0-9a-fA-F:]+/[0-9]+ (re)

Step 3 — Verify pre-release state (Lease, Routing Table, and TR-181 DM)

Wait for state file & data model synchronization:

  $ sleep 2

Verify lease entry exists in odhcpd state file:

  $ R "cat /tmp/odhcpd.leases" | grep -q "$IAPD_PREFIX" && echo "LEASE CREATED" || echo "LEASE MISSING"
  LEASE CREATED

Verify IPv6 route exists in Linux kernel:

  $ R "ip -6 route show" | grep -q "$IAPD_PREFIX" && echo "ROUTE CREATED" || echo "ROUTE MISSING"
  ROUTE CREATED

Verify TR-181 IPv6Forwarding object exists for delegated prefix:

  $ FORWARDING_OBJ=$(R "ba-cli 'Device.Routing.Router.1.IPv6Forwarding.*.DestIPPrefix?' | grep '$IAPD_PREFIX' | cut -d= -f1 | sed 's/.DestIPPrefix$//'")
  $ [ -n "$FORWARDING_OBJ" ] && echo "DM OBJECT CREATED" || echo "DM OBJECT MISSING"
  DM OBJECT CREATED

Step 4 — Release DHCPv6 IAPD lease

  $ sudo -E python3 "$TESTDIR/simulate_IANA_IAPD_ipv6_clients.py" -i "$TESTBED_LAN_INTERFACE" --duid "$CLIENT_DUID" --iaid "$CLIENT_IAID_PD" -n "$CLIENT_NAME" --timeout "$TIMEOUT" --release --iapd > /tmp/c7_iapd_release.log 2>&1

Wait for release processing:

  $ sleep 3

Step 5 — Verify post-release cleanup (C-7 Assertions)

Verify lease is removed from odhcpd state file:

  $ R "cat /tmp/odhcpd.leases" | grep -c "$IAPD_PREFIX" || true
  0

Verify kernel IPv6 route is removed:

  $ R "ip -6 route show" | grep -c "$IAPD_PREFIX" || true
  0

Verify TR-181 IPv6Forwarding object is removed from data model:

  $ R "ba-cli 'Device.Routing.Router.1.IPv6Forwarding.*.DestIPPrefix?'" | grep -c "$IAPD_PREFIX" || true
  0

Cleanup & Teardown:

  $ R "ba-cli 'Device.DHCPv6.Server.Pool.1.IAPDEnable=${IAPD_ENABLE_ORIG}'" >/dev/null 2>&1 || true
  $ rm -f /tmp/c7_iapd_alloc.log /tmp/c7_iapd_release.log >/dev/null 2>&1 || true