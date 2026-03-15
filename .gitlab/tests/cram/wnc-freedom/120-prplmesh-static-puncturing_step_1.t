Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R "logger -t cram 'Starting prplMesh static puncturing test 1/2 ...'"

Set AutoChannelEnable=0 on all WiFi.Radio. interfaces:

  $ wifi_dm "Radio.*.AutoChannelEnable=0"
  Device.WiFi.Radio.1.AutoChannelEnable=0
  Device.WiFi.Radio.2.AutoChannelEnable=0
  Device.WiFi.Radio.3.AutoChannelEnable=0

Set channel to a non DFS one:

  $ wifi_dm "Radio.[OperatingFrequencyBand==\"5GHz\"].Channel=36"
  Device.WiFi.Radio.\d+.Channel=36 (re)

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

  $ R "amx_wait_for X_PRPLWARE-COM_WiFiController.Network.Device.1"

Disable all AP:

  $ R logger -t cram "Disable all vaps"
  $ wifi_dm "AccessPoint.*.Enable=0"
  Device.WiFi.AccessPoint.1.Enable=0
  Device.WiFi.AccessPoint.2.Enable=0
  Device.WiFi.AccessPoint.3.Enable=0
  Device.WiFi.AccessPoint.4.Enable=0
  Device.WiFi.AccessPoint.5.Enable=0
  Device.WiFi.AccessPoint.6.Enable=0
  Device.WiFi.AccessPoint.7.Enable=0
  Device.WiFi.AccessPoint.8.Enable=0
  Device.WiFi.AccessPoint.9.Enable=0

  $ sleep 10

Check AccessPoints status:

  $ wifi_dm "AccessPoint.*.Status?0"
  Device.WiFi.AccessPoint.1.Status="Disabled"
  Device.WiFi.AccessPoint.2.Status="Disabled"
  Device.WiFi.AccessPoint.3.Status="Disabled"
  Device.WiFi.AccessPoint.4.Status="Disabled"
  Device.WiFi.AccessPoint.5.Status="Disabled"
  Device.WiFi.AccessPoint.6.Status="Disabled"
  Device.WiFi.AccessPoint.7.Status="Disabled"
  Device.WiFi.AccessPoint.8.Status="Disabled"
  Device.WiFi.AccessPoint.9.Status="Disabled"

First call of AccessPointCommit, controller should push empty config to agents:

  $ R logger -t cram "first call of AccessPointCommit pushes empty config, global teardown"

  $ R "ba-cli \"X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit()\"" | tail -n +2 |  sed '/^$/d'
  X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit() returned
  [
      ""
  ]

  $ sleep 10

Create one instances of Network.AccessPoint and push it to the agent:

  $ R logger -t cram "create instances of Network.AccessPoint and push them to the agent"

  $ R "ba-cli \"X_PRPLWARE-COM_WiFiController.Network.AccessPoint+(MLDUnit=0,Band5GH=1,Band5GL=1,MultiApMode=\"Fronthaul+Backhaul\",X_PRPLWARE_VapType=\"home\",SSID=\"SSIDforStaticPunct\",Security.ModeEnabled=\"WPA3-Personal\",Security.KeyPassphrase=\"password\",Enable=1)\"" | tail -n +2 | sed '/^$/d'
  X_PRPLWARE-COM_WiFiController.Network.AccessPoint.* (re)

  $ R "ba-cli \"X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit()\"" | tail -n +2 |  sed '/^$/d'
  X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit() returned
  [
      ""
  ]

  $ sleep 10

Check that 5GHz private vap status:

  $ wifi_dm "AccessPoint.3.SSIDReference+.Status?"
  Device.WiFi.SSID.\d+.Status="Up" (re)

Check the new SSID SSIDforStaticPunct is applied 1 time

  $ wifi_dm "AccessPoint.3.SSIDReference+.SSID?"
  Device.WiFi.SSID.\d+.SSID="SSIDforStaticPunct" (re)

Check that static puncturing is disabled in hostpad config files:

  $ R "grep punct_bitmap /tmp/wlan*_hapd.conf"
  [1]

No NBAPI function to set channel; taking advantage of gateway mode and write directly to PWHM. grep to remove empty line:

  $ wifi_dm_radio_band 5 "OperatingChannelBandwidth=\"80MHz\""
  Device.WiFi.Radio.\d+.OperatingChannelBandwidth="80MHz" (re)

  $ sleep 5

Check that 5GHz Radio reports opClass 115 channels 36,40,44,48:

  $ wifi_dm_radio_band 5 "ChannelsInUse?"
  Device.WiFi.Radio.\d+.ChannelsInUse="36,40,44,48" (re)

Push 0b0010 0d02 - disable channel 40:

  $ R logger -t cram "disable channel 40"
  $ R "ba-cli -l \"X_PRPLWARE-COM_WiFiController.Network.Device.1.Radio.*.BSS.*.SetEHTOperations(DisabledSubchannelBitmap=2)\""  |  sed '/^$/d'
  X_PRPLWARE-COM_WiFiController\.Network\.Device\.1\.Radio\.[0-9][0-9]*\.BSS\.[0-9][0-9]*\.SetEHTOperations\(\) returned (re)
  [
      ""
  ]

  $ sleep 5

Check channel 40:

  $ wifi_dm_radio_band 5 "StaticPuncturing.DisabledSubChannels?"
  Device.WiFi.Radio.\d+.StaticPuncturing.DisabledSubChannels=40 (re)

Check hostapd configuration:

  $ R "cat /tmp/wlan1_hapd.conf | grep punct"
  punct_bitmap=2

  $ R logger -t cram "prplMesh static puncturing test 1/2 finished !"
