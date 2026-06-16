Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting PWHM WPA3-CM test ..."

Wait for PWHM and add timeout for it to connect to mapper:
  $ R "amx_wait_for WiFi.Radio."
  $ sleep 5

Set AutoChannelEnable=0 on all Device.WiFi.Radio. interfaces:

  $ R "ba-cli -j -l WiFi.Radio.*.AutoChannelEnable=0 | sed '/^$/d'"
  [{"WiFi.Radio.1.":{"AutoChannelEnable":0},"WiFi.Radio.2.":{"AutoChannelEnable":0},"WiFi.Radio.3.":{"AutoChannelEnable":0}}]

Set channel to a non DFS one:

  $ R "usp-cli -j -l Device.WiFi.Radio.2.Channel=36 | sed '/^$/d'"
  [{"Device.WiFi.Radio.2.":{"Channel":36}}]

  $ sleep 5

Stop prplmesh:

  $ R logger -t cram "Stop prplmesh"

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=0" | tr -d '\n'
  0 (no-eol)

  $ sleep 2

Silently disable MLO:

  $ R logger -t cram "Disable MLO"
  $ R "usp-cli Device.WiFi.SSID.*.MLDUnit=-1 > /dev/null"

Check all 9 VAPs contain WPA3-Personal-Compatibility in the Security.ModesAvailable list:

  $ R "usp-cli Device.WiFi.AccessPoint.*.Security.X_PRPLWARE-COM_ModesAvailable? | grep WPA3-Personal-Compatibility | wc -l"
  9

Enable private vaps:

  $ R logger -t cram "Enable private vaps"
  $ enable_ap 1
  Device.WiFi.AccessPoint.1 enabled

  $ enable_ap 3
  Device.WiFi.AccessPoint.3 enabled

  $ enable_ap 5
  Device.WiFi.AccessPoint.5 enabled

  $ sleep 10

Check that 3 SSID instances are operating:

  $ check_ap_ref_ssid 1 Up
  Device.WiFi.AccessPoint.1 SSID Reference is Up

  $ check_ap_ref_ssid 3 Up
  Device.WiFi.AccessPoint.3 SSID Reference is Up

  $ check_ap_ref_ssid 5 Up
  Device.WiFi.AccessPoint.5 SSID Reference is Up

Check wpa_key_mgmt is configured for WPA3-Transition in 5GHz hostapd.conf and rsn override params are absent:

  $ itf=$(R "usp-cli -l Device.WiFi.AccessPoint.3.SSIDReference+.Name?" | sed '/^$/d')
  $ get_hapd_config $itf wpa_key_mgmt
  WPA-PSK SAE

  $ get_hapd_config $itf rsn_override_key_mgmt
  Option 'rsn_override_key_mgmt' not found

Check wpa_key_mgmt is configured for WPA3 in 6GHz hostapd.conf and rsn override params are absent:

  $ itf=$(R "usp-cli -l Device.WiFi.AccessPoint.5.SSIDReference+.Name?" | sed '/^$/d')
  $ get_hapd_config $itf wpa_key_mgmt
  .*\bSAE\b.* (re)

  $ get_hapd_config $itf rsn_override_key_mgmt
  Option 'rsn_override_key_mgmt' not found

Set WPA3-Personal-Compatibility and search for one rsn override parameter in hostapd.conf
The functional test here is: Controller is able to read WPA3-Personal-Compatibility from pwhm; Agent receives WPA3-Personal-Compatibility from Controller:

  $ R logger -t cram "Set WPA3-Personal-Compatibility"
  $ R "usp-cli -l -j \"Device.WiFi.AccessPoint.[Enable == 1].Security.ModeEnabled='WPA3-Personal-Compatibility'\" | jsonfilter -e @[0]'[*].ModeEnabled'"
  WPA3-Personal-Compatibility
  WPA3-Personal-Compatibility
  WPA3-Personal-Compatibility

  $ sleep 10

Agent did not overwrite the AccessPoint.Security.ModeEnabled in pwhm:

  $ R "usp-cli -j -l Device.WiFi.AccessPoint.[Enable==1].Security.ModeEnabled? | jsonfilter -e @[0]'[@].ModeEnabled'"
  WPA3-Personal-Compatibility
  WPA3-Personal-Compatibility
  WPA3-Personal-Compatibility

We only test 2.4/5GHz for RSN Override 1 parameters; RSN Override 1 is not broadcasted by 6GHz:

  $ itf=$(R "usp-cli -l Device.WiFi.AccessPoint.1.SSIDReference+.Name?" | sed '/^$/d')
  $ get_hapd_config $itf rsn_override_key_mgmt
  SAE

  $ itf=$(R "usp-cli -l Device.WiFi.AccessPoint.3.SSIDReference+.Name?" | sed '/^$/d')
  $ get_hapd_config $itf rsn_override_key_mgmt
  SAE

Check RSN Override 2 parameters are absent in hostapd.conf (we disabled MLO and implicitly 11BE):

  $ itf=$(R "usp-cli -l Device.WiFi.AccessPoint.1.SSIDReference+.Name?" | sed '/^$/d')
  $ get_hapd_config $itf rsn_override_key_mgmt_2
  Option 'rsn_override_key_mgmt_2' not found

  $ itf=$(R "usp-cli -l Device.WiFi.AccessPoint.3.SSIDReference+.Name?" | sed '/^$/d')
  $ get_hapd_config $itf rsn_override_key_mgmt_2
  Option 'rsn_override_key_mgmt_2' not found

Restore MLDUnit to default values

  $ R logger -t cram "Restore default MLD configuration"

  $ set_mlduint 1 0
  0

  $ set_mlduint 2 1
  1

  $ set_mlduint 3 0
  0

  $ set_mlduint 4 1
  1

  $ set_mlduint 5 0
  0

  $ set_mlduint 6 1
  1

  $ set_mlduint 7 2
  2

  $ set_mlduint 8 2
  2

  $ set_mlduint 9 2
  2

  $ sleep 10

Check RSNO2 parameter was added to 5GHz hostapd conf file:

  $ itf=$(R "usp-cli -l Device.WiFi.AccessPoint.3.SSIDReference+.Name?" | sed '/^$/d')
  $ get_hapd_config $itf rsn_override_key_mgmt_2
  .*\S.* (re)

Check RSNO2 parameter was added to 6GHz hostapd conf file

  $ itf=$(R "usp-cli -l Device.WiFi.AccessPoint.5.SSIDReference+.Name?" | sed '/^$/d')
  $ get_hapd_config $itf rsn_override_key_mgmt_2
  .*\S.* (re)

Next, restore security modes in two steps: WPA3 Transition to 2.4GHz/5GHz, and WPA3 Personal to 6GHz

  $ R "usp-cli -j -l Device.WiFi.AccessPoint.1.Security.ModeEnabled='WPA3-Personal-Transition' | jsonfilter -e @[0]'[@].ModeEnabled'"
  WPA3-Personal-Transition

  $ R "usp-cli -j -l Device.WiFi.AccessPoint.3.Security.ModeEnabled='WPA3-Personal-Transition' | jsonfilter -e @[0]'[@].ModeEnabled'"
  WPA3-Personal-Transition

  $ R "usp-cli -j -l Device.WiFi.AccessPoint.5.Security.ModeEnabled='WPA3-Personal' | jsonfilter -e @[0]'[@].ModeEnabled'"
  WPA3-Personal

  $ sleep 10

Here the expected configuration is: One VAP Enabled on 2.4 / 5 GHz / 6GHz bands // Security.ModeEnabled=WPA3-Personal-Transition or WPA3-Personal

Check 5GHz is broadcasting WPA3 Transition // at least WPA-PSK SAE // ignore 11BE/ AKM24

  $ itf=$(R "usp-cli -l Device.WiFi.AccessPoint.3.SSIDReference+.Name?" | sed '/^$/d')
  $ get_hapd_config $itf wpa_key_mgmt
  (?=.*WPA-PSK)(?=.*SAE).* (re)

Check 2.4GHz is broadcasting WPA3 Transition // at least WPA-PSK SAE // ignore 11BE/ AKM24

  $ itf=$(R "usp-cli -l Device.WiFi.AccessPoint.1.SSIDReference+.Name?" | sed '/^$/d')
  $ get_hapd_config $itf wpa_key_mgmt
  (?=.*WPA-PSK)(?=.*SAE).* (re)

Check 6GHz is broadcasting WPA3 // at least SAE // ignore 11BE/ AKM24:

  $ itf=$(R "usp-cli -l Device.WiFi.AccessPoint.5.SSIDReference+.Name?" | sed '/^$/d')
  $ get_hapd_config $itf wpa_key_mgmt
  .*\bSAE\b.* (re)

No more RSN Override in hostapd config files:

  $ R "cat /tmp/wlan*_hapd.conf | grep rsn_override | wc -l"
  0

Silently Disable all VAPs:

  $ R "usp-cli Device.WiFi.AccessPoint.*.Enable=0 > /dev/null"

Wait VAP disabled completely:

  $ sleep 15

Restore default controller config:

  $ R logger -t cram "Restart prplmesh"

  $ R "ba-cli X_PRPLWARE-COM_ProcessManager.PrplMesh.ManagementMode=Multi-AP-Controller-and-Agent"  > /dev/null
  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=1" | tr -d '\n'
  1 (no-eol)

  $ R "ubus -t 60 wait_for X_PRPLWARE-COM_WiFiController.Network.Device.1"

Check that prplmesh is running:

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Status?" | tr -d '\n'
  Active (no-eol)

  $ R logger -t cram "Finishing PWHM WPA3-CM test ..."
