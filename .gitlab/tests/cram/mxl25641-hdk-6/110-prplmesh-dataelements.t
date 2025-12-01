Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

Set AutoChannelEnable=0 on all WiFi.Radio. interfaces:

  $ R "ba-cli -j -l WiFi.Radio.*.AutoChannelEnable=0 | sed '/^$/d'"
  [{"WiFi.Radio.1.":{"AutoChannelEnable":0},"WiFi.Radio.2.":{"AutoChannelEnable":0},"WiFi.Radio.3.":{"AutoChannelEnable":0}}]

Set channel to a non DFS one:

  $ R "ba-cli -j -l WiFi.Radio.2.Channel=36 | sed '/^$/d'"
  [{"WiFi.Radio.2.":{"Channel":36}}]

  $ sleep 5

Configure controller, requires PPM-3022 to work:

  $ R logger -t cram "Stop prplmesh"

  $ R "( /etc/init.d/prplmesh stop ; sleep 2 )  2>&1 > /dev/null"


  $ R "sed -i 's/use_dataelements_vap_configs=0/use_dataelements_vap_configs=1/g' /opt/prplmesh/config/beerocks_controller.conf"

Restart prplmesh:

  $ R logger -t cram "Restart prplmesh"

  $ R "( /etc/init.d/prplmesh gateway_mode ; sleep 2 ) > /tmp/prplmesh-gw-mode.log 2>&1 ; logger -t prplmesh-gateway-mode < /tmp/prplmesh-gw-mode.log"

  $ R "ubus -t 60 wait_for X_PRPLWARE-COM_WiFiController.Network.Device.1"

First call of AccessPointCommit, controller should push empty config to agents:

  $ R logger -t cram "first call of AccessPointCommit pushes empty config, global teardown"

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network AccessPointCommit"
  {"retval":""}
  {}
  {"amxd-error-code":0}

  $ R sleep 15

Check all AccessPoint.SSIDReference+ instances are disabled

  $ get_ssid_status
  Down
  Down
  Down
  Down
  Down
  Down
  Down
  Down
  Down

  $ get_ssid_ssid
  backhaul_(4C:BA:7D|A8:C2:46):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  backhaul_(4C:BA:7D|A8:C2:46):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  backhaul_(4C:BA:7D|A8:C2:46):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  prplOS
  prplOS
  prplOS
  prplOS-guest
  prplOS-guest
  prplOS-guest


Create instances of Network.AccessPoint and push them to the agent:

  $ R logger -t cram "create instances of Network.AccessPoint and push them to the agent"

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint _add"
  {"object":"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.","index":1,"name":"1","parameters":{},"path":"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1."}
  {}
  {"amxd-error-code":0}

Since no persistent storage of NbAPI Network subsection, always index:1 after controller restart:

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1 _set '{\"parameters\":{\"Band2_4G\":1,\"Band5GH\":1,\"Band5GL\":1,\"Band6G\":1}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.":{"Band5GH":true,"Band6G":true,"Band2_4G":true,"Band5GL":true}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1 _set '{\"parameters\":{\"MultiApMode\":\"Fronthaul+Backhaul\"}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.":{"MultiApMode":"Fronthaul+Backhaul"}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Security _set '{\"parameters\":{\"ModeEnabled\":\"WPA2-Personal\",\"KeyPassphrase\":\"password\"}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Security.":{"KeyPassphrase":"password","ModeEnabled":"WPA2-Personal"}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1 _set '{\"parameters\":{\"SSID\":\"prplOSpriv\"}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.":{"SSID":"prplOSpriv"}}
  {}
  {"amxd-error-code":0}

In case the controller does not yet have this parameter, catch error here isof later during teardown test:
  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1 _set '{\"parameters\":{\"Enable\":1}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.":{"Enable":true}}
  {}
  {"amxd-error-code":0}

Create second instance of Network.AccessPoint for guest VAPs:

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint _add"
  {"object":"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2.","index":2,"name":"2","parameters":{},"path":"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2."}
  {}
  {"amxd-error-code":0}
  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2 _set '{\"parameters\":{\"Band2_4G\":1,\"Band5GH\":1,\"Band5GL\":1,\"Band6G\":1}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2.":{"Band5GH":true,"Band6G":true,"Band2_4G":true,"Band5GL":true}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2 _set '{\"parameters\":{\"MultiApMode\":\"Fronthaul\"}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2.":{"MultiApMode":"Fronthaul"}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2.Security _set '{\"parameters\":{\"ModeEnabled\":\"WPA2-Personal\",\"KeyPassphrase\":\"passwordGUEST\"}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2.Security.":{"KeyPassphrase":"passwordGUEST","ModeEnabled":"WPA2-Personal"}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2 _set '{\"parameters\":{\"SSID\":\"prplOSguest\"}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2.":{"SSID":"prplOSguest"}}
  {}
  {"amxd-error-code":0}

In case the controller does not yet have this parameter, catch error here isof later during teardown test:
  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2 _set '{\"parameters\":{\"Enable\":1}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2.":{"Enable":true}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network AccessPointCommit"
  {"retval":""}
  {}
  {"amxd-error-code":0}


  $ sleep 15

Check that wireless is operating:

  $ get_ssid_status
  Down
  Down
  Down
  Up
  Up
  Up
  Up
  Up
  Up

Check that prplmesh processes are running:

  $ R logger -t cram "Check that prplmesh processes are running"

  $ R "ps axw" | sed -nE 's/.*(\/opt\/prplmesh\/bin.*)/\1/p' | LC_ALL=C sort
  /opt/prplmesh/bin/beerocks_agent
  /opt/prplmesh/bin/beerocks_controller
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan0
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan2
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan4
  /opt/prplmesh/bin/beerocks_vendor_message
  /opt/prplmesh/bin/ieee1905_transport

Check that prplmesh is operational:

  $ R logger -t cram "Check that prplmesh is operational"

  $ R "/opt/prplmesh/scripts/prplmesh_utils.sh status" | sed 's/^[0-9]\+ //' | LC_ALL=C sort
  \x1b[0m (esc)
  \x1b[0m\x1b[1;32mOK Main radio agent operational (esc)
  \x1b[1;32moperational test success! (esc)
  /opt/prplmesh/scripts/prplmesh_utils.sh: status
  OK wlan0 radio agent operational
  OK wlan2 radio agent operational
  OK wlan4 radio agent operational
  beerocks_agent
  beerocks_contro
  beerocks_fronth
  beerocks_fronth
  beerocks_fronth
  beerocks_vendor
  executing operational test using bml
  ieee1905_transp

Check that controller received correct info about wifi subsystem:

  $ R logger -t cram "Check controller info about network"

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

To disable wireless, disable instances of Network.AccessPoint{i} and call AccessPointCommit():

  $ R logger -t cram "Stop wireless"

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1 _set '{\"parameters\":{\"Enable\":0}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.":{"Enable":false}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2 _set '{\"parameters\":{\"Enable\":0}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2.":{"Enable":false}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network AccessPointCommit"
  {"retval":""}
  {}
  {"amxd-error-code":0}

  $ sleep 10

Check that wireless is disabled:

  $ get_ssid_status
  Down
  Down
  Down
  Down
  Down
  Down
  Down
  Down
  Down

Restore Security Mode to default values

  $ R "ba-cli \"WiFi.AccessPoint.[RadioReference == 'WiFi.Radio.radio0'].Security.ModeEnabled='WPA2-WPA3-Personal'\" > /dev/null "

  $ R "ba-cli \"WiFi.AccessPoint.[RadioReference == 'WiFi.Radio.radio2'].Security.ModeEnabled='WPA2-WPA3-Personal'\" > /dev/null "

  $ R "ba-cli \"WiFi.AccessPoint.[RadioReference == 'WiFi.Radio.radio4'].Security.ModeEnabled='WPA3-Personal'\" > /dev/null "

Check the default ChipsetVendor param configurations:

  $ R logger -t cram "Check the default ChipsetVendor param configurations:"
  $ R "ba-cli -j -l WiFi.Radio.*.ChipsetVendor?0 | jsonfilter -e @[0]'[*].ChipsetVendor'"
  MaxLinear
  MaxLinear
  MaxLinear
