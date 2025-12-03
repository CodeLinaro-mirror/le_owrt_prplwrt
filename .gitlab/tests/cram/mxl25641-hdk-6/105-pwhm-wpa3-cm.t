Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting PWHM WPA3-CM test ..."

  $ R "ubus -t 60 wait_for Device.WiFi"

Set AutoChannelEnable=0 on all WiFi.Radio. interfaces:

  $ R "ba-cli -j -l WiFi.Radio.*.AutoChannelEnable=0 | sed '/^$/d'"
  [{"WiFi.Radio.1.":{"AutoChannelEnable":0},"WiFi.Radio.2.":{"AutoChannelEnable":0},"WiFi.Radio.3.":{"AutoChannelEnable":0}}]

Set channel to a non DFS one:

  $ R "ba-cli -j -l WiFi.Radio.2.Channel=36 | sed '/^$/d'"
  [{"WiFi.Radio.2.":{"Channel":36}}]

  $ sleep 5

Stop prplmesh:

  $ R logger -t cram "Stop prplmesh"

  $ R "( /etc/init.d/prplmesh stop 2>&1 > /dev/null; sleep 2 )"  2>&1 > /dev/null

Provisory: update Security.ModesAvailable as required by PPM-3660

  $ R "ba-cli \"WiFi.AccessPoint.[RadioReference == 'WiFi.Radio.radio0'].Security.ModesAvailable='None,WPA2-Personal,WPA3-Personal,WPA2-WPA3-Personal,WPA3-Personal-Compatibility,OWE'\" > /dev/null "

  $ R "ba-cli \"WiFi.AccessPoint.[RadioReference == 'WiFi.Radio.radio2'].Security.ModesAvailable='None,WPA2-Personal,WPA3-Personal,WPA2-WPA3-Personal,WPA3-Personal-Compatibility,OWE'\" > /dev/null "

  $ R "ba-cli \"WiFi.AccessPoint.[RadioReference == 'WiFi.Radio.radio4'].Security.ModesAvailable='WPA3-Personal,WPA3-Personal-Compatibility,OWE'\" > /dev/null "

Silently disable MLO:

  $ R logger -t cram "Disable MLO"
  $ R "ba-cli WiFi.SSID.*.MLDUnit=-1 > /dev/null"

Additionally, disable 11be to test absence of RSNOverride2 in 2.4/5 GHz:

  $ set_radio_operating_standard_format '2.4GHz' 'Legacy'
  Legacy

  $ set_radio_operating_standards '2.4GHz' 'ax'
  ax

  $ set_radio_operating_standard_format '5GHz' 'Legacy'
  Legacy

  $ set_radio_operating_standards '5GHz' 'ax'
  ax

Check all 9 VAPs contain WPA3-Personal-Compatibility in the Security.ModesAvailable list:

  $ R "ba-cli WiFi.AccessPoint.*.Security.ModesAvailable? | grep WPA3-Personal-Compatibility | wc -l"
  9

Enable private vaps:

  $ R logger -t cram "Enable private vaps"
  $ enable_ap 1
  WiFi.AccessPoint.1 enabled

  $ enable_ap 2
  WiFi.AccessPoint.2 enabled

  $ enable_ap 3
  WiFi.AccessPoint.3 enabled

  $ sleep 10

Check that 3 SSID instances are operating:

  $ check_ap_ref_ssid 1 Up
  WiFi.AccessPoint.1 SSID Reference is Up

  $ check_ap_ref_ssid 2 Up
  WiFi.AccessPoint.2 SSID Reference is Up

  $ check_ap_ref_ssid 3 Up
  WiFi.AccessPoint.3 SSID Reference is Up

Check wpa_key_mgmt is configured for WPA3-Transition in 5GHz hostapd.conf and rsn override params are absent:

  $ itf=$(R "ba-cli -l WiFi.AccessPoint.1.SSIDReference+.Name?" | sed '/^$/d')
  $ get_hapd_config $itf wpa_key_mgmt
  WPA-PSK SAE

  $ get_hapd_config $itf rsn_override_key_mgmt
  Option 'rsn_override_key_mgmt' not found

Check wpa_key_mgmt is configured for WPA3 in 6GHz hostapd.conf and rsn override params are absent:

  $ itf=$(R "ba-cli -l WiFi.AccessPoint.3.SSIDReference+.Name?" | sed '/^$/d')
  $ get_hapd_config $itf wpa_key_mgmt
  .*\bSAE\b.* (re)

  $ get_hapd_config $itf rsn_override_key_mgmt
  Option 'rsn_override_key_mgmt' not found

Set WPA3-Personal-Compatibility and search for one rsn override parameter in hostapd.conf
The functional test here is: Controller is able to read WPA3-Personal-Compatibility from pwhm; Agent receives WPA3-Personal-Compatibility from Controller:

  $ R logger -t cram "Set WPA3-Personal-Compatibility"
  $ R "ba-cli -l -j \"WiFi.AccessPoint.[Enable == 1].Security.ModeEnabled='WPA3-Personal-Compatibility'\" | jsonfilter -e @[0]'[*].ModeEnabled'"
  WPA3-Personal-Compatibility
  WPA3-Personal-Compatibility
  WPA3-Personal-Compatibility

  $ sleep 10

Agent did not overwrite the AccessPoint.Security.ModeEnabled in pwhm:

  $ R "ba-cli -j -l WiFi.AccessPoint.[Enable==1].Security.ModeEnabled? | jsonfilter -e @[0]'[@].ModeEnabled'"
  WPA3-Personal-Compatibility
  WPA3-Personal-Compatibility
  WPA3-Personal-Compatibility

We only test 2.4/5GHz for RSN Override 1 parameters; RSN Override 1 is not broadcasted by 6GHz:

  $ itf=$(R "ba-cli -l WiFi.AccessPoint.1.SSIDReference+.Name?" | sed '/^$/d')
  $ get_hapd_config $itf rsn_override_key_mgmt
  SAE

  $ itf=$(R "ba-cli -l WiFi.AccessPoint.2.SSIDReference+.Name?" | sed '/^$/d')
  $ get_hapd_config $itf rsn_override_key_mgmt
  SAE

Check RSN Override 2 parameters are absent in hostapd.conf (we disabled MLO and implicitly 11BE):

  $ itf=$(R "ba-cli -l WiFi.AccessPoint.1.SSIDReference+.Name?" | sed '/^$/d')
  $ get_hapd_config $itf rsn_override_key_mgmt_2
  Option 'rsn_override_key_mgmt_2' not found

  $ itf=$(R "ba-cli -l WiFi.AccessPoint.2.SSIDReference+.Name?" | sed '/^$/d')
  $ get_hapd_config $itf rsn_override_key_mgmt_2
  Option 'rsn_override_key_mgmt_2' not found

Restore MLDUnit to default values:

  $ R logger -t cram "Restore default MLD configuration"

  $ set_mlduint 1 0
  0

  $ set_mlduint 2 0
  0

  $ set_mlduint 3 0
  0

  $ set_mlduint 4 1
  1

  $ set_mlduint 5 1
  1

  $ set_mlduint 6 1
  1

Additionally, restore 11be to test absence of RSNOverride2 in 2.4/5 GHz:

  $ set_radio_operating_standard_format '2.4GHz' 'Standard'
  Standard

  $ set_radio_operating_standards '2.4GHz' 'b,g,n,ax,be'
  b,g,n,ax,be

  $ set_radio_operating_standard_format '5GHz' 'Standard'
  Standard

  $ set_radio_operating_standards '5GHz' 'a,n,ac,ax,be'
  a,n,ac,ax,be

  $ sleep 10

Check RSNO2 parameter was added to 5GHz hostapd conf file:

  $ itf=$(R "ba-cli -l WiFi.AccessPoint.1.SSIDReference+.Name?" | sed '/^$/d')
  $ get_hapd_config $itf rsn_override_key_mgmt_2
  .*\S.* (re)

Check RSNO2 parameter was added to 6GHz hostapd conf file

  $ itf=$(R "ba-cli -l WiFi.AccessPoint.3.SSIDReference+.Name?" | sed '/^$/d')
  $ get_hapd_config $itf rsn_override_key_mgmt_2
  .*\S.* (re)

Next, restore security modes in two steps: WPA3 Transition to 2.4GHz/5GHz, and WPA3 Personal to 6GHz

  $ R "ba-cli -j -l WiFi.AccessPoint.1.Security.ModeEnabled='WPA2-WPA3-Personal' | jsonfilter -e @[0]'[@].ModeEnabled'"
  WPA2-WPA3-Personal

  $ R "ba-cli -j -l WiFi.AccessPoint.2.Security.ModeEnabled='WPA2-WPA3-Personal' | jsonfilter -e @[0]'[@].ModeEnabled'"
  WPA2-WPA3-Personal

  $ R "ba-cli -j -l WiFi.AccessPoint.3.Security.ModeEnabled='WPA3-Personal' | jsonfilter -e @[0]'[@].ModeEnabled'"
  WPA3-Personal

  $ sleep 10

Here the expected configuration is: One VAP Enabled on 2.4 / 5 GHz / 6GHz bands // Security.ModeEnabled=WPA2-WPA3-Personal or WPA3-Personal

Check 5GHz is broadcasting WPA2-WPA3 Transition // at least WPA-PSK SAE // ignore 11BE/ AKM24

  $ itf=$(R "ba-cli -l WiFi.AccessPoint.1.SSIDReference+.Name?" | sed '/^$/d')
  $ get_hapd_config $itf wpa_key_mgmt
  (?=.*WPA-PSK)(?=.*SAE).* (re)

Check 2.4GHz is broadcasting WPA2-WPA3 Transition // at least WPA-PSK SAE // ignore 11BE/ AKM24

  $ itf=$(R "ba-cli -l WiFi.AccessPoint.2.SSIDReference+.Name?" | sed '/^$/d')
  $ get_hapd_config $itf wpa_key_mgmt
  (?=.*WPA-PSK)(?=.*SAE).* (re)

Check 6GHz is broadcasting WPA3 // at least SAE // ignore 11BE/ AKM24:

  $ itf=$(R "ba-cli -l WiFi.AccessPoint.3.SSIDReference+.Name?" | sed '/^$/d')
  $ get_hapd_config $itf wpa_key_mgmt
  .*\bSAE\b.* (re)

No more RSN Override in hostapd config files:

  $ R "cat /tmp/wlan*_hapd.conf | grep rsn_override | wc -l"
  0

Silently Disable all VAPs:

  $ R "ba-cli WiFi.AccessPoint.*.Enable=0 > /dev/null"

Restore default controller config:

  $ R logger -t cram "Restart prplmesh"

  $ R "( /etc/init.d/prplmesh gateway_mode ; sleep 2 ) > /tmp/prplmesh-gw-mode.log 2>&1 ; logger -t prplmesh-gateway-mode < /tmp/prplmesh-gw-mode.log"

  $ R "ubus -t 60 wait_for X_PRPLWARE-COM_WiFiController.Network.Device.1"

Check that prplmesh is running:

  $ R "ps axw" | sed -nE 's/.*(\/opt\/prplmesh\/bin.*)/\1/p' | LC_ALL=C sort
  /opt/prplmesh/bin/beerocks_agent
  /opt/prplmesh/bin/beerocks_controller
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan0
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan2
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan4
  /opt/prplmesh/bin/beerocks_vendor_message
  /opt/prplmesh/bin/ieee1905_transport

  $ R logger -t cram "Finishing PWHM WPA3-CM test ..."
