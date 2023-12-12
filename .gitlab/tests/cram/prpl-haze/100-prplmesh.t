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

  $ R "ubus list | grep hostapd."
  [1]

Restart prplmesh:

Start wireless:

  $ R logger -t cram "Start wireless"

  $ R "ubus -S call WiFi.AccessPoint.1 _set '{\"parameters\":{\"Enable\":1}}'"
  {"WiFi.AccessPoint.1.":{"Enable":true}}
  {}
  {"amxd-error-code":0}

  $ R "i=15 ; while [ \$i -gt 1 ]; do ubus -S call WiFi.SSID.1 _get '{\"rel_path\":\"Status\"}'| grep -q Up && echo 'SSID.1 Up' && i=0 ; i=\$(( i-1 )); sleep 1 ; done"
  SSID.1 Up

  $ R "ubus -S call WiFi.AccessPoint.2 _set '{\"parameters\":{\"Enable\":1}}'"
  {"WiFi.AccessPoint.2.":{"Enable":true}}
  {}
  {"amxd-error-code":0}

  $ R "i=15 ; while [ \$i -gt 1 ]; do ubus -S call WiFi.SSID.2 _get '{\"rel_path\":\"Status\"}'| grep -q Up && echo 'SSID.2 Up' && i=0 ; i=\$(( i-1 )); sleep 1 ; done"
  SSID.2 Up

  $ R "ubus -S call WiFi.AccessPoint.3 _set '{\"parameters\":{\"Enable\":1}}'"
  {"WiFi.AccessPoint.3.":{"Enable":true}}
  {}
  {"amxd-error-code":0}

  $ R "i=15 ; while [ \$i -gt 1 ]; do ubus -S call WiFi.SSID.3 _get '{\"rel_path\":\"Status\"}'| grep -q Up && echo 'SSID.3 Up' && i=0 ; i=\$(( i-1 )); sleep 1 ; done"
  SSID.3 Up

  $ R "ubus -S call WiFi.AccessPoint.4 _set '{\"parameters\":{\"Enable\":1}}'"
  {"WiFi.AccessPoint.4.":{"Enable":true}}
  {}
  {"amxd-error-code":0}

  $ R "i=15 ; while [ \$i -gt 1 ]; do ubus -S call WiFi.SSID.4 _get '{\"rel_path\":\"Status\"}'| grep -q Up && echo 'SSID.4 Up' && i=0 ; i=\$(( i-1 )); sleep 1 ; done"
  SSID.4 Up

  $ R "ubus -S call WiFi.AccessPoint.5 _set '{\"parameters\":{\"Enable\":1}}'"
  {"WiFi.AccessPoint.5.":{"Enable":true}}
  {}
  {"amxd-error-code":0}

  $ R "i=15 ; while [ \$i -gt 1 ]; do ubus -S call WiFi.SSID.5 _get '{\"rel_path\":\"Status\"}'| grep -q Up && echo 'SSID.5 Up' && i=0 ; i=\$(( i-1 )); sleep 1 ; done"
  SSID.5 Up

  $ R "ubus -S call WiFi.AccessPoint.6 _set '{\"parameters\":{\"Enable\":1}}'"
  {"WiFi.AccessPoint.6.":{"Enable":true}}
  {}
  {"amxd-error-code":0}

  $ R "i=15 ; while [ \$i -gt 1 ]; do ubus -S call WiFi.SSID.6 _get '{\"rel_path\":\"Status\"}'| grep -q Up && echo 'SSID.6 Up' && i=0 ; i=\$(( i-1 )); sleep 1 ; done"
  SSID.6 Up

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
  hostapd.wlan2
  hostapd.wlan2.1

Check that wireless is operating:

  $ R "ubus -S call WiFi.SSID _get | jsonfilter -e @[*].SSID -e @[*].Status | sort"
  Dormant
  PWHM_SSID7
  Up
  Up
  Up
  Up
  Up
  Up
  prplOS
  prplOS
  prplOS
  prplOS-guest
  prplOS-guest
  prplOS-guest

  $ R "iw dev | grep -e Interface -e ssid | tr -d '\t' | sort"
  Interface wlan0
  Interface wlan0.1
  Interface wlan0.2
  Interface wlan1
  Interface wlan1.1
  Interface wlan2
  Interface wlan2.1
  ssid prplOS
  ssid prplOS
  ssid prplOS
  ssid prplOS-guest
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

  $ R "i=15 ; while [ \$i -gt 1 ]; do ubus -S call WiFi.SSID.1 _get '{\"rel_path\":\"Status\"}'| grep -q Down && echo 'SSID.1 Down' && i=0 ; i=\$(( i-1 )); sleep 1 ; done"
  SSID.1 Down

  $ R "ubus -S call WiFi.AccessPoint.2 _set '{\"parameters\":{\"Enable\":0}}'"
  {"WiFi.AccessPoint.2.":{"Enable":false}}
  {}
  {"amxd-error-code":0}

  $ R "i=15 ; while [ \$i -gt 1 ]; do ubus -S call WiFi.SSID.2 _get '{\"rel_path\":\"Status\"}'| grep -q Down && echo 'SSID.2 Down' && i=0 ; i=\$(( i-1 )); sleep 1 ; done"
  SSID.2 Down

  $ R "ubus -S call WiFi.AccessPoint.3 _set '{\"parameters\":{\"Enable\":0}}'"
  {"WiFi.AccessPoint.3.":{"Enable":false}}
  {}
  {"amxd-error-code":0}

  $ R "i=15 ; while [ \$i -gt 1 ]; do ubus -S call WiFi.SSID.3 _get '{\"rel_path\":\"Status\"}'| grep -q Down && echo 'SSID.3 Down' && i=0 ; i=\$(( i-1 )); sleep 1 ; done"
  SSID.3 Down

  $ R "ubus -S call WiFi.AccessPoint.4 _set '{\"parameters\":{\"Enable\":0}}'"
  {"WiFi.AccessPoint.4.":{"Enable":false}}
  {}
  {"amxd-error-code":0}

  $ R "i=15 ; while [ \$i -gt 1 ]; do ubus -S call WiFi.SSID.4 _get '{\"rel_path\":\"Status\"}'| grep -q Down && echo 'SSID.4 Down' && i=0 ; i=\$(( i-1 )); sleep 1 ; done"
  SSID.4 Down

  $ R "ubus -S call WiFi.AccessPoint.5 _set '{\"parameters\":{\"Enable\":0}}'"
  {"WiFi.AccessPoint.5.":{"Enable":false}}
  {}
  {"amxd-error-code":0}

  $ R "i=15 ; while [ \$i -gt 1 ]; do ubus -S call WiFi.SSID.5 _get '{\"rel_path\":\"Status\"}'| grep -q Down && echo 'SSID.5 Down' && i=0 ; i=\$(( i-1 )); sleep 1 ; done"
  SSID.5 Down

  $ R "ubus -S call WiFi.AccessPoint.6 _set '{\"parameters\":{\"Enable\":0}}'"
  {"WiFi.AccessPoint.6.":{"Enable":false}}
  {}
  {"amxd-error-code":0}

  $ R "i=15 ; while [ \$i -gt 1 ]; do ubus -S call WiFi.SSID.6 _get '{\"rel_path\":\"Status\"}'| grep -q Down && echo 'SSID.6 Down' && i=0 ; i=\$(( i-1 )); sleep 1 ; done"
  SSID.6 Down

  $ sleep 10

Check that wireless is disabled:

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
