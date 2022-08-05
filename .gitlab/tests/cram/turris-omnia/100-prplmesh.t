Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Start wireless:

  $ R logger -t cram "Start wireless"
  $ R "uci set wireless.radio0.disabled='0'; uci set wireless.radio1.disabled='0'; uci commit; wifi up"
  $ sleep 30

Check that hostapd is operating after reboot:

  $ R logger -t cram "Check that hostapd is operating after reboot"
  $ R "ps w" | sed -nE 's/.*(\/usr\/sbin\/hostapd.*)/\1/p' | LC_ALL=C sort
  /usr/sbin/hostapd -s -P /var/run/wifi-phy0.pid -B /var/run/hostapd-phy0.conf
  /usr/sbin/hostapd -s -P /var/run/wifi-phy1.pid -B /var/run/hostapd-phy1.conf

Restart prplmesh:

  $ R logger -t cram "Restart prplmesh"
  $ R "/etc/init.d/prplmesh gateway_mode && sleep 5" > /dev/null 2>&1
  $ sleep 60

Check VAP setup after restart:

  $ R logger -t cram "Check VAP setup after restart"
  $ R "iwinfo | grep ESSID"
  wlan0     ESSID: "prplOS"
  wlan0-1   ESSID: "prplOS-guest"
  wlan1     ESSID: "prplOS"
  wlan1-1   ESSID: "prplOS-guest"

Check that prplmesh processes are running:

  $ R logger -t cram "Check that prplmesh processes are running"
  $ R "ps w" | sed -nE 's/.*(\/opt\/prplmesh\/bin.*)/\1/p' | LC_ALL=C sort
  /opt/prplmesh/bin/beerocks_agent
  /opt/prplmesh/bin/beerocks_controller
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan0
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan1
  /opt/prplmesh/bin/ieee1905_transport

Check that prplmesh is operational:

  $ R logger -t cram "Check that prplmesh is operational"
  $ R "/opt/prplmesh/scripts/prplmesh_utils.sh status" | sed -E 's/.*(\/opt\/prplmesh.*)/\1/' | LC_ALL=C sort
  \x1b[0m (esc)
  \x1b[0m\x1b[1;32mOK Main radio agent operational (esc)
  \x1b[1;32moperational test success! (esc)
  /opt/prplmesh/bin/beerocks_agent
  /opt/prplmesh/bin/beerocks_controller
  /opt/prplmesh/bin/beerocks_controller
  /opt/prplmesh/bin/beerocks_fronthaul
  /opt/prplmesh/bin/beerocks_fronthaul
  /opt/prplmesh/bin/ieee1905_transport
  /opt/prplmesh/scripts/prplmesh_utils.sh: status
  OK wlan0 radio agent operational
  OK wlan1 radio agent operational
  executing operational test using bml

Check that prplmesh is in operational state:

  $ R logger -t cram "Check that prplmesh is in operational state"
  $ R "/opt/prplmesh/bin/beerocks_cli -c bml_conn_map" | egrep '(wlan|OK)' | sed -E "s/.*: (wlan[0-9.]+) .*/\1/" | LC_ALL=C sort
  bml_connect: return value is: BML_RET_OK, Success status
  bml_disconnect: return value is: BML_RET_OK, Success status
  bml_nw_map_query: return value is: BML_RET_OK, Success status
  wlan0
  wlan0.0
  wlan0.1
  wlan1
  wlan1.0
  wlan1.1
