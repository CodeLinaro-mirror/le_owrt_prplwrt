End-to-end WireGuard tunnel test. The remote peer runs in a network
namespace on the DUT, connected through a veth pair that emulates the
WAN link, so the test is self-contained.

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting WireGuard E2E test"

Create the peer network namespace with a veth link emulating the WAN:

  $ R "(ip netns add wgpeer; \
  >     ip link add veth-wg type veth peer name veth-wgp; \
  >     ip link set veth-wgp netns wgpeer; \
  >     ip addr add 192.168.77.1/24 dev veth-wg; \
  >     ip link set veth-wg up; \
  >     ip netns exec wgpeer ip addr add 192.168.77.2/24 dev veth-wgp; \
  >     ip netns exec wgpeer ip link set veth-wgp up; \
  >     ip netns exec wgpeer ip link set lo up) > /dev/null 2>&1"

Configure the WireGuard peer endpoint inside the namespace:

  $ R "(umask 077; wg genkey > /tmp/wgpeer.key && wg pubkey < /tmp/wgpeer.key > /tmp/wgpeer.pub) 2>&1"
  $ R "(ip netns exec wgpeer ip link add wg-peer type wireguard; \
  >     ip netns exec wgpeer wg set wg-peer private-key /tmp/wgpeer.key listen-port 51820; \
  >     ip netns exec wgpeer ip addr add 10.0.10.5/24 dev wg-peer; \
  >     ip netns exec wgpeer ip link set wg-peer up) > /dev/null 2>&1"
  $ WGPEERPUB=$(R "cat /tmp/wgpeer.pub")

Configure the CPE tunnel through the data model:

  $ WGTIDX=$(R "ba-cli 'WireGuard.Tunnel.+{Alias=\"e2e\"}'" 2>/dev/null | sed -ne 's/^WireGuard.Tunnel.\([0-9]\+\).$/\1/p')
  $ R "ba-cli 'WireGuard.Tunnel.e2e.Interface.+{Alias=\"i1\",Enable=1}'" > /dev/null 2>&1
  $ WGPIDX=$(R "ba-cli 'WireGuard.Peer.+{Alias=\"peer1\",AllowedIPs=\"10.0.10.5/32\",PublicKey=\"$WGPEERPUB\",EndpointAddress=\"192.168.77.2\",EndpointPort=51820,Enable=1}'" 2>/dev/null | sed -ne 's/^WireGuard.Peer.\([0-9]\+\).$/\1/p')
  $ R "ba-cli 'WireGuard.Tunnel.e2e.PeerReferences=\"Device.WireGuard.Peer.$WGPIDX\"'" > /dev/null 2>&1
  $ R "ba-cli 'WireGuard.Tunnel.e2e.Enable=1'" > /dev/null 2>&1
  $ sleep 3

Point the namespace peer at the CPE endpoint:

  $ CPEPUB=$(R "ba-cli 'WireGuard.Tunnel.e2e.PublicKey?'" | sed -ne 's/.*PublicKey="\(.*\)"$/\1/p')
  $ CPEPORT=$(R "ba-cli 'WireGuard.Tunnel.e2e.ListenPort?'" | sed -ne 's/.*ListenPort=\([0-9]\+\).*/\1/p')
  $ R "ip netns exec wgpeer wg set wg-peer peer \"$CPEPUB\" allowed-ips 10.0.10.1/32 endpoint 192.168.77.1:$CPEPORT persistent-keepalive 5"

Assign an IPv4 address to the CPE tunnel interface through the data model:

  $ IPIDX=$(R "ba-cli 'IP.Interface.+{Alias=\"wg-e2e\",Enable=1,IPv4Enable=1,LowerLayers=\"Device.WireGuard.Tunnel.$WGTIDX.Interface.1.\",Router=\"Device.Routing.Router.1.\"}'" 2>/dev/null | sed -ne 's/^IP.Interface.\([0-9]\+\).$/\1/p')
  $ R "ba-cli 'IP.Interface.$IPIDX.IPv4Address.+{Alias=\"wg-e2e\",AddressingType=\"Static\",IPAddress=\"10.0.10.1\",SubnetMask=\"255.255.255.0\",Enable=1}'" > /dev/null 2>&1
  $ sleep 3

Send traffic through the tunnel (CPE to peer):

  $ R "ping -c 3 -W 10 10.0.10.5 > /dev/null 2>&1; echo \$?"
  0

Verify the handshake completed on the peer side:

  $ R "ip netns exec wgpeer wg show wg-peer latest-handshakes | awk '{print ((\$2 > 0) ? \"handshake-ok\" : \"no-handshake\")}'"
  handshake-ok

Accept tunnel traffic towards the CPE and ping from the peer (WAN to LAN direction):

  $ R "ba-cli 'Firewall.Service.+{Alias=\"wge2e\",SourcePrefixes=\"10.0.10.0/24\",Protocol=1,Interface=\"Device.WireGuard.Tunnel.$WGTIDX.Interface.1\",IPVersion=4,Enable=1}'" > /dev/null 2>&1
  $ sleep 2
  $ R "ip netns exec wgpeer ping -c 3 -W 10 10.0.10.1 > /dev/null 2>&1; echo \$?"
  0

Run a short throughput test through the tunnel:

  $ R "ip netns exec wgpeer iperf3 -s -D > /dev/null 2>&1"
  $ sleep 1
  $ R "iperf3 -c 10.0.10.5 -t 2 > /dev/null 2>&1; echo \$?"
  0
  $ R "killall iperf3 > /dev/null 2>&1; true"

The WireGuard interface is present in NetModel:

  $ WGIFACE=$(R "ba-cli 'WireGuard.Tunnel.e2e.Interface.1.Name?'" | sed -ne 's/.*Name="\(.*\)"$/\1/p')
  $ R "ba-cli 'NetModel.Intf.[Name ~= \""$WGIFACE"\"].Flags?'" | grep -v '>' | grep -F 'Flags=' | grep -c 'wireguard'
  1

Cleanup:

  $ R "ba-cli 'Firewall.Service.wge2e-'" > /dev/null 2>&1
  $ R "ba-cli 'IP.Interface.$IPIDX.-'" > /dev/null 2>&1
  $ R "ba-cli 'WireGuard.Tunnel.e2e-'" > /dev/null 2>&1
  $ R "ba-cli 'WireGuard.Peer.peer1-'" > /dev/null 2>&1
  $ R "(ip netns del wgpeer; rm -f /tmp/wgpeer.key /tmp/wgpeer.pub) > /dev/null 2>&1; true"

  $ R logger -t cram "WireGuard E2E test finished"
