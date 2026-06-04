Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting prplMesh WPA3-CM test ..."

  $ R "amx_wait_for Device.WiFi"

Set AutoChannelEnable=0 on all WiFi.Radio. interfaces:

  $ wifi_dm "Radio.*.AutoChannelEnable=0"
  Device.WiFi.Radio.1.AutoChannelEnable=0
  Device.WiFi.Radio.2.AutoChannelEnable=0
  Device.WiFi.Radio.3.AutoChannelEnable=0

Set channel to a non DFS one:

  $ wifi_dm "Radio.2.Channel=36"
  Device.WiFi.Radio.2.Channel=36 (re)

Check default SecMode:

  $ R logger -t cram "Check default SecMode"

  $ wifi_dm "AccessPoint.1.Security.ModeEnabled?"
  Device.WiFi.AccessPoint.1.Security.ModeEnabled="WPA3-Personal-Transition"

  $ wifi_dm "AccessPoint.2.Security.ModeEnabled?"
  Device.WiFi.AccessPoint.2.Security.ModeEnabled="WPA3-Personal-Transition"

  $ wifi_dm "AccessPoint.3.Security.ModeEnabled?"
  Device.WiFi.AccessPoint.3.Security.ModeEnabled="WPA3-Personal"

Check if private/guest VAPs contain WPA3-Personal-Compatibility in the Security.ModesAvailable list:

  $ wifi_dm "AccessPoint.*.Security.ModesAvailable?" "WiFi." "ba-cli" | sed -n 's/^\(WiFi\.AccessPoint\.[1-6]\+\.Security\.ModesAvailable\).*WPA3-Personal-Compatibility.*/\1 has WPA3-Personal-Compatibility mode/p'
  WiFi.AccessPoint.1.Security.ModesAvailable has WPA3-Personal-Compatibility mode
  WiFi.AccessPoint.2.Security.ModesAvailable has WPA3-Personal-Compatibility mode
  WiFi.AccessPoint.3.Security.ModesAvailable has WPA3-Personal-Compatibility mode
  WiFi.AccessPoint.4.Security.ModesAvailable has WPA3-Personal-Compatibility mode
  WiFi.AccessPoint.5.Security.ModesAvailable has WPA3-Personal-Compatibility mode
  WiFi.AccessPoint.6.Security.ModesAvailable has WPA3-Personal-Compatibility mode

Configure controller for NBAPI configuration:

  $ R logger -t cram "Stop prplmesh"

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=0" | tr -d '\n'
  0 (no-eol)

  $ sleep 2
  $ R "sed -i 's/use_dataelements_vap_configs=0/use_dataelements_vap_configs=1/g' /opt/prplmesh/config/beerocks_controller.conf"
  $ R logger -t cram "Restart prplmesh"
  $ R "ba-cli X_PRPLWARE-COM_ProcessManager.PrplMesh.ManagementMode=Multi-AP-Controller-and-Agent"  > /dev/null
  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=1" | tr -d '\n'
  1 (no-eol)
  $ sleep 15

  $ R "ubus -t 60 wait_for X_PRPLWARE-COM_WiFiController.Network.Device.1"

  $ sleep 10

Set WPA3-Personal-Compatibility and check that : 1. Controller reads it correctly, 2. triggers reconfiguration, and 3. agent applies the correct value:

  $ wifi_dm "AccessPoint.1.Security.ModeEnabled=\"WPA3-Personal-Compatibility\""
  Device.WiFi.AccessPoint.1.Security.ModeEnabled="WPA3-Personal-Compatibility"

  $ wifi_dm "AccessPoint.2.Security.ModeEnabled=\"WPA3-Personal-Compatibility\""
  Device.WiFi.AccessPoint.2.Security.ModeEnabled="WPA3-Personal-Compatibility"

  $ wifi_dm "AccessPoint.3.Security.ModeEnabled=\"WPA3-Personal-Compatibility\""
  Device.WiFi.AccessPoint.3.Security.ModeEnabled="WPA3-Personal-Compatibility"

Enable private vaps:

  $ R logger -t cram "Enable private vaps"

  $ enable_ap_sync 1 1
  AccessPoint.\d+.Enable=1 (re)

  $ enable_ap_sync 2 1
  AccessPoint.\d+.Enable=1 (re)

  $ enable_ap_sync 3 1
  AccessPoint.\d+.Enable=1 (re)

  $ check_ap_ref_ssid 1 Up
  Device.WiFi.AccessPoint.1 SSID Reference is Up

  $ check_ap_ref_ssid 2 Up
  Device.WiFi.AccessPoint.2 SSID Reference is Up

  $ check_ap_ref_ssid 3 Up
  Device.WiFi.AccessPoint.3 SSID Reference is Up

Create one instances of Network.AccessPoint with WPA3-Personal enabled and push it to the agent:

  $ R logger -t cram "Create instances of Network.AccessPoint and push them to the agent"

  $ R "ba-cli \"X_PRPLWARE-COM_WiFiController.Network.AccessPoint+(Band2_4G=1,Band5GH=1,Band5GL=1,Band6G=1,MultiApMode=\"Fronthaul+Backhaul\",X_PRPLWARE-COM_VapType=\"home\",SSID=\"SSID_WPA3CM\",Security.ModeEnabled=\"WPA3-Personal\",Security.KeyPassphrase=\"password\",Enable=1)\"" | grep -Ev '^(>|$)'
  X_PRPLWARE-COM_WiFiController.Network.AccessPoint.* (re)

  $ R "ba-cli \"X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit()\"" | grep -Ev '^(>|$)'
  X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit() returned
  [
      ""
  ]

  $ sleep 10

Check that 3 SSID instances are still operating:

  $ R logger -t cram "Check private vaps"

  $ check_ap_ref_ssid 1 Up
  Device.WiFi.AccessPoint.1 SSID Reference is Up

  $ check_ap_ref_ssid 2 Up
  Device.WiFi.AccessPoint.2 SSID Reference is Up

  $ check_ap_ref_ssid 3 Up
  Device.WiFi.AccessPoint.3 SSID Reference is Up

Check config from Nbapi AccessPoint is correctly applied : SSID / Security.ModeEnabled:

  $ wifi_dm "AccessPoint.1.SSIDReference+.SSID?"
  Device.WiFi.SSID.\d+.SSID="SSID_WPA3CM" (re)

  $ wifi_dm "AccessPoint.2.SSIDReference+.SSID?"
  Device.WiFi.SSID.\d+.SSID="SSID_WPA3CM" (re)

  $ wifi_dm "AccessPoint.3.SSIDReference+.SSID?"
  Device.WiFi.SSID.\d+.SSID="SSID_WPA3CM" (re)

Check if agent overrides the security mode:

  $ wifi_dm "AccessPoint.1.Security.ModeEnabled?"
  Device.WiFi.AccessPoint.1.Security.ModeEnabled="WPA3-Personal"

  $ wifi_dm "AccessPoint.2.Security.ModeEnabled?"
  Device.WiFi.AccessPoint.2.Security.ModeEnabled="WPA3-Personal"

  $ wifi_dm "AccessPoint.3.Security.ModeEnabled?"
  Device.WiFi.AccessPoint.3.Security.ModeEnabled="WPA3-Personal"

Push WPA3-Personal-Compatibility:

  $ R logger -t cram "Push WPA3-Personal-Compatibility"

  $ R "ba-cli -l X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Security.ModeEnabled=\"WPA3-Personal-Compatibility\"" | sed '/^$/d'
  WPA3-Personal-Compatibility

  $ R "ba-cli \"X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit()\"" | grep -Ev '^(>|$)'
  X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit() returned
  [
      ""
  ]

  $ sleep 5

Check if agent overrides the security mode:

  $ wifi_dm "AccessPoint.1.Security.ModeEnabled?"
  Device.WiFi.AccessPoint.1.Security.ModeEnabled="WPA3-Personal-Compatibility"

  $ wifi_dm "AccessPoint.2.Security.ModeEnabled?"
  Device.WiFi.AccessPoint.2.Security.ModeEnabled="WPA3-Personal-Compatibility"

  $ wifi_dm "AccessPoint.3.Security.ModeEnabled?"
  Device.WiFi.AccessPoint.3.Security.ModeEnabled="WPA3-Personal-Compatibility"

Check hostapd configuration file:
(RSN Override 1 is set, RSN Override 2 shouldn't be present)

  $ itf=$(R "ba-cli -l WiFi.AccessPoint.1.SSIDReference+.Name?" | sed '/^$/d')
  $ get_hapd_config $itf rsn_override_key_mgmt
  SAE

  $ get_hapd_config $itf rsn_override_key_mgmt_2
  Option 'rsn_override_key_mgmt_2' not found

  $ itf=$(R "ba-cli -l WiFi.AccessPoint.2.SSIDReference+.Name?" | sed '/^$/d')
  $ get_hapd_config $itf rsn_override_key_mgmt
  SAE

  $ get_hapd_config $itf rsn_override_key_mgmt_2
  Option 'rsn_override_key_mgmt_2' not found

Restore default config:

  $ R logger -t cram "Restore default config"

  $ R "ba-cli -l \"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.SSID=\"prplOS\"\"" | sed '/^$/d'
  prplOS

Restore security modes in two steps: WPA3 Transition to 2.4GHz/5GHz and then WPA3 Personal to 6GHz:

  $ R "ba-cli -l \"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Band6G=0\"" | sed '/^$/d'
  0

  $ R "ba-cli -l \"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Security.ModeEnabled=\"WPA3-Personal-Transition\"\"" | sed '/^$/d'
  WPA3-Personal-Transition

  $ R "ba-cli \"X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit()\"" | grep -Ev '^(>|$)'
  X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit() returned
  [
      ""
  ]

  $ sleep 5

  $ R "ba-cli \"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.{Band2_4G=0,Band5GH=0,Band5GL=0,Band6G=1}\"" | grep -Ev '^(>|$)' | sed '1d'
  X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Band2_4G=0
  X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Band5GH=0
  X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Band5GL=0
  X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Band6G=1

  $ R "ba-cli -l \"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Security.ModeEnabled=\"WPA3-Personal\"\"" | sed '/^$/d'
  WPA3-Personal

  $ R "ba-cli \"X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit()\"" | grep -Ev '^(>|$)'
  X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit() returned
  [
      ""
  ]

  $ sleep 5

  $ R logger -t cram "Stop prplmesh"

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=0" | tr -d '\n'
  0 (no-eol)

  $ sleep 2
  $ R "sed -i 's/use_dataelements_vap_configs=1/use_dataelements_vap_configs=0/g' /opt/prplmesh/config/beerocks_controller.conf"

Disable private vaps:

  $ R logger -t cram "Disable private vaps"
  $ enable_ap_sync 3 0
  AccessPoint.\d+.Enable=0 (re)

  $ enable_ap_sync 2 0
  AccessPoint.\d+.Enable=0 (re)

  $ enable_ap_sync 1 0
  AccessPoint.\d+.Enable=0 (re)

  $ check_ap_ref_ssid 5 Down
  Device.WiFi.AccessPoint.5 SSID Reference is Down

  $ check_ap_ref_ssid 3 Down
  Device.WiFi.AccessPoint.3 SSID Reference is Down

  $ check_ap_ref_ssid 1 Down
  Device.WiFi.AccessPoint.1 SSID Reference is Down

Restart prplmesh:

  $ R logger -t cram "Restart prplmesh"
  $ R "ba-cli X_PRPLWARE-COM_ProcessManager.PrplMesh.ManagementMode=Multi-AP-Controller-and-Agent"  > /dev/null
  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=1" | tr -d '\n'
  1 (no-eol)

  $ R "amx_wait_for X_PRPLWARE-COM_WiFiController.Network.Device.1"

  $ R logger -t cram "Test finished!"
