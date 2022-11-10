Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that ubus has all expected services available:

  $ R "ubus list | grep -v '^[[:upper:]]'"
  dhcp
  dnsmasq
  luci-rpc
  network
  network.device
  network.interface
  network.interface.guest
  network.interface.lan
  network.interface.loopback
  network.interface.wan
  network.interface.wan6
  network.wireless
  service
  session
  system
  uci
  umdns

Check that we've correct bridge aliases:

  $ R "ubus call Bridging _get \"{'rel_path':'Bridge.*.Alias'}\" | jsonfilter -e @[*].Alias | sort"
  guest
  lan
  lcm

Check that we've correct DHCP pool settings:

  $ R "ubus call DHCPv4.Server.Pool _get \"{'rel_path':'*'}\" | grep -E '(Alias|MinAddres|MaxAddress|Enable|Servers|Status)' | sort"
  \t\t"Alias": "guest", (esc)
  \t\t"Alias": "lan", (esc)
  \t\t"Alias": "lcm", (esc)
  \t\t"DNSServers": "192.168.1.1", (esc)
  \t\t"DNSServers": "192.168.2.1", (esc)
  \t\t"DNSServers": "192.168.5.1", (esc)
  \t\t"Enable": true, (esc)
  \t\t"Enable": true, (esc)
  \t\t"Enable": true, (esc)
  \t\t"MaxAddress": "192.168.1.249", (esc)
  \t\t"MaxAddress": "192.168.2.249", (esc)
  \t\t"MaxAddress": "192.168.5.249", (esc)
  \t\t"MinAddress": "192.168.1.100", (esc)
  \t\t"MinAddress": "192.168.2.100", (esc)
  \t\t"MinAddress": "192.168.5.100", (esc)
  \t\t"Status": "Enabled", (esc)
  \t\t"Status": "Enabled", (esc)
  \t\t"Status": "Error_Misconfigured", (esc)

  $ R "ubus call DHCPv6.Server.Pool _get \"{'rel_path':'*'}\" | grep -E '(Alias|Enable|Status)' | sort"
  \t\t"Alias": "guest", (esc)
  \t\t"Alias": "lan", (esc)
  \t\t"Alias": "lcm", (esc)
  \t\t"Enable": false, (esc)
  \t\t"Enable": false, (esc)
  \t\t"Enable": true, (esc)
  \t\t"IANAEnable": false, (esc)
  \t\t"IANAEnable": false, (esc)
  \t\t"IANAEnable": false, (esc)
  \t\t"IAPDEnable": false, (esc)
  \t\t"IAPDEnable": false, (esc)
  \t\t"IAPDEnable": false, (esc)
  \t\t"Status": "Disabled", (esc)
  \t\t"Status": "Disabled", (esc)
  \t\t"Status": "Error_Misconfigured", (esc)

Check that we've correct Time.CurrentLocalTime:

  $ time=$(R "ubus call Time _get '{\"rel_path\":\"CurrentLocalTime\"}' | jsonfilter -e @[*].CurrentLocalTime")
  $ time=$(echo $time | sed -E 's/([0-9\-]+)T([0-9]+:[0-9]+:[0-9]+).*/\1 \2/')
  $ time=$(date -d "$time" +'%s')
  $ sys=$(R date +"%s")
  $ diff=$(( (sys - time) ))
  $ tolerance=5
  $ R logger -t cram "Time.CurrentLocalTime=$(date -d @$time +'%c') SystemTime=$(date -d @$sys +'%c') diff=${diff}s tolerance=${tolerance}s"
  $ test "$diff" -le "$tolerance" && echo "Time is OK"
  Time is OK

Check that aclmanager has expected setup:

  $ R "ubus call ACLManager.Role _get '{\"rel_path\":\"*\"}' | jsonfilter -e @[*].Name -e @[*].Alias | sort"
  admin
  cpe-Role-1
  cpe-Role-2
  cpe-Role-3
  guest
  operator

Check that Users.Role component has expected setup:

  $ R "ubus call Users.Role _get '{\"rel_path\":\"\"}' | jsonfilter -e @[*].Alias -e @[*].RoleName | sort"
  acl
  acl-role
  admin
  admin-role
  guest
  guest-role
  webui
  webui-role

Check that we've correct hostname and release info:

  $ R "ubus -S call system board | jsonfilter -e '@.hostname' -e '@.release.distribution'"
  prplOS
  OpenWrt

Check that netifd service is running:

  $ R "ubus -S call service list | jsonfilter -e '@.network.instances.instance1.running'"
  true
