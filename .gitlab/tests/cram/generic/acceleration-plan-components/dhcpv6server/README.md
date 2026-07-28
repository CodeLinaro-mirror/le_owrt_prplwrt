# simulate_IANA_IAPD_ipv6_clients.py

A DHCPv6 client simulator built on [Scapy](https://scapy.net/) that performs complete Solicit → Advertise → Request → Reply exchanges on a live network interface. It supports both IA_NA (address assignment) and IA_PD (prefix delegation) modes, single and multi-client simulation, fully deterministic client identities via custom DUID and IAID, and DHCPv6 RELEASE.

## Requirements

```
pip install scapy
```

Root privileges are required because the script uses raw sockets to craft and inject Ethernet frames.

## Usage

```
sudo -E python3 simulate_IANA_IAPD_ipv6_clients.py -i IFACE [OPTIONS]
```

### Arguments

| Flag | Short | Default | Description |
|------|-------|---------|-------------|
| `--iface` | `-i` | *(required)* | Network interface to send/receive DHCPv6 on (e.g. `eth0`, `br-lan`) |
| `--client-name` | `-n` | `client` | Hostname sent in the FQDN option; used as the base name when `--count > 1` |
| `--duid` | | *(random)* | Client DUID as a colon-separated hex string (e.g. `00:03:00:01:aa:bb:cc:dd:ee:ff`) |
| `--iaid` | | *(derived)* | IAID as decimal or hex (e.g. `256` or `0x100`) |
| `--request-options` | `-r` | `16,17,23,24,39` | Comma-separated DHCPv6 option codes to include in the ORO (Option Request Option) |
| `--timeout` | `-t` | `5` | Seconds to wait for each server response before giving up |
| `--apply-lease` | `-a` | off | Apply the assigned IPv6 address to the interface with `ip addr` after the REPLY |
| `--count` | `-c` | `1` | Number of independent clients to simulate sequentially |
| `--pd` | | off | Request IA_PD (prefix delegation) instead of IA_NA (address) |
| `--pd-prefix-len` | | `64` | Prefix length hint sent in the IA_PD Solicit when `--pd` is active |
| `--release` | | off | Send a DHCPv6 RELEASE (type 8) instead of a Solicit/Request exchange; requires `--iana` or `--iapd` |
| `--iana` | | off | With `--release`, release an IA_NA (address) lease. Mutually exclusive with `--iapd` |
| `--iapd` | | off | With `--release`, release an IA_PD (prefix) delegation. Mutually exclusive with `--iana` |
| `--release-address` | | *(placeholder)* | Optional comma-separated address(es)/prefix(es) to include in the RELEASE, one per `--count` client. Cosmetic only — see note below |
| `--server-duid` | | *(auto-discovered)* | Server DUID to target with RELEASE. If omitted, it's discovered automatically via a throwaway Solicit |

### Default option request codes (ORO)

| Code | Option |
|------|--------|
| 16 | Vendor Class |
| 17 | Vendor-specific Information |
| 23 | DNS Recursive Name Server |
| 24 | Domain Search List |
| 39 | Client FQDN |

## DHCPv6 Exchange Flow

For each simulated client the script performs one complete four-message exchange:

```
Client                          Server (odhcpd)
  |                                   |
  |--- SOLICIT (IA_NA or IA_PD) ----> |
  |<-- ADVERTISE -------------------- |
  |--- REQUEST (confirms offer) ----> |
  |<-- REPLY (lease granted) -------- |
```

The sniffer thread and the sender run concurrently. A `threading.Event` signals completion when the REPLY is received, or the timeout (2× `--timeout`) expires.

## DHCPv6 Release Flow

When `--release` is passed, the script skips the Solicit/Advertise/Request/Reply exchange entirely and instead sends a single RELEASE message per client:

```
Client                          Server (odhcpd)
  |                                   |
  |--- RELEASE (IA_NA or IA_PD) ----> |
  |<-- REPLY (Status Code) ---------- |
```

If `--server-duid` is not given, the script first sends a throwaway Solicit to learn the server's DUID before sending the RELEASE.

**Important — odhcpd matches a RELEASE on Client DUID + IAID only.** The address (for `--iana`) or prefix (for `--iapd`) carried inside the RELEASE is not checked against the lease table, only the requesting client's identity is. Practical implications:

- `--release-address` is optional. If you omit it, the script fills in a placeholder automatically (`::` for `--iana`, `::/<pd-prefix-len>` for `--iapd`) and the release still succeeds as long as the DUID + IAID match an existing lease.
- You must still pick `--iana` or `--iapd` so the script builds the correct option type (`IA_NA` vs `IA_PD`) — that part of the message *is* structurally required by the protocol, even though the address/prefix content inside it isn't checked.
- Get the DUID and IAID right (matching what was used to originally obtain the lease, e.g. from the `SIMULATION SUMMARY` of a prior run) — those are the only fields odhcpd uses to find and remove the lease.

## Client Identity

### DUID

If `--duid` is not provided the script generates a random `DUID_LL` from a locally-administered MAC address. The last byte is set to `client_idx & 0xFF` so each client in a multi-client run gets a unique DUID.

If `--duid` is provided the given bytes are used as-is for `client_idx=0`. For subsequent clients (`--count > 1`) the **last byte** of the provided DUID is incremented by `client_idx`, making it easy to derive a batch of related, reproducible DUIDs from a single base value. This same derivation is used for `--release`, so releasing multiple clients with a base `--duid`/`--iaid` and `--count` reproduces the same per-client identities used to obtain the leases.

Accepted formats: `00:03:00:01:aa:bb:cc:dd:ee:ff`, `00030001aabbccddeeff`, or any mix of `:` and `-` separators.

DUID type auto-detection:

| Type byte | Scapy class |
|-----------|-------------|
| `0x0001` | `DUID_LLT` (Link-layer + time) |
| `0x0002` | `DUID_EN` (Enterprise number) |
| `0x0003` | `DUID_LL` (Link-layer) |
| other | `Raw` |

### IAID

If `--iaid` is not provided:
- With `--duid`: derived from the first 4 bytes of the DUID bytes.
- Without `--duid`: derived from the last 4 bytes of the randomly generated MAC.

In both cases `client_idx` is added so each simulated client has a unique IAID.

If `--iaid` is provided the value is used directly for `client_idx=0`, with `client_idx` added for each subsequent client (wrapping at `0xFFFFFFFF`).

## Output

All log lines go to stdout with a timestamp and log level:

```
[14:23:01.042] [INFO ] Using link-local address: fe80::1
[14:23:01.045] [INFO ] --- Starting Client 1/1 (Name: my-client, ...) ---
[14:23:01.047] [INFO ] Client 1 (my-client): Starting exchange (TRID: 0xabcdef)
[14:23:01.048] [INFO ] Client 1 (my-client): Sending SOLICIT
[14:23:01.052] [INFO ] Client 1 (my-client): ADVERTISE received from Server DUID: 00:...
[14:23:01.053] [INFO ] Client 1 (my-client): Sending REQUEST
[14:23:01.058] [OK   ] Client 1 (my-client): Success! Leased: 2001:db8:1::100
```

After all clients finish, a structured summary is printed:

```
================================================================================
SIMULATION SUMMARY
================================================================================
Client 1 (my-client) [SUCCESS]
  ├─ Client DUID: 00:03:00:01:aa:bb:cc:dd:ee:ff
  ├─ IAID: 286331153
  ├─ IAID_HEX: 0x11111111
  ├─ Server DUID: 00:01:...
  ├─ Server Vendor: Enterprise ID: 12345 (ExampleVendor)
  ├─ Leased Addr/Prefix: 2001:db8:1::100        # address in IA_NA mode
  └─ Applied: None                               # or the address if --apply-lease
--------------------------------------------------------------------------------
```

In IA_PD mode `Leased Addr/Prefix` shows the delegated prefix with its length:

```
  ├─ Leased Addr/Prefix: 2001:db8:1:1000::/60
```

When `--release` is used, a shorter summary is printed instead:

```
================================================================================
RELEASE SUMMARY
================================================================================
  my-client: [RELEASE_SUCCESS] ::
```

**Exit codes:** the script always exits `0` on clean termination. The `[SUCCESS]` / `[FAILED]` (or `[RELEASE_SUCCESS]` / `[RELEASE_FAILED]`) status in the summary is the machine-readable result used by the cram tests.

## Examples

```bash
# IA_NA request - basic dry-run, random DUID
sudo python3 simulate_IANA_IAPD_ipv6_clients.py -i eth0

# IA_NA with fixed DUID + IAID (deterministic, cram-test-friendly)
sudo python3 simulate_IANA_IAPD_ipv6_clients.py -i eth0 \
    --duid "00:03:00:01:aa:bb:cc:dd:ee:01" \
    --iaid 0x11111111 \
    --client-name my-laptop \
    --timeout 10

# IA_PD request, ask for a /56 prefix
sudo python3 simulate_IANA_IAPD_ipv6_clients.py -i eth0 \
    --pd --pd-prefix-len 56

# Simulate 5 distinct clients from a base DUID (last byte increments per client)
sudo python3 simulate_IANA_IAPD_ipv6_clients.py -i eth0 \
    --count 5 \
    --duid "00:03:00:01:00:11:22:33:44:00" \
    --iaid 1000 \
    --apply-lease

# Custom ORO: also request Bootfile URL (59) and DNS (23, 24)
sudo python3 simulate_IANA_IAPD_ipv6_clients.py -i eth0 \
    --request-options "16,17,23,24,39,59" \
    --timeout 15

# Release a previously leased IA_NA address (DUID + IAID identify the lease; address is not checked)
sudo python3 simulate_IANA_IAPD_ipv6_clients.py -i eth0 \
    --duid "00:03:00:01:aa:bb:cc:dd:ee:01" \
    --iaid 0x11111111 \
    --release --iana

# Release a delegated IA_PD prefix (server DUID auto-discovered via Solicit)
sudo python3 simulate_IANA_IAPD_ipv6_clients.py -i eth0 \
    --duid "00:03:00:01:aa:bb:cc:dd:ee:01" \
    --iaid 0x11111111 \
    --release --iapd

# Release 3 simulated clients at once (DUID last byte / IAID auto-incremented per client)
sudo python3 simulate_IANA_IAPD_ipv6_clients.py -i eth0 \
    --count 3 \
    --duid "00:03:00:01:00:11:22:33:44:00" \
    --iaid 1000 \
    --release --iana

# Release with an explicit server DUID (skips the discovery Solicit)
sudo python3 simulate_IANA_IAPD_ipv6_clients.py -i eth0 \
    --duid "00:03:00:01:aa:bb:cc:dd:ee:01" \
    --iaid 0x11111111 \
    --release --iana --server-duid "00:01:00:01:..."
```

## Usage in cram tests

The cram tests in this directory use the simulator with fixed `--duid` and `--iaid` values so that the same client identity can be presented across multiple runs. Output is redirected to a temp file and then parsed with `awk`/`grep`.

Extract the leased address or prefix from the summary:

```bash
# IA_NA
awk '/Leased Addr\/Prefix:/{print $NF}' /tmp/out.txt
# => 2001:db8:1::100

# IA_PD
awk '/Leased Addr\/Prefix:/{print $NF}' /tmp/out_pd.txt
# => 2001:db8:1:1000::/60
```

Check for success:

```bash
grep -F "[SUCCESS]" /tmp/out.txt
```

Check that a lease was released (reuse the same `--duid`/`--iaid` that obtained the lease):

```bash
grep -F "[RELEASE_SUCCESS]" /tmp/out_release.txt
```

## Notes

- Only one of `--pd` (IA_PD) or address mode (IA_NA) is active per run for the Solicit/Request flow. To test both, invoke the script twice with different `--iaid` values.
- `--apply-lease` applies only in IA_NA mode; IA_PD prefixes are never automatically configured on the interface.
- When `--count > 1` each client runs sequentially, with a short gap between them (1s for the Solicit/Request flow, 0.5s for `--release`).
- The sniffer waits up to `2 × --timeout` seconds total for the REPLY before giving up during Solicit/Request; `--release` waits up to `--timeout` seconds for the RELEASE's REPLY.
- `--release` requires exactly one of `--iana` / `--iapd`; odhcpd looks up the lease by Client DUID + IAID only, so `--release-address` is optional and, when provided, is not validated against the server's lease table.