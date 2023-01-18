Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that ubus has all expected services available:

  $ R "ubus list | grep -v '^[[:upper:]]'"
  container
  dhcp
  dnsmasq
  dnsmasq.dns
  hostapd
  hotplug.dhcp
  hotplug.ieee80211
  hotplug.iface
  hotplug.neigh
  hotplug.net
  hotplug.ntp
  hotplug.tftp
  network
  network.device
  network.interface
  network.interface.guest
  network.interface.lan
  network.interface.loopback
  network.interface.wan
  network.interface.wan6
  network.wireless
  rc
  service
  session
  system
  uci
  umdns
  wpa_supplicant

Check that we've correct system info:

  $ R "ubus call system board | jsonfilter -e @.system -e @.model -e @.board_name"
  ARMv7 Processor rev 1 (v7l)
  Turris Omnia
  cznic,turris-omnia
