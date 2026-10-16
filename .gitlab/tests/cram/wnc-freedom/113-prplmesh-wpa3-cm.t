Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting $TESTFILE"

  $ check_wifi_defaults
  $ testbed_set_wifi_defaults

Check default SecMode:

  $ R logger -t cram "First subtest : Controller WifiManager"

  $ wifi_dm "AccessPoint.1.Security.ModeEnabled?"
  Device.WiFi.AccessPoint.1.Security.ModeEnabled="WPA3-Personal-Transition"

  $ wifi_dm "AccessPoint.3.Security.ModeEnabled?"
  Device.WiFi.AccessPoint.3.Security.ModeEnabled="WPA3-Personal-Transition"

  $ wifi_dm "AccessPoint.5.Security.ModeEnabled?"
  Device.WiFi.AccessPoint.5.Security.ModeEnabled="WPA3-Personal"

Check if private/guest VAPs contain WPA3-Personal-Compatibility in the Security.ModesAvailable list:
(use the  regex AccessPoint\.[1-6]\+\.Security to filter out backhaul vaps )

  $ wifi_dm "AccessPoint.*.Security.X_PRPLWARE-COM_ModesAvailable?" | sed -n 's/^\(Device.WiFi\.AccessPoint\.[1-6]\+\.Security\.X_PRPLWARE-COM_ModesAvailable\).*WPA3-Personal-Compatibility.*/\1 has WPA3-Personal-Compatibility mode/p'
  Device.WiFi.AccessPoint.1.Security.X_PRPLWARE-COM_ModesAvailable has WPA3-Personal-Compatibility mode
  Device.WiFi.AccessPoint.2.Security.X_PRPLWARE-COM_ModesAvailable has WPA3-Personal-Compatibility mode
  Device.WiFi.AccessPoint.3.Security.X_PRPLWARE-COM_ModesAvailable has WPA3-Personal-Compatibility mode
  Device.WiFi.AccessPoint.4.Security.X_PRPLWARE-COM_ModesAvailable has WPA3-Personal-Compatibility mode
  Device.WiFi.AccessPoint.5.Security.X_PRPLWARE-COM_ModesAvailable has WPA3-Personal-Compatibility mode
  Device.WiFi.AccessPoint.6.Security.X_PRPLWARE-COM_ModesAvailable has WPA3-Personal-Compatibility mode

Configure controller for WiFi Manager configuration:

  $ prplmesh_stop
  $ R "sed -i 's/use_dataelements_vap_configs=./use_dataelements_vap_configs=0/g' /opt/prplmesh/config/beerocks_controller.conf"

  $ R logger -t cram "Configure private VAPs for WifiManager"

Set WPA3-Personal-Compatibility for private vaps:

  $ wifi_dm "AccessPoint.1.Security.ModeEnabled=\"WPA3-Personal-Compatibility\""
  Device.WiFi.AccessPoint.1.Security.ModeEnabled="WPA3-Personal-Compatibility"

  $ wifi_dm "AccessPoint.3.Security.ModeEnabled=\"WPA3-Personal-Compatibility\""
  Device.WiFi.AccessPoint.3.Security.ModeEnabled="WPA3-Personal-Compatibility"

  $ wifi_dm "AccessPoint.5.Security.ModeEnabled=\"WPA3-Personal-Compatibility\""
  Device.WiFi.AccessPoint.5.Security.ModeEnabled="WPA3-Personal-Compatibility"

Enable private vaps:

  $ enable_ap 1
  Device.WiFi.AccessPoint.1 enabled

  $ enable_ap 3
  Device.WiFi.AccessPoint.3 enabled

  $ enable_ap 5
  Device.WiFi.AccessPoint.5 enabled

Start prplMesh and check that WiFi Manager reads WPA3-CM from pwhm, and Controller correctly transports it to the Agent
As a result of the full chain, AccessPoint fields {.Security.ModeEnabled} and {.Enable} are not changed

  $ prplmesh_start

  $ prplmesh_agent_poll_operational 3 10
  Fronthauls Operational: 3

Sleep a bit longer than WiFiManager CONFIG_RENEW_TIMEOUT{3000}; [ms]

  $ sleep 5

  $ wifi_dm "AccessPoint.1.Enable?"
  Device.WiFi.AccessPoint.1.Enable=1

  $ wifi_dm "AccessPoint.3.Enable?"
  Device.WiFi.AccessPoint.3.Enable=1

  $ wifi_dm "AccessPoint.5.Enable?"
  Device.WiFi.AccessPoint.5.Enable=1

  $ wifi_dm "AccessPoint.1.Security.ModeEnabled?"
  Device.WiFi.AccessPoint.1.Security.ModeEnabled="WPA3-Personal-Compatibility"

  $ wifi_dm "AccessPoint.3.Security.ModeEnabled?"
  Device.WiFi.AccessPoint.3.Security.ModeEnabled="WPA3-Personal-Compatibility"

  $ wifi_dm "AccessPoint.5.Security.ModeEnabled?"
  Device.WiFi.AccessPoint.5.Security.ModeEnabled="WPA3-Personal-Compatibility"

Status goes Up or Down as a consequence of changing the value of Enable. Agent only writes to Enable. Still, let's check the Status

  $ check_ap_ref_ssid 1 Up
  Device.WiFi.AccessPoint.1 SSID Reference is Up

  $ check_ap_ref_ssid 3 Up
  Device.WiFi.AccessPoint.3 SSID Reference is Up

  $ check_ap_ref_ssid 5 Up
  Device.WiFi.AccessPoint.5 SSID Reference is Up

  $ R logger -t cram "Second subtest : Controller Dataelements"

Configure controller for NBAPI configuration:

  $ prplmesh_stop
  $ R "sed -i 's/use_dataelements_vap_configs=./use_dataelements_vap_configs=1/g' /opt/prplmesh/config/beerocks_controller.conf"
  $ prplmesh_start

  $ prplmesh_agent_poll_operational 3 10
  Fronthauls Operational: 3


Create one instances of Network.AccessPoint with WPA3-Personal enabled and push it to the agent:

  $ R logger -t cram "Create instances of Network.AccessPoint and push them to the agent"

  $ R "ba-cli \"X_PRPLWARE-COM_WiFiController.Network.AccessPoint+(Band2_4G=1,Band5GH=1,Band5GL=1,Band6G=1,MultiApMode=\"Fronthaul+Backhaul\",X_PRPLWARE-COM_VapType=\"home\",SSID=\"SSID_WPA3CM\",Security.ModeEnabled=\"WPA3-Personal\",Security.KeyPassphrase=\"password\",Enable=1)\"" | grep -Ev '^(>|$)'
  X_PRPLWARE-COM_WiFiController.Network.AccessPoint.* (re)

  $ R "ba-cli \"X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit()\"" | grep -Ev '^(>|$)'
  X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit() returned
  [
      ""
  ]

Unfortunately, we cannot use prplmesh_agent_poll_operational here: Agent.Fronthaul.CurrentState does not change from
OPERATIONAL during Autoconfiguration Renew. So we sleep for 10 seconds instead.

  $ sleep 10

Check that 3 SSID instances are still operating:

  $ R logger -t cram "Search Values from Dataelements in private VAPs Configuration"

  $ check_ap_ref_ssid 1 Up
  Device.WiFi.AccessPoint.1 SSID Reference is Up

  $ check_ap_ref_ssid 3 Up
  Device.WiFi.AccessPoint.3 SSID Reference is Up

  $ check_ap_ref_ssid 5 Up
  Device.WiFi.AccessPoint.5 SSID Reference is Up

Check config from Nbapi AccessPoint is correctly applied : SSID / Security.ModeEnabled:

  $ wifi_dm "AccessPoint.1.SSIDReference+.SSID?"
  Device.WiFi.SSID.\d+.SSID="SSID_WPA3CM" (re)

  $ wifi_dm "AccessPoint.3.SSIDReference+.SSID?"
  Device.WiFi.SSID.\d+.SSID="SSID_WPA3CM" (re)

  $ wifi_dm "AccessPoint.5.SSIDReference+.SSID?"
  Device.WiFi.SSID.\d+.SSID="SSID_WPA3CM" (re)

Check if agent overrides the security mode:

  $ wifi_dm "AccessPoint.1.Security.ModeEnabled?"
  Device.WiFi.AccessPoint.1.Security.ModeEnabled="WPA3-Personal"

  $ wifi_dm "AccessPoint.3.Security.ModeEnabled?"
  Device.WiFi.AccessPoint.3.Security.ModeEnabled="WPA3-Personal"

  $ wifi_dm "AccessPoint.5.Security.ModeEnabled?"
  Device.WiFi.AccessPoint.5.Security.ModeEnabled="WPA3-Personal"

Push WPA3-Personal-Compatibility:

  $ R logger -t cram "Push WPA3-Personal-Compatibility"

  $ R "ba-cli -l X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Security.ModeEnabled=\"WPA3-Personal-Compatibility\"" | sed '/^$/d'
  WPA3-Personal-Compatibility

  $ R "ba-cli \"X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit()\"" | grep -Ev '^(>|$)'
  X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit() returned
  [
      ""
  ]

  $ sleep 10

Check if agent overrides the security mode:

  $ wifi_dm "AccessPoint.1.Security.ModeEnabled?"
  Device.WiFi.AccessPoint.1.Security.ModeEnabled="WPA3-Personal-Compatibility"

  $ wifi_dm "AccessPoint.3.Security.ModeEnabled?"
  Device.WiFi.AccessPoint.3.Security.ModeEnabled="WPA3-Personal-Compatibility"

  $ wifi_dm "AccessPoint.5.Security.ModeEnabled?"
  Device.WiFi.AccessPoint.5.Security.ModeEnabled="WPA3-Personal-Compatibility"

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

  $ prplmesh_stop
  $ R "sed -i 's/use_dataelements_vap_configs=./use_dataelements_vap_configs=0/g' /opt/prplmesh/config/beerocks_controller.conf"

Disable private vaps:

  $ R logger -t cram "Disable private vaps"
  $ disable_ap 1
  Device.WiFi.AccessPoint.1 disabled

  $ disable_ap 3
  Device.WiFi.AccessPoint.3 disabled

  $ disable_ap 5
  Device.WiFi.AccessPoint.5 disabled

Force restoring pwhm default MLDUnit:

  $ set_default_ap_mldunit
  $ sleep 5

Restart prplmesh:

  $ prplmesh_start

  $ R logger -t cram "$TESTFILE finished!"

