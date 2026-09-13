End-to-end GRE tunnel test (IPv4-over-IPv4). The remote peer runs in a
network namespace on the DUT, connected through a veth pair that
emulates the WAN link, so the test is self-contained.

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting GRE E2E test"

Create the peer network namespace with a veth link emulating the WAN:

  $ R "(ip netns add grepeer; \
  >     ip link add veth-gre type veth peer name veth-grep; \
  >     ip link set veth-grep netns grepeer; \
  >     ip addr add 192.168.78.1/24 dev veth-gre; \
  >     ip link set veth-gre up; \
  >     ip netns exec grepeer ip addr add 192.168.78.2/24 dev veth-grep; \
  >     ip netns exec grepeer ip link set veth-grep up; \
  >     ip netns exec grepeer ip link set lo up) > /dev/null 2>&1"

Configure the GRE peer endpoint inside the namespace:

  $ R "(ip netns exec grepeer ip tunnel add gre1 mode gre remote 192.168.78.1 local 192.168.78.2; \
  >     ip netns exec grepeer ip addr add 10.0.1.1 dev gre1; \
  >     ip netns exec grepeer ip link set gre1 up) > /dev/null 2>&1"

Configure the CPE tunnel through the data model:

  $ GRETIDX=$(R "ba-cli 'GRE.Tunnel.+{Alias=\"e2e\",Enable=1,RemoteEndpoints=\"192.168.78.2\",DeliveryHeaderProtocol=\"IPv4\"}'" 2>/dev/null | sed -ne 's/^GRE.Tunnel.\([0-9]\+\).$/\1/p')
  $ R "ba-cli 'GRE.Tunnel.e2e.Interface.+{Alias=\"i1\",Enable=1}'" > /dev/null 2>&1
  $ sleep 3
  $ GREIFACE=$(R "ba-cli 'GRE.Tunnel.e2e.Interface.1.Name?'" | sed -ne 's/.*Name="\(.*\)"$/\1/p')

Assign an IPv4 address to the CPE GRE interface through the data model:

  $ IPIDX=$(R "ba-cli 'IP.Interface.+{Alias=\"gre-e2e\",Enable=1,IPv4Enable=1,LowerLayers=\"Device.GRE.Tunnel.$GRETIDX.Interface.1.\",Router=\"Device.Routing.Router.1.\"}'" 2>/dev/null | sed -ne 's/^IP.Interface.\([0-9]\+\).$/\1/p')
  $ R "ba-cli 'IP.Interface.$IPIDX.IPv4Address.+{Alias=\"gre-e2e\",AddressingType=\"Static\",IPAddress=\"10.0.1.2\",SubnetMask=\"255.255.255.0\",Enable=1}'" > /dev/null 2>&1
  $ sleep 3

A route to 10.0.1.0/24 through the GRE interface is installed on the CPE:

  $ R "ip route show 10.0.1.0/24 | grep -c \"dev $GREIFACE\""
  1

Without a return route on the peer, echo replies do not come back:

  $ R "ping -c 1 -W 2 10.0.1.1 > /dev/null 2>&1; echo \$?"
  1

Add the return route on the peer and observe echo replies:

  $ R "ip netns exec grepeer ip route add 10.0.1.2 dev gre1"
  $ R "ping -c 3 -W 5 10.0.1.1 > /dev/null 2>&1; echo \$?"
  0

Enable GRE sequence numbering on the CPE; traffic still passes:

  $ R "ba-cli 'GRE.Tunnel.e2e.Interface.1.UseSequenceNumber=1'" > /dev/null 2>&1
  $ sleep 2
  $ R "ip -d link show $GREIFACE | grep -c oseq"
  1
  $ R "ping -c 3 -W 5 10.0.1.1 > /dev/null 2>&1; echo \$?"
  0

Enable GRE output checksum on the CPE; the peer does not accept
checksummed packets yet, so echo replies stop:

  $ R "ba-cli 'GRE.Tunnel.e2e.Interface.1.UseChecksum=1'" > /dev/null 2>&1
  $ sleep 2
  $ R "ip -d link show $GREIFACE | grep -c ocsum"
  1
  $ R "ping -c 1 -W 2 10.0.1.1 > /dev/null 2>&1; echo \$?"
  1

Enable GRE input checksum on the peer; echo replies come back again:

  $ R "ip netns exec grepeer ip link set gre1 type gre icsum"
  $ R "ping -c 3 -W 5 10.0.1.1 > /dev/null 2>&1; echo \$?"
  0

Run a short throughput test through the tunnel:

  $ R "ip netns exec grepeer iperf3 -s -D > /dev/null 2>&1"
  $ sleep 1
  $ R "iperf3 -c 10.0.1.1 -t 2 > /dev/null 2>&1; echo \$?"
  0
  $ R "killall iperf3 > /dev/null 2>&1; true"

Cleanup:

  $ R "ba-cli 'IP.Interface.$IPIDX.-'" > /dev/null 2>&1
  $ R "ba-cli 'GRE.Tunnel.e2e-'" > /dev/null 2>&1
  $ R "ip netns del grepeer > /dev/null 2>&1; true"

  $ R logger -t cram "GRE E2E test finished"
