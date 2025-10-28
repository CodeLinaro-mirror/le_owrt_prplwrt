Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Stop prplmesh"
  $ R "( /etc/init.d/prplmesh stop ; sleep 2 )  2>&1 > /dev/null"

Enable DataElements VAP config:

  $ R logger -t cram "Enabling DataElements VAP config..."

  $ R "sed -i 's/use_dataelements_vap_configs=0/use_dataelements_vap_configs=1/g' /opt/prplmesh/config/beerocks_controller.conf"

Disable MLO, MLDUnit = -1 for all SSIDs:

  $ R logger -t cram "Disabling MLO for all SSIDs..."
  $ R "ba-cli -j -l WiFi.SSID.*.MLDUnit=-1 | jsonfilter -e @[0]'[*].MLDUnit'"
  -1
  -1
  -1
  -1
  -1
  -1
  -1
  -1
  -1
  -1
  -1
  -1

Check Controller, Agent,FrontHaul process are Running:

  $ R "( /etc/init.d/prplmesh gateway_mode ; sleep 2 ) > /tmp/prplmesh-gw-mode.log 2>&1 ; logger -t prplmesh-gateway-mode < /tmp/prplmesh-gw-mode.log"

  $ R "ubus -t 60 wait_for X_PRPLWARE-COM_WiFiController.Network.Device.1"
  $ sleep 15

  $ R logger -t cram "Checking beerocks process."
  $ R "ps axw" | sed -nE 's/.*(\/opt\/prplmesh\/bin.*)/\1/p' | LC_ALL=C sort
  /opt/prplmesh/bin/beerocks_agent
  /opt/prplmesh/bin/beerocks_controller
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan0
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan1
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan2
  /opt/prplmesh/bin/beerocks_vendor_message
  /opt/prplmesh/bin/ieee1905_transport

Create instances of Network.AccessPoint and push them to the agent:

  $ R logger -t cram "create instances of Network.AccessPoint and push them to the agent"

  $ R "ba-cli -j -l 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.+'"
  
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.":{}}
  

  $ R "ba-cli -j -l 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Band2_4G=1'"
  
  [{"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.":{"Band2_4G":1}}]
  

  $ R "ba-cli -j -l 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Band5GH=1'"
  
  [{"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.":{"Band5GH":1}}]
  

  $ R "ba-cli -j -l  'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Band5GL=1'"
  
  [{"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.":{"Band5GL":1}}]
  

  $ R "ba-cli -j -l 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Band6G=1'"
  
  [{"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.":{"Band6G":1}}]
  

  $ R "ba-cli -j -l 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Enable=1'"
  
  [{"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.":{"Enable":1}}]
  

  $ R "ba-cli -j -l 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.SSID=TEST-FRONTHAUL'"
  
  [{"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.":{"SSID":"TEST-FRONTHAUL"}}]
  

  $ R "ba-cli -j -l 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Security.ModeEnabled=WPA3-Personal'"
  
  [{"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Security.":{"ModeEnabled":"WPA3-Personal"}}]
  

  $ R "ba-cli -j -l 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Security.SAEPassphrase=password-fhl'"
  
  [{"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Security.":{"SAEPassphrase":"password-fhl"}}]
  

  $ R "ba-cli -j -l 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Security.KeyPassphrase=password-fhl'"
  
  [{"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Security.":{"KeyPassphrase":"password-fhl"}}]
  

  $ R "ba-cli -j -l 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.MultiApMode=Fronthaul'"
  
  [{"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.":{"MultiApMode":"Fronthaul"}}]
  

  $ R "ba-cli -j -l 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.MLDUnit=7'"
  
  [{"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.":{"MLDUnit":7}}]
  

  $ R "ba-cli -j -l 'X_PRPLWARE-COM_Agent.Info.CurrentState?' | jsonfilter -e @[0]'[*].CurrentState'"
  OPERATIONAL (15)

  $ R "ba-cli -j -l 'X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit()'"
  
  X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit() returned
  [""]
  

  $ sleep 10

Verify MLDUnit Set by Agent in 2.4GHz, 5GHz and 6GHz:

  $ R logger -t cram "Verifying MLDUnit values in Data Model..."

  $ R "ba-cli -j -l WiFi.SSID.?0 | jsonfilter -e @[0]'[@.Alias != \"ep2g0\" && @.Alias != \"ep5g0\" && @.Alias != \"ep6g0\" && @.Enable != 0].MLDUnit'" | LC_ALL=C sort
  1
  1
  1

Check the MLO group in iw dev:

  $ R logger -t cram " To check interface status"
  $ R "iw dev | awk '
  > /Interface/ { iface = \$2; iface_mac = \"\"; next }
  > /addr/ && !/link/ { iface_mac = \$2; next }
  > /link 0:/ { getline; if (\$1 == \"addr\") {
  > if (iface_mac == \$2) { print \"true\" } } }'"
  true

Restore defautlt MLDUnit and config values:

  $ R logger -t cram "Restore default MLD configuration"

  $ R "ba-cli -j -l WiFi.AccessPoint.1.SSIDReference+.MLDUnit=0 |jsonfilter -e @[0]'[*].MLDUnit' "
  0

  $ R "ba-cli -j -l WiFi.AccessPoint.2.SSIDReference+.MLDUnit=1 |jsonfilter -e @[0]'[*].MLDUnit' "
  1

  $ R "ba-cli -j -l WiFi.AccessPoint.3.SSIDReference+.MLDUnit=0 |jsonfilter -e @[0]'[*].MLDUnit' "
  0

  $ R "ba-cli -j -l WiFi.AccessPoint.4.SSIDReference+.MLDUnit=1 |jsonfilter -e @[0]'[*].MLDUnit' "
  1

  $ R "ba-cli -j -l WiFi.AccessPoint.5.SSIDReference+.MLDUnit=0 |jsonfilter -e @[0]'[*].MLDUnit' "
  0

  $ R "ba-cli -j -l WiFi.AccessPoint.6.SSIDReference+.MLDUnit=1 |jsonfilter -e @[0]'[*].MLDUnit' "
  1

  $ R "sed -i 's/^use_dataelements_vap_configs=.*/use_dataelements_vap_configs=0/' /opt/prplmesh/config/beerocks_controller.conf"

  $ R "ba-cli -j -l 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.SSID=prplOS'"
  
  [{"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.":{"SSID":"prplOS"}}]
  

  $ R "ba-cli -j -l 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Security.KeyPassphrase=password'"
  
  [{"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Security.":{"KeyPassphrase":"password"}}]
  

  $ R "ba-cli -j -l 'X_PRPLWARE-COM_Agent.Info.CurrentState?' | jsonfilter -e @[0]'[*].CurrentState'"
  OPERATIONAL (15)

  $ R "ba-cli -j -l 'X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit()'"
  
  X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit() returned
  [""]
  

  $ sleep 10

  $ R "/etc/init.d/prplmesh restart 2>&1 > /dev/null"
  $ sleep 10

  $ R "ps axw" | sed -nE 's/.*(\/opt\/prplmesh\/bin.*)/\1/p' | LC_ALL=C sort
  /opt/prplmesh/bin/beerocks_agent
  /opt/prplmesh/bin/beerocks_controller
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan0
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan1
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan2
  /opt/prplmesh/bin/beerocks_vendor_message
  /opt/prplmesh/bin/ieee1905_transport

Final log:

  $ R logger -t cram "MLDUnit test completed."
  $ sleep 20
  $ R logger -t cram "MLO test finished!"

