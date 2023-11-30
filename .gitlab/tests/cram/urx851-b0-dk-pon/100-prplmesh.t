Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that wireless has desired configuration and state after boot:

  $ R "ubus -S call WiFi.SSID _get | jsonfilter -e @[*].SSID -e @[*].Status | sort"
  Dormant
  Down
  Down
  Down
  Down
  Down
  Down
  PWHM_SSID7
  prplOS
  prplOS
  prplOS
  prplOS-guest
  prplOS-guest
  prplOS-guest

  $ R "pgrep -f 'hostapd -ddt'"
  [1]

Restart prplmesh:

  $ R logger -t cram "Restart prplmesh"
  $ R "( /etc/init.d/prplmesh gateway_mode ; sleep 2 ) > /tmp/prplmesh-gw-mode.log 2>&1 ; logger -t prplmesh-gateway-mode < /tmp/prplmesh-gw-mode.log"

  $ R "ubus -t 60 wait_for Device.WiFi"

Start wireless:

  $ R logger -t cram "Start wireless"

  $ R "ubus -S call WiFi.AccessPoint.1 _set '{\"parameters\":{\"Enable\":1}}'"
  {"WiFi.AccessPoint.1.":{"Enable":true}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call WiFi.AccessPoint.2 _set '{\"parameters\":{\"Enable\":1}}'"
  {"WiFi.AccessPoint.2.":{"Enable":true}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call WiFi.AccessPoint.3 _set '{\"parameters\":{\"Enable\":1}}'"
  {"WiFi.AccessPoint.3.":{"Enable":true}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call WiFi.AccessPoint.4 _set '{\"parameters\":{\"Enable\":1}}'"
  {"WiFi.AccessPoint.4.":{"Enable":true}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call WiFi.AccessPoint.5 _set '{\"parameters\":{\"Enable\":1}}'"
  {"WiFi.AccessPoint.5.":{"Enable":true}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call WiFi.AccessPoint.6 _set '{\"parameters\":{\"Enable\":1}}'"
  {"WiFi.AccessPoint.6.":{"Enable":true}}
  {}
  {"amxd-error-code":0}

  $ sleep 10

Check that hostapd is operating as expected:

  $ R logger -t cram "Check that hostapd is operating after reboot"
  $ R "ps axw" | sed -nE 's/.*(hostapd.*)/\1/p' | head -3 | LC_ALL=C sort
  hostapd -ddt /tmp/wlan0_hapd.conf
  hostapd -ddt /tmp/wlan2_hapd.conf
  hostapd -ddt /tmp/wlan4_hapd.conf

Check that wireless is operating:

  $ R "iw dev | grep -e Interface -e ssid | tr -d '\t' | sort"
  Interface wlan0
  Interface wlan0.1
  Interface wlan0.2
  Interface wlan2
  Interface wlan2.1
  Interface wlan2.2
  Interface wlan3
  Interface wlan4
  Interface wlan4.1
  Interface wlan4.2
  ssid dummy_ssid_2.4GHz
  ssid dummy_ssid_5GHz
  ssid dummy_ssid_6GHz
  ssid prplOS
  ssid prplOS
  ssid prplOS
  ssid prplOS-guest
  ssid prplOS-guest
  ssid prplOS-guest

Check that prplmesh processes are running:

  $ R logger -t cram "Check that prplmesh processes are running"
  $ R "ps axw" | sed -nE 's/.*(\/opt\/prplmesh\/bin.*)/\1/p' | LC_ALL=C sort
  /opt/prplmesh/bin/beerocks_agent
  /opt/prplmesh/bin/beerocks_controller
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan0
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan2
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan4
  /opt/prplmesh/bin/ieee1905_transport

Check that prplmesh is operational:

  $ R logger -t cram "Check that prplmesh is operational"
  $ R "/opt/prplmesh/scripts/prplmesh_utils.sh status" | LC_ALL=C sort
  \x1b[0m (esc)
  \x1b[0m\x1b[1;32mOK Main radio agent operational (esc)
  \x1b[1;32moperational test success! (esc)
  /opt/prplmesh/scripts/prplmesh_utils.sh: status
  [0-9]+ beerocks_contro (re)
  [0-9]+ beerocks_agent (re)
  [0-9]+ beerocks_fronth (re)
  [0-9]+ beerocks_fronth (re)
  [0-9]+ beerocks_fronth (re)
  OK wlan0 radio agent operational
  OK wlan2 radio agent operational
  OK wlan4 radio agent operational
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
  wlan2
  wlan2.0
  wlan2.1
  wlan4
  wlan4.0
  wlan4.1

Disable wireless:

  $ R logger -t cram "Stop wireless"

  $ R "ubus -S call WiFi.AccessPoint.1 _set '{\"parameters\":{\"Enable\":0}}'"
  {"WiFi.AccessPoint.1.":{"Enable":false}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call WiFi.AccessPoint.2 _set '{\"parameters\":{\"Enable\":0}}'"
  {"WiFi.AccessPoint.2.":{"Enable":false}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call WiFi.AccessPoint.3 _set '{\"parameters\":{\"Enable\":0}}'"
  {"WiFi.AccessPoint.3.":{"Enable":false}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call WiFi.AccessPoint.4 _set '{\"parameters\":{\"Enable\":0}}'"
  {"WiFi.AccessPoint.4.":{"Enable":false}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call WiFi.AccessPoint.5 _set '{\"parameters\":{\"Enable\":0}}'"
  {"WiFi.AccessPoint.5.":{"Enable":false}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call WiFi.AccessPoint.6 _set '{\"parameters\":{\"Enable\":0}}'"
  {"WiFi.AccessPoint.6.":{"Enable":false}}
  {}
  {"amxd-error-code":0}


  $ sleep 10

Check that wireless is disabled:

