# IPv6 CRAM experiment (CI-69)

The QEMU CRAM job provides a WAN DHCPv6 server and a separate LAN client
for testing IPv6 routing and NPTv6 with an existing firmware image.

## Image and firmware

The testbed-qemu image includes `kea-dhcp6-server` and `radvd`.
`CI69_TESTBED_IMAGE` pins the published container image by digest.

`CI69_FIRMWARE_URL` and `CI69_FIRMWARE_SHA256` select an existing gzip-compressed
squashfs combined EFI disk.
The `fetch QEMU firmware` job verifies and unpacks it into the standard
`bin/targets/x86/64/` artifact path.
The CRAM job downloads that artifact through `needs`; firmware is not built.
QEMU runs a disposable copy.

## Network setup

`testbed-qemu` starts Kea, radvd and a LAN client namespace alongside its bridges
and TAP devices, before booting the DUT.
It exports access to them to every payload and tears them down with the network.
It does not wait for PD, RA, addresses or firewall rules, and never writes the DUT datamodel.
The CRAM tests own readiness checks and any DUT configuration and restoration.

```text
LAN client (user+net namespace)       QEMU DUT                  job namespace
SLAAC /64, RA default route ---- br-lan | eth1 ---- br-wan 2001:2:0:1000::1
                                        PD: 2001:2:0:9600::/60
```

Kea delegates a /60; radvd supplies WAN router advertisements.
The DUT uses its default DHCPv6-PD configuration and advertises a LAN /64.
The separate LAN client accepts those RAs and configures its own address and route.
Inside CRAM, `ipv6.py wait-lan` waits for a usable client address in the expected
prefix and an RA default route, then prints shell exports for the observed values.
It configures neither the DUT nor the client.
`--prefix` selects a different expected subnet, such as the NPT example's static LAN prefix.

Kea's run-script hook installs delegated-prefix routes through the requesting
DUT's WAN link-local address in routing table 1069.
The shell hook adds or refreshes routes on committed PD leases.
Released leases remove their routes; otherwise the kernel expires routes at the lease deadline.
The hook does not reconcile delayed callbacks against the lease database.
No global WAN address on the DUT is required.
The hook records its actions and errors in `kea-pd-routes.log`.
A source-specific rule selects that table for traffic bound to the WAN server address.
An unreachable default prevents fallback through the controller LAN when no lease route exists.
The harness reserves the table and rule priority and removes them on exit.
The route helper accepts the prefix supplied by Kea, so it is not tied to the initial pool.
The examples do not exercise PD replacement.

TAP devices, the host end of the client veth, and controller bridges use
`addrgenmode none` to suppress automatic link-local addresses and Router Solicitations.
The WAN bridge has an explicit link-local address for Kea and radvd.
TAP devices have ARP disabled; bridges retain ARP for controller IPv4 access.
The controller drops RAs on the local IPv6 input path of `br-lan`,
so the service bridge does not acquire SLAAC addresses or RA routes.
The bridges continue to forward guest and client IPv6 frames.
WAN-initiated tests must bind the WAN server source address, for example:

```sh
ping -6 -I "$TESTBED_WAN_ADDRESS" "$TESTBED_LAN_CLIENT_ADDRESS"
ip -6 route get "$TESTBED_LAN_CLIENT_ADDRESS" from "$TESTBED_WAN_ADDRESS"
```

TCP probes bind that source automatically in the WAN-to-LAN direction.
Replies from a TCP server bound to the WAN address also select the fixture route.
Unbound controller traffic keeps its existing routing behavior.
No runner-host namespace or Docker socket is needed.
The fixture creates the namespace from inside the job container.
It uses `unshare --user --map-root-user --net`.

The fixture leaves firewall policy and NPTv6 configuration to CRAM.
The examples save and restore the original firewall Enable value.
The routing example temporarily disables it for WAN-initiated traffic.
The NPTv6 example explicitly sets ExternalPrefix; PD does not update this string.

## CRAM environment

| Variable | Meaning / use |
| --- | --- |
| `CRAM_REMOTE_COMMAND` | Existing harness SSH command for the DUT |
| `TESTBED_LAN_INTERFACE`, `TESTBED_WAN_INTERFACE` | Existing controller interfaces, unchanged (`br-lan`, `br-wan`) |
| `TESTBED_LAN_CLIENT_EXEC` | Executable wrapper: `"$TESTBED_LAN_CLIENT_EXEC" ping -6 ...` |
| `TESTBED_LAN_CLIENT_INTERFACE` | Client veth name inside its namespace |
| `TESTBED_LAN_CLIENT_ADDRESS`, `TESTBED_LAN_GATEWAY`, `TESTBED_LAN_PREFIX` | SLAAC address, RA gateway and /64 observed by `wait-lan` |
| `TESTBED_WAN_ADDRESS` | WAN server address in the job namespace; bind WAN-originated traffic to it |
| `TESTBED_PD_PREFIX` | Initial delegated /60 expected by the examples |
| `TESTBED_KEA_SOCKET` | Kea's Unix control socket, for direct clients |
| `TESTBED_KEA_CONFIG` | Generated server configuration |

For example:

```sh
alias V6='python3 "$TESTDIR/ipv6.py"'
V6 kea status-get
V6 kea config-get
V6 kea dhcp-disable '{"max-period": 10}'
V6 kea dhcp-enable
"$TESTBED_LAN_CLIENT_EXEC" ip -6 address
V6 tcp lan-to-wan
$CRAM_REMOTE_COMMAND "ba-cli 'NAT.NPTv6.?'"
```

The harness exports access to the client and Kea, together with the fixed server/pool addresses.
LAN address/gateway/subnet variables are produced by the explicit `wait-lan` call
inside each CRAM test.

The LAN wrapper and Kea socket are usable only while the fixture is running.
The wrapper remains as an artifact, but the socket and namespace are removed during cleanup.
`artifacts/ipv6-env.sh` records these exports for debugging inside that session;
it is not an environment that can be reused in another job.
Commands with nonzero Kea result codes exit nonzero.
The socket is local to the job, with no HTTP control service or credentials.

## Examples and artifacts

`CRAM_TEST_SUITE` selects `.gitlab/tests/cram/ci69` and runs only the two examples.
`ipv6-pd.t` checks the Kea configuration, routes through the DUT,
and ping and TCP in both directions.
`nptv6.t` requires firmware with NPTv6 support.
It switches the DUT LAN to the static `2001:2:0:6902::/64` advertised through RA.
The client acquires an address in this prefix through SLAAC.
The translation setting maps the whole `2001:2:0:6900::/60` to the delegated /60.
The TCP probe binds to the acquired address and checks that the WAN server
sees a source in the external prefix and returns the payload.
The test restores the LAN configuration and removes its NPT setting on exit.
`ExternalPrefix` is a literal CIDR; the test sets it explicitly.
Automatic NPT updates following PD changes are not provided by this fixture.
The test first checks translation with filtering disabled, then enables the firewall
and repeats LAN-to-WAN TCP with a live conntrack check.
The entry must be `ESTABLISHED` and `[ASSURED]`, with matching original and reply tuples.
The reply destination must equal the translated source observed by the WAN server.
Conntrack snapshots are saved as `conntrack-<port>.txt`, including after a failed connection.
Benchmark addresses avoid the default firewall's ULA filtering.
The test does not exercise hairpinning or PD changes.

To run both in a local testbed-qemu session, use this payload:

```sh
testbed-qemu cram .gitlab/tests/cram/ci69/ipv6-pd.t .gitlab/tests/cram/ci69/nptv6.t
```

The normal harness artifacts include `cram.txt`, `cram.xml` and failing `.t.err` files.
Additional artifacts include Kea config/leases/log, radvd config/log,
LAN/WAN pcaps, network dumps, conntrack snapshots and `ipv6-env.sh`.
Do not infer packet traversal merely from a successful API call;
the CRAM examples perform real traffic exchanges.

## CI workflow

The CRAM job extends `.qemu-x86-64 testbed`, using its normal setup,
`testbed-qemu run` invocation and artifact collection.
The firmware dependency is the download job.
`CRAM_TEST_SUITE` explicitly selects the two IPv6 tests;
`CRAM_TEST_SUITE_POST` is empty, so no other tests run.

The shared template resolves `COMPONENT` through `components.yml` when no
explicit suite is supplied.
Its default post selection remains `.gitlab/tests/cram/post/generic`.
The IPv6 examples live outside the generic and board directories and are
selected explicitly; they do not alter other component buckets.
Full-suite compatibility has not been tested.
Each job boots a fresh DUT and discards it after its selected tests.

## Cleanup

On exit, the harness stops its services and remaining LAN namespace processes,
deletes the veth pair, and releases the namespace.
It removes its WAN address, policy rule and reserved routing table.
IPv6 cleanup runs before bridge removal.
