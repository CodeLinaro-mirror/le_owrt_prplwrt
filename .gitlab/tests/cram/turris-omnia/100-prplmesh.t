Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that wireless has desired configuration and state after boot:

  $ R "ubus -S call WiFi.SSID _get | jsonfilter -e @[*].SSID -e @[*].Status | sort"
  Dormant
  Down
  Down
  Down
  Down
  PWHM_SSID5
  prplOS
  prplOS
  prplOS-guest
  prplOS-guest

  $ R "pgrep -f 'hostapd -ddt'"
  [1]

  $ R "ubus list | grep hostapd."
  [1]

Restart prplmesh:

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

  $ sleep 10

Check that hostapd is operating as expected:

  $ R logger -t cram "Check that hostapd is operating after reboot"
  $ R "ps axw" | sed -nE 's/.*(hostapd.*)/\1/p' | head -3 | LC_ALL=C sort
  hostapd -ddt /tmp/wlan0_hapd.conf
  hostapd/global
  hostapd/global

  $ R "ubus list | grep hostapd. | sort"
  hostapd.wlan0.1
  hostapd.wlan0.2
  hostapd.wlan1
  hostapd.wlan1.1

Check that wireless is operating:

  $ R "iw dev | grep -e Interface -e ssid | tr -d '\t' | sort"
  Interface wlan0
  Interface wlan0.1
  Interface wlan0.2
  Interface wlan1
  Interface wlan1.1
  ssid prplOS
  ssid prplOS
  ssid prplOS-guest
  ssid prplOS-guest

Check that prplmesh processes are running:

Check that prplmesh is operational:

Check that prplmesh is in operational state:

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

  $ sleep 10

Check that wireless is disabled:
