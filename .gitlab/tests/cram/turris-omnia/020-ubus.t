Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that ubus has all expected services available:

  $ R "ubus list | grep -v '^[[:upper:]]'"
  dhcp
  dnsmasq
  hostapd
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
  wpa_supplicant

Check that we've correct system info:

  $ R "ubus call system board | jsonfilter -e @.system -e @.model -e @.board_name"
  ARMv7 Processor rev 1 (v7l)
  Turris Omnia
  cznic,turris-omnia
