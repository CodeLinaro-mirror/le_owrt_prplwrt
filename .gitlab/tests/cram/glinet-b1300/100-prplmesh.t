Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that wireless has desired configuration and state after boot:

  $ R "ubus -S call WiFi.SSID _get | jsonfilter -e @[*].SSID -e @[*].Status | sort"
  Down
  Down
  Down
  Down
  prplOS
  prplOS
  prplOS-guest
  prplOS-guest

  $ R "pgrep hostapd"
  [1]

  $ R "ubus list | grep hostapd."
  [1]

Start wireless:

  $ R logger -t cram "Start wireless"

  $ R "ubus -S call WiFi.Radio.1 _set '{\"parameters\":{\"Enable\":1}}'"
  {"WiFi.Radio.1.":{"Enable":true}}

  $ R "ubus -S call WiFi.Radio.2 _set '{\"parameters\":{\"Enable\":1}}'"
  {"WiFi.Radio.2.":{"Enable":true}}

  $ R "ubus -t 30 wait_for hostapd.wlan0 && ubus -t 30 wait_for hostapd.wlan1"

Check that hostapd is operating as expected:

  $ R logger -t cram "Check that hostapd is operating after reboot"
  $ R "ps w" | sed -nE 's/.*(hostapd.*)/\1/p' | head -2 | LC_ALL=C sort
  hostapd -ddt /tmp/wlan0_hapd.conf
  hostapd -ddt /tmp/wlan1_hapd.conf

  $ R "ubus list | grep hostapd. | sort"
  hostapd.wlan0
  hostapd.wlan1

Check that wireless is operating:

  $ R "ubus -S call WiFi.SSID _get | jsonfilter -e @[*].SSID -e @[*].Status | sort"
  Up
  Up
  Up
  Up
  prplOS
  prplOS
  prplOS-guest
  prplOS-guest

  $ R "iw dev | grep -e Interface -e ssid | tr -d '\t' | sort"
  Interface wlan0
  Interface wlan1
  ssid prplOS
  ssid prplOS
  ssid prplOS-guest
  ssid prplOS-guest

Restart prplmesh:

  $ R logger -t cram "Restart prplmesh"
  $ R "/etc/init.d/prplmesh gateway_mode && sleep 5" > /dev/null 2>&1
  $ sleep 60

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
