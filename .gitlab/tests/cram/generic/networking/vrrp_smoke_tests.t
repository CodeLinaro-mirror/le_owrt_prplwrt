Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ wait_state() {
  >   R "for i in \$(seq 1 10); do
  >     ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.$1.State? | grep -qx '$2' && exit 0
  >     sleep 1
  >   done
  >   exit 1"
  > }

Scapy runs on the testbed host:

  $ python3 -c "import scapy.all" || exit 1
  $ test -n "$TESTBED_LAN_INTERFACE" || exit 1

Create br-lan <-> veth-br <-> veth-vrrp <-> macvlan@veth-vrrp.

  $ BRIDGE_NF=$(R 'sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables 2>/dev/null' | tr -d ' ' | tr '\n' ' ')
  $ R 'ip link add veth-br address fe:00:00:00:01:01 type veth peer name veth-vrrp address fe:00:00:00:01:02' || exit 1
  $ cleanup() {
  >   touch "$PWD/vrrp-peer.stop"
  >   if [ -n "${PEER_PID:-}" ]; then wait "$PEER_PID"; fi
  >   R 'ba-cli "Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-1.-"
  >      ba-cli "Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-2.-"
  >      ba-cli "Device.X_PRPLWARE-COM_VRRP.Enable=0"
  >      ba-cli "Device.IP.Interface.vrrp-lan.-"
  >      ba-cli "NetModel.Intf.ethLink-vrrp-lan.clearFlag(flag=\"netdev\",traverse=\"this\")"
  >      ba-cli "Device.Ethernet.Link.vrrp-lan.-"
  >      ip link delete veth-br' >/dev/null 2>&1
  >   if [ -n "$BRIDGE_NF" ]; then R "sysctl -q $BRIDGE_NF"; fi
  > }
  $ trap cleanup EXIT

Disable bridge netfilter only for this test's bridged topology.
Production supports a detached LAN interface and does not need this change:

  $ for setting in $BRIDGE_NF; do R "sysctl -q ${setting%=*}=0" || exit 1; done
  $ R 'ip link set veth-br master br-lan && ip link set veth-br up && ip link set veth-vrrp up' || exit 1

Create Ethernet.Link for veth-vrrp and stack IP.Interface on that link:

  $ R "ba-cli 'Device.Ethernet.Link.+{Alias=\"vrrp-lan\",Name=\"veth-vrrp\",Enable=1}'" > /dev/null 2>&1
  $ BASE_ETH_LINK=$(R "ba-cli -l 'resolve Device.Ethernet.Link.vrrp-lan.'" | grep -Ev '^(>|$)')
  $ test -n "$BASE_ETH_LINK" || exit 1

Bind the standalone Ethernet.Link to its netdev:

  $ R 'ba-cli "NetModel.Intf.ethLink-vrrp-lan.clearFlag(flag=\"netdev\",traverse=\"this\")"; ba-cli "NetModel.Intf.ethLink-vrrp-lan.setFlag(flag=\"netdev\",traverse=\"this\")"' >/dev/null 2>&1

  $ R "ba-cli 'Device.IP.Interface.+{Alias=\"vrrp-lan\",Enable=1,IPv4Enable=1,IPv6Enable=1,LowerLayers=\"$BASE_ETH_LINK\"}'" > /dev/null 2>&1
  $ BASE_INTERFACE=$(R "ba-cli -l 'resolve Device.IP.Interface.vrrp-lan.'" | grep -Ev '^(>|$)')
  $ BASE_INTERFACE=${BASE_INTERFACE%.}
  $ test -n "$BASE_INTERFACE" || exit 1

  $ R "ba-cli '$BASE_INTERFACE.IPv4Address.+{Alias=\"vrrp-lan\",Enable=1,IPAddress=\"192.168.111.1\",SubnetMask=\"255.255.255.0\"}'" > /dev/null 2>&1
  $ R "ba-cli '$BASE_INTERFACE.IPv6Prefix.+{Alias=\"vrrp-lan-ipv6\",Enable=1,Prefix=\"fd00:111::/64\",StaticType=\"Static\",OnLink=1,Autonomous=1}'" > /dev/null 2>&1
  $ BASE_IPV6_PREFIX_OBJ=$(R "ba-cli -l 'resolve Device.IP.Interface.vrrp-lan.IPv6Prefix.vrrp-lan-ipv6.'" | grep -Ev '^(>|$)')
  $ test -n "$BASE_IPV6_PREFIX_OBJ" || exit 1
  $ R "ba-cli '$BASE_INTERFACE.IPv6Address.+{Alias=\"vrrp-lan-ipv6\",Enable=1,IPAddress=\"fd00:111::1\",Prefix=\"$BASE_IPV6_PREFIX_OBJ\"}'" > /dev/null 2>&1

Wait for the base interface:

  $ R 'for i in $(seq 1 10); do
  >   ba-cli -l Device.IP.Interface.vrrp-lan.Name? | grep -qx veth-vrrp &&
  >     ip -4 addr show dev veth-vrrp | grep -q "192.168.111.1/24" &&
  >     ip -6 addr show dev veth-vrrp | grep -q "scope link" && exit 0
  >   sleep 1
  > done
  > exit 1' || exit 1

Check Initial VRRP Service State:

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.Enable?" | grep -Ev '^(>|$)'
  0

  $ R "pgrep -af /tmp/keepalived/keepalived.conf"
  [1]

Enable VRRP:

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.Enable=1" | grep -Ev '^(>|$)'
  1

  $ R "pgrep -af '/tmp/keepalived/keepalived.conf'"
  .* /tmp/keepalived/keepalived\.conf$ (re)

Create and configure an IPv4 virtual router:

  $ R "ba-cli -l 'Device.X_PRPLWARE-COM_VRRP.VirtualRouter+ {Alias=\"vrrp-1\", Enable=true, VRID=111, Interface=\"$BASE_INTERFACE\", AcceptMode=true, VirtualIPAddresses=\"192.168.111.10\"}'" > /dev/null 2>&1

Verify Virtual Router IPv4 Instance Enabled:

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-1.Status?" | grep -Ev '^(>|$)'
  Enabled

Verify Virtual MAC Address and VRID Changes:

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-1.VirtualMACAddress?" | grep -Ev '^(>|$)'
  00-00-5E-00-01-6F

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-1.VRID=123" | grep -Ev '^(>|$)'
  123

Changing VRID from 111 (0x6F) to 123 (0x7B) must update the last MAC octet
while preserving the IPv4 VRRP prefix (00-00-5E-00-01).

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-1.VirtualMACAddress?" | grep -Ev '^(>|$)'
  00-00-5E-00-01-7B

Verify IsOwner Configuration for Virtual Router (IPv4):

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-1.IsOwner?" | grep -Ev '^(>|$)'
  0

Verify Virtual Router Instance Enable/Disable Lifecycle (IPv4):

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-1.Enable=0" | grep -Ev '^(>|$)'
  0

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-1.Status?" | grep -Ev '^(>|$)'
  Disabled

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-1.State?" | grep -Ev '^(>|$)'
  Initialize

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-1.Enable=1" | grep -Ev '^(>|$)'
  1

  $ wait_state vrrp-1 Active
  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-1.Status?" | grep -Ev '^(>|$)'
  Enabled

Verify Global VRRP Service Enable/Disable Lifecycle (IPv4):

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.Enable=0" | grep -Ev '^(>|$)'
  0

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-1.Status?" | grep -Ev '^(>|$)'
  StackDisabled

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-1.State?" | grep -Ev '^(>|$)'
  Initialize

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.Enable=1" | grep -Ev '^(>|$)'
  1

  $ wait_state vrrp-1 Active
  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-1.Status?" | grep -Ev '^(>|$)'
  Enabled

Create and configure an IPv6 virtual router:

  $ R "ba-cli -l 'Device.X_PRPLWARE-COM_VRRP.VirtualRouter+ {Alias=\"vrrp-2\", IPVersion=6, Enable=true, VRID=111, Interface=\"$BASE_INTERFACE\", AcceptMode=false, VirtualIPAddresses=\"fe80::111,fd00:111::10\"}'" > /dev/null 2>&1

Verify Virtual Router IPv6 Instance Enabled:

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-2.Status?" | grep -Ev '^(>|$)'
  Enabled

Verify Virtual MAC Address and VRID Changes (IPv6):

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-2.VirtualMACAddress?" | grep -Ev '^(>|$)'
  00-00-5E-00-02-6F

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-2.VRID=122" | grep -Ev '^(>|$)'
  122

Changing VRID from 111 (0x6F) to 122 (0x7A) must update the last MAC octet
while preserving the IPv6 VRRP prefix (00-00-5E-00-02).

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-2.VirtualMACAddress?" | grep -Ev '^(>|$)'
  00-00-5E-00-02-7A

Verify IsOwner Configuration for Virtual Router (IPv6):

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-2.IsOwner?" | grep -Ev '^(>|$)'
  0

Verify Virtual Router Instance Enable/Disable Lifecycle (IPv6):

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-2.Enable=0" | grep -Ev '^(>|$)'
  0

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-2.Status?" | grep -Ev '^(>|$)'
  Disabled

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-2.State?" | grep -Ev '^(>|$)'
  Initialize

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-2.Enable=1" | grep -Ev '^(>|$)'
  1

  $ wait_state vrrp-2 Active
  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-2.Status?" | grep -Ev '^(>|$)'
  Enabled

Verify Global VRRP Service Enable/Disable Lifecycle (IPv6):

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.Enable=0" | grep -Ev '^(>|$)'
  0

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-2.Status?" | grep -Ev '^(>|$)'
  StackDisabled

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-2.State?" | grep -Ev '^(>|$)'
  Initialize

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.Enable=1" | grep -Ev '^(>|$)'
  1

  $ wait_state vrrp-2 Active
  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-2.Status?" | grep -Ev '^(>|$)'
  Enabled

Send peer advertisements until the state checks finish:

  $ if [ "$(id -u)" = 0 ]; then SUDO=""; else SUDO="sudo -E"; fi
  $ start_peer() {
  >   rm -f "$PWD/vrrp-peer.stop"
  >   $SUDO python3 "$TESTDIR/vrrp_peer.py" --iface "$TESTBED_LAN_INTERFACE" --stop-file "$PWD/vrrp-peer.stop" "$@" >"$PWD/vrrp-peer.log" 2>&1 &
  >   PEER_PID=$!
  > }
  $ stop_peer() {
  >   touch "$PWD/vrrp-peer.stop"
  >   wait "$PEER_PID"
  >   result=$?
  >   PEER_PID=""
  >   if [ "$result" != 0 ]; then cat "$PWD/vrrp-peer.log"; fi
  >   return "$result"
  > }
  $ received() {
  >   R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.$1.Stats.AdvertisementsReceived?" | grep -Ev '^(>|$)'
  > }
  $ wait_received() {
  >   R "for i in \$(seq 1 10); do
  >     count=\$(ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.$1.Stats.AdvertisementsReceived? | grep -Ev '^(>|$)')
  >     test -n \"\$count\" && test \"\$count\" -gt '$2' && exit 0
  >     sleep 1
  >   done
  >   exit 1"
  > }

IPv4: a priority-50 peer must not displace the local priority-100 Active.

  $ wait_state vrrp-1 Active
  $ RX_BEFORE=$(received vrrp-1)
  $ test -n "$RX_BEFORE" || exit 1
  $ start_peer --source 192.168.111.2 --vip 192.168.111.10 --vrid 123 --priority 50 || exit 1
  $ wait_received vrrp-1 "$RX_BEFORE"
  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-1.State?" | grep -Ev '^(>|$)'
  Active
  $ stop_peer

IPv4: priority 200 makes the DUT Backup; stopping the peer restores Active.

  $ RX_BEFORE=$(received vrrp-1)
  $ test -n "$RX_BEFORE" || exit 1
  $ start_peer --source 192.168.111.2 --vip 192.168.111.10 --vrid 123 --priority 200 || exit 1
  $ wait_received vrrp-1 "$RX_BEFORE"
  $ wait_state vrrp-1 Backup
  $ stop_peer
  $ wait_state vrrp-1 Active

IPv6: repeat with a link-local source and the configured VIP list.

  $ wait_state vrrp-2 Active
  $ RX_BEFORE=$(received vrrp-2)
  $ test -n "$RX_BEFORE" || exit 1
  $ start_peer --source fe80::2 --vip fe80::111 fd00:111::10 --vrid 122 --priority 50 || exit 1
  $ wait_received vrrp-2 "$RX_BEFORE"
  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-2.State?" | grep -Ev '^(>|$)'
  Active
  $ stop_peer

  $ RX_BEFORE=$(received vrrp-2)
  $ test -n "$RX_BEFORE" || exit 1
  $ start_peer --source fe80::2 --vip fe80::111 fd00:111::10 --vrid 122 --priority 200 || exit 1
  $ wait_received vrrp-2 "$RX_BEFORE"
  $ wait_state vrrp-2 Backup
  $ stop_peer
  $ wait_state vrrp-2 Active

Restore Initial State:

  $ cleanup
  $ trap - EXIT

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.Enable?" | grep -Ev '^(>|$)'
  0

  $ R "pgrep -af /tmp/keepalived/keepalived.conf"
  [1]

  $ R "ba-cli -l 'resolve Device.IP.Interface.vrrp-lan.'" | grep -Ev '^(>|$)'
  [1]

  $ R "ba-cli -l 'resolve Device.Ethernet.Link.vrrp-lan.'" | grep -Ev '^(>|$)'
  [1]
