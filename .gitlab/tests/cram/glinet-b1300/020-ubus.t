Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that ubus has hotplug.firmware service available:

  $ R "ubus list | grep hotplug.firmware"
  hotplug.firmware

Check that we've correct system info:

  $ R "ubus call system board | jsonfilter -e @.system -e @.model -e @.board_name"
  ARMv7 Processor rev 5 (v7l)
  GL.iNet GL-B1300
  glinet,gl-b1300

  $ R "ubus call DeviceInfo _get | jsonfilter -e '@[\"DeviceInfo.\"].ProductClass'"
  GL.iNet GL-B1300

Check that we've correct bridge port aliases:

  $ R "ubus call Bridging _get \"{'rel_path':'Bridge.*.Port.*.Alias'}\" | jsonfilter -e @[*].Alias | sort"
  GUEST
  LAN1
  LAN2
  bridge
  default_radio0
  default_radio1
  guest_radio0
  guest_radio1

Check that we've correct ethernet interface details:

  $ R "ubus call Ethernet _get \"{'rel_path':'Interface.'}\" | grep -E '(Alias|Enable|Name)' | sort"
  \t\t"Alias": "LAN1", (esc)
  \t\t"Alias": "LAN2", (esc)
  \t\t"Alias": "WAN", (esc)
  \t\t"EEEEnable": false, (esc)
  \t\t"EEEEnable": false, (esc)
  \t\t"EEEEnable": false, (esc)
  \t\t"Enable": true, (esc)
  \t\t"Enable": true, (esc)
  \t\t"Enable": true, (esc)
  \t\t"Name": "lan1", (esc)
  \t\t"Name": "lan2", (esc)
  \t\t"Name": "wan", (esc)

Check that we've correct ethernet link details:

  $ R "ubus call Ethernet _get \"{'rel_path':'Link.'}\" | grep -E '(Alias|Enable|Name)' | sort"
  \t\t"Alias": "GUEST", (esc)
  \t\t"Alias": "LAN", (esc)
  \t\t"Alias": "LO", (esc)
  \t\t"Alias": "WAN", (esc)
  \t\t"Enable": true, (esc)
  \t\t"Enable": true, (esc)
  \t\t"Enable": true, (esc)
  \t\t"Enable": true, (esc)
  \t\t"Name": "br-guest", (esc)
  \t\t"Name": "br-lan", (esc)
  \t\t"Name": "lo", (esc)
  \t\t"Name": "wan", (esc)

Check that IP.Interface provides expected output:

  $ R "ubus call IP _get '{\"rel_path\":\"Interface.\",\"depth\":100}' | jsonfilter -e @[*].Alias -e @[*].Name -e @[*].IPAddress -e @[*].SubnetMask | sort" | egrep -v '(^f[0-9a-z:]+|^$)'
  10.0.0.2
  127.0.0.1
  192.168.1.1
  192.168.2.1
  255.0.0.0
  255.255.255.0
  255.255.255.0
  255.255.255.0
  ::1
  GUA
  GUA
  GUA_IAPD
  GUA_IAPD
  GUA_RA
  GUA_RA
  ULA
  ULA64
  br-guest
  br-lan
  guest
  guest
  lan
  lan
  lo
  loopback
  loopback_ipv4
  loopbackipv6
  wan
  wan

Check that NAT.Interface provides expected output:

  $ R "ubus call NAT _get '{\"rel_path\":\"InterfaceSetting.\",\"depth\":100}' | jsonfilter -e @[*].Alias -e @[*].Interface"
  lan
  guest
  wan
  br-lan
  br-guest
  wan

Check that NetDev.Link provides expected output:

  $ R "ubus call NetDev _get '{\"rel_path\":\"Link.\",\"depth\":100}' | jsonfilter -e @[*].Name | sort"
  br-guest
  br-lan
  br-lan
  eth0
  lan1
  lan2
  lo
  teql0
  veth_gene_0
  wan
  wlan0
  wlan1

Check that NetModel.Intf provides expected output:

  $ R "ubus call NetModel _get '{\"rel_path\":\"Intf.\",\"depth\":100}' | jsonfilter -e @[*].Alias -e @[*].Flags -e @[*].Name -e @[*].Status | sed '/^$/d' | sort"
  bridge
  bridge
  bridge-GUEST
  bridge-GUEST
  bridge-bridge
  bridge-bridge
  bridgeport-LAN1
  bridgeport-LAN1
  bridgeport-LAN2
  bridgeport-LAN2
  bridgeport-default_radio0
  bridgeport-default_radio0
  bridgeport-default_radio1
  bridgeport-default_radio1
  bridgeport-guest_radio0
  bridgeport-guest_radio0
  bridgeport-guest_radio1
  bridgeport-guest_radio1
  ethIntf-LAN1
  ethIntf-LAN1
  ethIntf-LAN2
  ethIntf-LAN2
  ethIntf-WAN
  ethIntf-WAN
  ethLink-GUEST
  ethLink-GUEST
  ethLink-LAN
  ethLink-LAN
  ethLink-LO
  ethLink-LO
  ethLink-WAN
  ethLink-WAN
  eth_intf netdev
  eth_intf netdev
  eth_intf netdev
  eth_link
  eth_link
  eth_link
  eth_link
  false
  false
  false
  false
  false
  false
  false
  false
  false
  false
  false
  false
  false
  false
  false
  false
  false
  false
  false
  false
  inbridge
  inbridge
  inbridge
  inbridge
  inbridge
  inbridge
  ip netdev
  ip netdev
  ip netdev
  ip netdev dhcpv[46] dhcpv[46] (re)
  ip-guest
  ip-guest
  ip-lan
  ip-lan
  ip-loopback
  ip-loopback
  ip-wan
  ip-wan
  resolver
  resolver
