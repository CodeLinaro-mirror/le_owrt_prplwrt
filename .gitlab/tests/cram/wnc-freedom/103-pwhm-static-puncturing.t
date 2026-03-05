Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting PWHM static puncturing test ..."

Stop prplMesh:

  $ R "/etc/init.d/prplmesh stop > /dev/null 2>&1"

Set AutoChannelEnable=0 on all WiFi.Radio. interfaces:

  $ wifi_dm "Radio.*.AutoChannelEnable=0"
  WiFi.Radio.1.AutoChannelEnable=0
  WiFi.Radio.2.AutoChannelEnable=0
  WiFi.Radio.3.AutoChannelEnable=0

Set channel to a non DFS one:

  $ wifi_dm "Radio.2.Channel=36"
  WiFi.Radio.\d+.Channel=36 (re)

Check default static puncturing configuration:

  $ wifi_dm "Radio.*.StaticPuncturing.DisabledSubChannels?"
  WiFi.Radio.1.StaticPuncturing.DisabledSubChannels=""
  WiFi.Radio.2.StaticPuncturing.DisabledSubChannels=""
  WiFi.Radio.3.StaticPuncturing.DisabledSubChannels=""

Set 5GHz channel bandwith to 80Mhz:

  $ wifi_dm_radio_band 5 "OperatingChannelBandwidth=\"80MHz\""
  WiFi.Radio.\d+.OperatingChannelBandwidth="80MHz" (re)

Get vap indexes:

  $ priv2g_idx=$(get_vap_index "2" "private")
  $ priv5g_idx=$(get_vap_index "5" "private")
  $ priv6g_idx=$(get_vap_index "6" "private")

Predict hostapd config files pathes:

  $ hapd_conf_2g="/tmp/$(get_ap_main_wlan ${priv2g_idx})_hapd.conf"
  $ hapd_conf_5g="/tmp/$(get_ap_main_wlan ${priv5g_idx})_hapd.conf"
  $ hapd_conf_6g="/tmp/$(get_ap_main_wlan ${priv6g_idx})_hapd.conf"

Enable private vaps:

  $ R logger -t cram "Enable private vaps"

  $ wifi_dm "AccessPoint.${priv2g_idx}.Enable=1"
  WiFi.AccessPoint.\d+.Enable=1 (re)

  $ wifi_dm "AccessPoint.${priv5g_idx}.Enable=1"
  WiFi.AccessPoint.\d+.Enable=1 (re)

  $ wifi_dm "AccessPoint.${priv6g_idx}.Enable=1"
  WiFi.AccessPoint.\d+.Enable=1 (re)

  $ sleep 10

Check that static puncturing is disabled in hostpad config files:

  $ R "grep punct_bitmap /tmp/wlan*_hapd.conf"
  [1]

Check that SSID are enabled:

  $ wifi_dm "AccessPoint.${priv2g_idx}.SSIDReference+.Status?"
  Device.WiFi.SSID.\d+.Status="Up" (re)

  $ wifi_dm "AccessPoint.${priv5g_idx}.SSIDReference+.Status?"
  Device.WiFi.SSID.\d+.Status="Up" (re)

  $ wifi_dm "AccessPoint.${priv6g_idx}.SSIDReference+.Status?"
  Device.WiFi.SSID.\d+.Status="Up" (re)

Check that 5GHz Radio reports opClass 115 channels 36,40,44,48:

  $ wifi_dm_radio_band 5 "ChannelsInUse?"
  WiFi.Radio.\d+.ChannelsInUse="36,40,44,48" (re)

Interacting with pwhm and hostapd.conf now
Hostapd syntax is bitmap with LSB indicating lowest channel; 0x01 - 36; 0x02 - 40; 0x04 - 44; 0x08 - 48; and sums thereof

Test static puncturing on 5GHz band:

  $ R logger -t cram "Test static puncturing on 5GHz band"
  $ R logger -t cram "disable channels 44"
  $ wifi_dm_radio_band 5 "StaticPuncturing.DisabledSubChannels=\"44\""
  WiFi.Radio.\d+.StaticPuncturing.DisabledSubChannels="44" (re)

  $ sleep 5

  $ R "cat ${hapd_conf_5g} | grep "punct_bitmap=""
  punct_bitmap=4

Test static puncturing on 6GHz band:

  $ R logger -t cram "Test static puncturing on 6GHz band"
  $ wifi_dm_radio_band 6 "OperatingChannelBandwidth=\"320MHz-1\""
  WiFi.Radio.\d+.OperatingChannelBandwidth="320MHz-1" (re)

  $ sleep 10

Check that 6GHz Radio reports opClass 137 channels, 16 in total:

  $ wifi_dm_radio_band 6 "ChannelsInUse?"
  WiFi.Radio.\d+.ChannelsInUse="1,5,9,13,17,21,25,29,33,37,41,45,49,53,57,61" (re)

Disable top 4 channels : 49,53,57,61; from python:
>>> (1<<15) + (1<<14) + (1<<13) + (1<<12)
61440

  $ R logger -t cram "disable channels 49,53,57,61"
  $ wifi_dm_radio_band 6 "StaticPuncturing.DisabledSubChannels=\"49,53,57,61\""
  WiFi.Radio.\d+.StaticPuncturing.DisabledSubChannels="49,53,57,61" (re)

  $ sleep 5

  $ R "cat ${hapd_conf_6g} | grep "punct_bitmap=""
  punct_bitmap=61440

  $ R logger -t cram "clear all DisabledSubChannels"
  $ wifi_dm_radio_band 5 "StaticPuncturing.DisabledSubChannels=\"\""
  WiFi.Radio.\d+.StaticPuncturing.DisabledSubChannels="" (re)
  $ wifi_dm_radio_band 6 "StaticPuncturing.DisabledSubChannels=\"\""
  WiFi.Radio.\d+.StaticPuncturing.DisabledSubChannels="" (re)

Disable all AP:

  $ R logger -t cram "Disable all vaps"
  $ wifi_dm "AccessPoint.*.Enable=0"
  WiFi.AccessPoint.1.Enable=0
  WiFi.AccessPoint.2.Enable=0
  WiFi.AccessPoint.3.Enable=0
  WiFi.AccessPoint.4.Enable=0
  WiFi.AccessPoint.5.Enable=0
  WiFi.AccessPoint.6.Enable=0
  WiFi.AccessPoint.7.Enable=0
  WiFi.AccessPoint.8.Enable=0
  WiFi.AccessPoint.9.Enable=0

  $ sleep 10

Check AccessPoints status:

  $ wifi_dm "AccessPoint.*.Status?0"
  WiFi.AccessPoint.1.Status="Disabled"
  WiFi.AccessPoint.2.Status="Disabled"
  WiFi.AccessPoint.3.Status="Disabled"
  WiFi.AccessPoint.4.Status="Disabled"
  WiFi.AccessPoint.5.Status="Disabled"
  WiFi.AccessPoint.6.Status="Disabled"
  WiFi.AccessPoint.7.Status="Disabled"
  WiFi.AccessPoint.8.Status="Disabled"
  WiFi.AccessPoint.9.Status="Disabled"

Restart prplMesh:

  $ R "( /etc/init.d/prplmesh gateway_mode ; sleep 2 ) > /tmp/prplmesh-gw-mode.log 2>&1 ; logger -t prplmesh-gateway-mode < /tmp/prplmesh-gw-mode.log"

  $ R "ubus -t 60 wait_for X_PRPLWARE-COM_WiFiController.Network.Device.1"

Check that prplmesh is running:

  $ R "ps axw" | sed -nE 's/.*(\/opt\/prplmesh\/bin.*)/\1/p' | LC_ALL=C sort
  /opt/prplmesh/bin/beerocks_agent
  /opt/prplmesh/bin/beerocks_controller
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan\d+ (re)
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan\d+ (re)
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan\d+ (re)
  /opt/prplmesh/bin/beerocks_vendor_message
  /opt/prplmesh/bin/ieee1905_transport

  $ R logger -t cram "Test finished!"
