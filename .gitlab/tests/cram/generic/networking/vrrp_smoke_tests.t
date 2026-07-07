Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Set BASE_NETDEV to any lan iface different from CDROUTER_CONFIG_LAN_IFACE_ALIAS

Set lan iface for VRRP:
  $ case "$DUT_BOARD" in
  >   mxl25641-hdk-6) BASE_NETDEV="${BASE_NETDEV:-cpe-10g}" ;;
  >   wnc-freedom)    BASE_NETDEV="${BASE_NETDEV:-cpe-lan4}" ;;
  >   *) exit 80 ;;
  > esac


Remove targeted lan interface from the bridge (br-lan)
  $ BASE_BRIDGE_PORT=$(R "ba-cli -l 'resolve Device.Bridging.Bridge.lan.Port.[Alias==\"$BASE_NETDEV\"].'" | grep -Ev '^(>|$)')
  $ test -n "$BASE_BRIDGE_PORT"
  $ BASE_ETH_INTF=$(R "ba-cli -l 'resolve Device.Ethernet.Interface.[Alias==\"$BASE_NETDEV\"].'" | grep -Ev '^(>|$)')
  $ test -n "$BASE_ETH_INTF"
  $ R "ba-cli -l $BASE_BRIDGE_PORT.Enable=0" | grep -Ev '^(>|$)'
  0

Create Ethernet.Link. and IP.Interface. objects on top of it:

  $ R "ba-cli 'Device.Ethernet.Link.+{Alias=\"vrrp-lan\",Name=\"$BASE_NETDEV\",LowerLayers=\"$BASE_ETH_INTF\",Enable=1}'" > /dev/null 2>&1
  $ BASE_ETH_LINK=$(R "ba-cli -l 'resolve Device.Ethernet.Link.vrrp-lan.'" | grep -Ev '^(>|$)')
  $ test -n "$BASE_ETH_LINK"

  $ R "ba-cli 'Device.IP.Interface.+{Alias=\"vrrp-lan\",Enable=1,IPv4Enable=1,IPv6Enable=1,LowerLayers=\"$BASE_ETH_LINK\"}'" > /dev/null 2>&1
  $ BASE_INTERFACE=$(R "ba-cli -l 'resolve Device.IP.Interface.vrrp-lan.'" | grep -Ev '^(>|$)')
  $ BASE_INTERFACE=${BASE_INTERFACE%.}
  $ test -n "$BASE_INTERFACE"

  $ R "ba-cli '$BASE_INTERFACE.IPv4Address.+{Alias=\"vrrp-lan\",Enable=1,IPAddress=\"192.168.111.1\",SubnetMask=\"255.255.255.0\"}'" > /dev/null 2>&1
  $ R "ba-cli '$BASE_INTERFACE.IPv6Prefix.+{Alias=\"vrrp-lan-ipv6\",Enable=1,Prefix=\"2001:db8:4582:1110::/64\",StaticType=\"Static\",OnLink=1,Autonomous=1}'" > /dev/null 2>&1
  $ BASE_IPV6_PREFIX_OBJ=$(R "ba-cli -l 'resolve Device.IP.Interface.vrrp-lan.IPv6Prefix.vrrp-lan-ipv6.'" | grep -Ev '^(>|$)')
  $ test -n "$BASE_IPV6_PREFIX_OBJ"
  $ R "ba-cli '$BASE_INTERFACE.IPv6Address.+{Alias=\"vrrp-lan-ipv6\",Enable=1,IPAddress=\"2001:db8:4582:1110::1\",Prefix=\"$BASE_IPV6_PREFIX_OBJ\"}'" > /dev/null 2>&1

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

Create and configure a virtual router IPv4 Version:

  $ R "ba-cli -l 'Device.X_PRPLWARE-COM_VRRP.VirtualRouter+ {Alias=\"vrrp-1\", Enable=true, VRID=111, Interface=\"$BASE_INTERFACE\", AcceptMode=true, VirtualIPAddresses=\"192.168.111.10/24\"}'" > /dev/null 2>&1

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

Configure Tracking:

  $ R "ba-cli -l 'Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-1.Track.Interface+ {Alias=\"vrrp-iface-1\", PriorityDecrement=40, Interface=\"Device.IP.Interface.2.\", Enable=1}'" > /dev/null 2>&1

Verify Virtual Router Instance Enable/Disable Lifecycle (IPv4):

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-1.Enable=0" | grep -Ev '^(>|$)'
  0

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-1.Status?" | grep -Ev '^(>|$)'
  Disabled

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-1.State?" | grep -Ev '^(>|$)'
  Initialize

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-1.Enable=1" | grep -Ev '^(>|$)'
  1

  $ R 'for i in $(seq 1 10); do
  >   ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-1.State? | grep -qx Active && exit 0
  >   sleep 1
  > done
  > exit 1'
  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-1.Status?" | grep -Ev '^(>|$)'
  Enabled

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-1.State?" | grep -Ev '^(>|$)'
  Active

Verify Global VRRP Service Enable/Disable Lifecycle (IPv4):

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.Enable=0" | grep -Ev '^(>|$)'
  0

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-1.Status?" | grep -Ev '^(>|$)'
  StackDisabled

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-1.State?" | grep -Ev '^(>|$)'
  Initialize

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.Enable=1" | grep -Ev '^(>|$)'
  1

  $ R 'for i in $(seq 1 10); do
  >   ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-1.State? | grep -qx Active && exit 0
  >   sleep 1
  > done
  > exit 1'
  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-1.Status?" | grep -Ev '^(>|$)'
  Enabled

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-1.State?" | grep -Ev '^(>|$)'
  Active

Configure IPv6 Virtual Router instance:

  $ R "ba-cli -l 'Device.X_PRPLWARE-COM_VRRP.VirtualRouter+ {Alias=\"vrrp-2\", IPVersion=6, Enable=true, VRID=111, Interface=\"$BASE_INTERFACE\", AcceptMode=false, VirtualIPAddresses=\"fe80::111,2001:db8:4582:1110::10\"}'" > /dev/null 2>&1

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

  $ R 'for i in $(seq 1 10); do
  >   ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-2.State? | grep -qx Active && exit 0
  >   sleep 1
  > done
  > exit 1'
  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-2.Status?" | grep -Ev '^(>|$)'
  Enabled

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-2.State?" | grep -Ev '^(>|$)'
  Active

Verify Global VRRP Service Enable/Disable Lifecycle (IPv6):

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.Enable=0" | grep -Ev '^(>|$)'
  0

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-2.Status?" | grep -Ev '^(>|$)'
  StackDisabled

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-2.State?" | grep -Ev '^(>|$)'
  Initialize

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.Enable=1" | grep -Ev '^(>|$)'
  1

  $ R 'for i in $(seq 1 10); do
  >   ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-2.State? | grep -qx Active && exit 0
  >   sleep 1
  > done
  > exit 1'
  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-2.Status?" | grep -Ev '^(>|$)'
  Enabled

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-2.State?" | grep -Ev '^(>|$)'
  Active

Restore Initial State:

  $ R "ba-cli 'Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-1.-'" > /dev/null 2>&1

  $ R "ba-cli 'Device.X_PRPLWARE-COM_VRRP.VirtualRouter.vrrp-2.-'" > /dev/null 2>&1

  $ R "ba-cli -l Device.X_PRPLWARE-COM_VRRP.Enable=0" | grep -Ev '^(>|$)'
  0

  $ R "pgrep -af /tmp/keepalived/keepalived.conf"
  [1]

  $ R "ba-cli '${BASE_INTERFACE%.}.-'" > /dev/null 2>&1
  $ R "ba-cli -l 'resolve Device.IP.Interface.vrrp-lan.'" | grep -Ev '^(>|$)'
  [1]

  $ R "ba-cli '${BASE_ETH_LINK%.}.-'" > /dev/null 2>&1
  $ R "ba-cli -l 'resolve Device.Ethernet.Link.vrrp-lan.'" | grep -Ev '^(>|$)'
  [1]

  $ R "ba-cli -l $BASE_BRIDGE_PORT.Enable=1" | grep -Ev '^(>|$)'
  1
