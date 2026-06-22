Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Set channel to a non DFS one:

  $ R "ba-cli 'WiFi.Radio.1.Channel=36' > /dev/null"

  $ sleep 1

Switch channel bandwith from 160 to 80 Mhz to avoid doing DFS CAC operation, that lead to long delay before vaps being up (to be removed when PPM 2810 is fixed):

  $ R "ba-cli 'WiFi.Radio.1.OperatingChannelBandwidth=\\\"80MHz\\\"' > /dev/null"

  $ sleep 1

Check that wireless has desired configuration and state after boot:

  $ R "ba-cli -l 'WiFi.SSID.*.SSID?;WiFi.SSID.*.Status?' | grep -v '^$' | sort"
  Dormant
  Dormant
  Down
  Down
  Down
  Down
  Down
  Down
  Down
  PWHM_SSID2
  PWHM_SSID5
  PWHM_SSID8
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

  $ R logger -t cram "Restart prplmesh"

  $ R "ba-cli X_PRPLWARE-COM_ProcessManager.PrplMesh.ManagementMode=Multi-AP-Controller-and-Agent"  > /dev/null
  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=1" | tr -d '\n'
  1 (no-eol)
  
  $ R "ubus -t 60 wait_for X_PRPLWARE-COM_WiFiController.Network.Device.1"

Start wireless:

  $ R logger -t cram "Start wireless"

  $ R "ba-cli 'WiFi.AccessPoint.1.Enable=1' > /dev/null"

  $ sleep 10

  $ R "i=15 ; while [ \$i -gt 1 ]; do ba-cli -l 'WiFi.SSID.1.Status?' | grep -q Up && echo 'SSID.1 Up' && i=0 ; i=\$(( i-1 )); sleep 2 ; done"
  SSID.1 Up

  $ R "ba-cli 'WiFi.AccessPoint.2.Enable=1' > /dev/null"

  $ sleep 10

  $ R "i=15 ; while [ \$i -gt 1 ]; do ba-cli -l 'WiFi.SSID.2.Status?' | grep -q Up && echo 'SSID.2 Up' && i=0 ; i=\$(( i-1 )); sleep 2 ; done"
  SSID.2 Up

  $ R "ba-cli 'WiFi.AccessPoint.3.Enable=1' > /dev/null"

  $ sleep 10

  $ R "i=15 ; while [ \$i -gt 1 ]; do ba-cli -l 'WiFi.SSID.3.Status?' | grep -q Up && echo 'SSID.3 Up' && i=0 ; i=\$(( i-1 )); sleep 2 ; done"
  SSID.3 Up

  $ R "ba-cli 'WiFi.AccessPoint.4.Enable=1' > /dev/null"

  $ sleep 10

  $ R "i=15 ; while [ \$i -gt 1 ]; do ba-cli -l 'WiFi.SSID.4.Status?' | grep -q Up && echo 'SSID.4 Up' && i=0 ; i=\$(( i-1 )); sleep 2 ; done"
  SSID.4 Up

  $ R "ba-cli 'WiFi.AccessPoint.5.Enable=1' > /dev/null"

  $ sleep 10

  $ R "i=15 ; while [ \$i -gt 1 ]; do ba-cli -l 'WiFi.SSID.5.Status?' | grep -q Up && echo 'SSID.5 Up' && i=0 ; i=\$(( i-1 )); sleep 2 ; done"
  SSID.5 Up

  $ R "ba-cli 'WiFi.AccessPoint.6.Enable=1' > /dev/null"

  $ sleep 10

  $ R "i=15 ; while [ \$i -gt 1 ]; do ba-cli -l 'WiFi.SSID.6.Status?' | grep -q Up && echo 'SSID.6 Up' && i=0 ; i=\$(( i-1 )); sleep 2 ; done"
  SSID.6 Up

Check that hostapd is operating as expected:

  $ R logger -t cram "Check that hostapd is operating after reboot"
  $ R "ps axw" | sed -nE 's/.*(hostapd.*)/\1/p' | head -1 | tr -s ' ' '\n' | LC_ALL=C sort
  -ddt
  /tmp/wlan0_hapd.conf
  /tmp/wlan1_hapd.conf
  /tmp/wlan2_hapd.conf
  hostapd

  $ R "ubus list | grep hostapd. | sort"
  hostapd.wlan0.1
  hostapd.wlan0.2
  hostapd.wlan1.1
  hostapd.wlan1.2
  hostapd.wlan2.1
  hostapd.wlan2.2

Check that wireless is operating:

  $ R "ba-cli -l 'WiFi.SSID.*.SSID?;WiFi.SSID.*.Status?' | grep -v '^$' | sort"
  Dormant
  Dormant
  Down
  PWHM_SSID2
  PWHM_SSID5
  PWHM_SSID8
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
  Interface wlan1.2
  Interface wlan2
  Interface wlan2.1
  Interface wlan2.2
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
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan1
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan2
  /opt/prplmesh/bin/beerocks_vendor_message
  /opt/prplmesh/bin/ieee1905_transport

Check that prplmesh is operational:

  $ R logger -t cram "Check that prplmesh is operational"
  $ R "/opt/prplmesh/bin/prplmesh_cli -c status -o pretty" | sed 's/\t/        /g'
  Mode: Agent+Controller
  Controller:
          bridge MAC: [0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
          1 agent(s) connected
  Agent:
          MAC address: [0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
          management mode: Multi-AP-Controller-and-Agent
          fronthaul ifaces: wlan0,wlan1,wlan2
          current state: OPERATIONAL
          best state: OPERATIONAL
          Fronthaul:
                  interface: wlan0
                  current state: OPERATIONAL
                  best state: OPERATIONAL
          Fronthaul:
                  interface: wlan1
                  current state: OPERATIONAL
                  best state: OPERATIONAL
          Fronthaul:
                  interface: wlan2
                  current state: OPERATIONAL
                  best state: OPERATIONAL

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
  wlan2
  wlan2.0
  wlan2.1

Disable wireless:

  $ R logger -t cram "Stop wireless"

  $ R "ba-cli 'WiFi.AccessPoint.6.Enable=0' > /dev/null"

  $ sleep 10

  $ R "i=15 ; while [ \$i -gt 1 ]; do ba-cli -l 'WiFi.SSID.6.Status?' | grep -q Down && echo 'SSID.6 Down' && i=0 ; i=\$(( i-1 )); sleep 2 ; done"
  SSID.6 Down

  $ R "ba-cli 'WiFi.AccessPoint.5.Enable=0' > /dev/null"

  $ sleep 10

  $ R "i=15 ; while [ \$i -gt 1 ]; do ba-cli -l 'WiFi.SSID.5.Status?' | grep -q Down && echo 'SSID.5 Down' && i=0 ; i=\$(( i-1 )); sleep 2 ; done"
  SSID.5 Down

  $ R "ba-cli 'WiFi.AccessPoint.4.Enable=0' > /dev/null"

  $ sleep 10

  $ R "i=15 ; while [ \$i -gt 1 ]; do ba-cli -l 'WiFi.SSID.4.Status?' | grep -q Down && echo 'SSID.4 Down' && i=0 ; i=\$(( i-1 )); sleep 2 ; done"
  SSID.4 Down

  $ R "ba-cli 'WiFi.AccessPoint.3.Enable=0' > /dev/null"

  $ sleep 10

  $ R "i=15 ; while [ \$i -gt 1 ]; do ba-cli -l 'WiFi.SSID.3.Status?' | grep -q Down && echo 'SSID.3 Down' && i=0 ; i=\$(( i-1 )); sleep 2 ; done"
  SSID.3 Down

  $ R "ba-cli 'WiFi.AccessPoint.2.Enable=0' > /dev/null"

  $ sleep 10

  $ R "i=15 ; while [ \$i -gt 1 ]; do ba-cli -l 'WiFi.SSID.2.Status?' | grep -q Down && echo 'SSID.2 Down' && i=0 ; i=\$(( i-1 )); sleep 2 ; done"
  SSID.2 Down

  $ R "ba-cli 'WiFi.AccessPoint.1.Enable=0' > /dev/null"

  $ sleep 10

  $ R "i=15 ; while [ \$i -gt 1 ]; do ba-cli -l 'WiFi.SSID.1.Status?' | grep -q Down && echo 'SSID.1 Down' && i=0 ; i=\$(( i-1 )); sleep 2 ; done"
  SSID.1 Down

Check that wireless is disabled:

  $ R "ba-cli -l 'WiFi.SSID.*.SSID?;WiFi.SSID.*.Status?' | grep -v '^$' | sort"
  Dormant
  Dormant
  Down
  Down
  Down
  Down
  Down
  Down
  Down
  PWHM_SSID2
  PWHM_SSID5
  PWHM_SSID8
  prplOS
  prplOS
  prplOS
  prplOS-guest
  prplOS-guest
  prplOS-guest

  $ R "pgrep -f 'hostapd -ddt'"
  [1]
