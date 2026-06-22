Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

Set AutoChannelEnable=0 on all Device.WiFi.Radio. interfaces:

  $ R "ba-cli -j -l WiFi.Radio.*.AutoChannelEnable=0 | sed '/^$/d'"
  [{"WiFi.Radio.1.":{"AutoChannelEnable":0},"WiFi.Radio.2.":{"AutoChannelEnable":0},"WiFi.Radio.3.":{"AutoChannelEnable":0}}]

Set channel to a non DFS one:

  $ R "usp-cli -j -l Device.WiFi.Radio.2.Channel=36 | sed '/^$/d'"
  [{"Device.WiFi.Radio.2.":{"Channel":36}}]

  $ sleep 5

Configure controller, requires PPM-3022 to work:

  $ R logger -t cram "Stop prplmesh"

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=0" | tr -d '\n'
  0 (no-eol)

  $ sleep 2
  $ R "sed -i 's/use_dataelements_vap_configs=0/use_dataelements_vap_configs=1/g' /opt/prplmesh/config/beerocks_controller.conf"

Restart prplmesh:

  $ R logger -t cram "Restart prplmesh"

  $ R "ba-cli X_PRPLWARE-COM_ProcessManager.PrplMesh.ManagementMode=Multi-AP-Controller-and-Agent"  > /dev/null

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=1" | tr -d '\n'
  1 (no-eol)

  $ R "ubus -t 60 wait_for X_PRPLWARE-COM_WiFiController.Network.Device.1"

  $ sleep 5

First call of AccessPointCommit, controller should push empty config to agents:

  $ R logger -t cram "first call of AccessPointCommit pushes empty config, global teardown"

  $ R "ba-cli 'X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit()' > /dev/null"

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

  $ R "ba-cli 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint+' > /dev/null"

Since no persistent storage of NbAPI Network subsection, always index:1 after controller restart:

  $ R "ba-cli 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Band2_4G=1;X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Band5GH=1;X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Band5GL=1;X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Band6G=1' > /dev/null"

  $ R "ba-cli 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.MultiApMode=\\\"Fronthaul+Backhaul\\\";X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.X_PRPLWARE_VapType=\\\"home\\\"' > /dev/null"

  $ R "ba-cli 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Security.ModeEnabled=\\\"WPA2-Personal\\\";X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Security.KeyPassphrase=\\\"password\\\"' > /dev/null"

  $ R "ba-cli 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.SSID=\\\"prplOSpriv\\\"' > /dev/null"

In case the controller does not yet have this parameter, catch error here isof later during teardown test:
  $ R "ba-cli 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Enable=1' > /dev/null"

Create second instance of Network.AccessPoint for guest VAPs:

  $ R "ba-cli 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint+' > /dev/null"
  $ R "ba-cli 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2.Band2_4G=1;X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2.Band5GH=1;X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2.Band5GL=1;X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2.Band6G=1' > /dev/null"

  $ R "ba-cli 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2.MultiApMode=\\\"Fronthaul\\\";X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2.X_PRPLWARE_VapType=\\\"guest\\\"' > /dev/null"

  $ R "ba-cli 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2.Security.ModeEnabled=\\\"WPA2-Personal\\\";X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2.Security.KeyPassphrase=\\\"passwordGUEST\\\"' > /dev/null"

  $ R "ba-cli 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2.SSID=\\\"prplOSguest\\\"' > /dev/null"

In case the controller does not yet have this parameter, catch error here isof later during teardown test:
  $ R "ba-cli 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2.Enable=1' > /dev/null"

  $ R "ba-cli 'X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit()' > /dev/null"


  $ sleep 60

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

  $ R "/opt/prplmesh/bin/prplmesh_cli -c status -o pretty" | sed 's/\t/        /g'
  Mode: Agent+Controller
  Controller:
          bridge MAC: (4C:BA:7D|A8:C2:46):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
          1 agent(s) connected
  Agent:
          MAC address: [0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
          management mode: Multi-AP-Controller-and-Agent
          fronthaul ifaces: wlan0,wlan2,wlan4
          current state: OPERATIONAL
          best state: OPERATIONAL
          Fronthaul:
                  interface: wlan0
                  current state: OPERATIONAL
                  best state: OPERATIONAL
          Fronthaul:
                  interface: wlan2
                  current state: OPERATIONAL
                  best state: OPERATIONAL
          Fronthaul:
                  interface: wlan4
                  current state: OPERATIONAL
                  best state: OPERATIONAL

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

  $ R "ba-cli 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Enable=0' > /dev/null"

  $ R "ba-cli 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2.Enable=0' > /dev/null"

  $ R "ba-cli 'X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit()' > /dev/null"

  $ sleep 60

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

  $ R "ba-cli  \"WiFi.AccessPoint.[RadioReference == 'Device.WiFi.Radio.1'].Security.ModeEnabled='WPA2-WPA3-Personal'\"" | grep 'ModeEnabled=' | sed '/^$/d' | grep -v '>'
  WiFi.AccessPoint.\d+.Security.ModeEnabled="WPA2-WPA3-Personal" (re)
  WiFi.AccessPoint.\d+.Security.ModeEnabled="WPA2-WPA3-Personal" (re)
  WiFi.AccessPoint.\d+.Security.ModeEnabled="WPA2-WPA3-Personal" (re)

  $ R "ba-cli  \"WiFi.AccessPoint.[RadioReference == 'Device.WiFi.Radio.2'].Security.ModeEnabled='WPA2-WPA3-Personal'\"" | grep 'ModeEnabled=' | sed '/^$/d' | grep -v '>'
  WiFi.AccessPoint.\d+.Security.ModeEnabled="WPA2-WPA3-Personal" (re)
  WiFi.AccessPoint.\d+.Security.ModeEnabled="WPA2-WPA3-Personal" (re)
  WiFi.AccessPoint.\d+.Security.ModeEnabled="WPA2-WPA3-Personal" (re)

  $ R "ba-cli  \"WiFi.AccessPoint.[RadioReference == 'Device.WiFi.Radio.3'].Security.ModeEnabled='WPA3-Personal'\"" | grep 'ModeEnabled=' | sed '/^$/d' | grep -v '>'
  WiFi.AccessPoint.\d+.Security.ModeEnabled="WPA3-Personal" (re)
  WiFi.AccessPoint.\d+.Security.ModeEnabled="WPA3-Personal" (re)
  WiFi.AccessPoint.\d+.Security.ModeEnabled="WPA3-Personal" (re)

Check the default ChipsetVendor param configurations:

  $ R logger -t cram "Check the default ChipsetVendor param configurations:"
  $ R "ba-cli -j -l WiFi.Radio.*.ChipsetVendor?0 | jsonfilter -e @[0]'[*].ChipsetVendor'"
  MaxLinear
  MaxLinear
  MaxLinear
