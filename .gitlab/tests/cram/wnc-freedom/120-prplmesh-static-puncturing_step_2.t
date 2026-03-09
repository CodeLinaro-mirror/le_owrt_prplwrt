Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R "logger -t cram 'Starting prplMesh static puncturing test (step 2) ...'"

Check channels 40,44,48:

  $ wifi_dm_radio_band 5 "StaticPuncturing.DisabledSubChannels?"
  Device.WiFi.Radio.\d+.StaticPuncturing.DisabledSubChannels="40,44,48" (re)

Push 0b0000 0d00 - clear Radio.StaticPuncturing.DisabledSubChannels list:

  $ R logger -t cram "clear DisabledSubChannels"
  $ R "ba-cli -l \"X_PRPLWARE-COM_WiFiController.Network.Device.1.Radio.*.BSS.*.SetEHTOperations(DisabledSubchannelBitmap=0)\""  |  sed '/^$/d'
  X_PRPLWARE-COM_WiFiController\.Network\.Device\.1\.Radio\.[0-9][0-9]*\.BSS\.[0-9][0-9]*\.SetEHTOperations\(\) returned (re)
  [
      ""
  ]

  $ sleep 5

Check channels puncturing deactivation:

  $ wifi_dm_radio_band 5 "StaticPuncturing.DisabledSubChannels?"
  Device.WiFi.Radio.\d+.StaticPuncturing.DisabledSubChannels="" (re)

Restore defaults:

  $ R logger -t cram "Restore defaults"
  $ R "ba-cli -l \"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.SSID=\"prplOS\"\"" | sed '/^$/d'
  prplOS

  $ R "ba-cli -l \"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Security.ModeEnabled=\"WPA3-Personal-Transition\"\"" | sed '/^$/d'
  WPA3-Personal-Transition

  $ R "ba-cli \"X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit()\"" | tail -n +2 |  sed '/^$/d'
  X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit() returned
  [
      ""
  ]

  $ sleep 10

  $ R logger -t cram "Stop prplmesh"

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=0" | tr -d '\n'
  0 (no-eol)

  $ sleep 2
  $ R "sed -i 's/use_dataelements_vap_configs=1/use_dataelements_vap_configs=0/g' /opt/prplmesh/config/beerocks_controller.conf"

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

Restart prplmesh:

  $ R logger -t cram "Restart prplmesh"
  $ R "ba-cli X_PRPLWARE-COM_ProcessManager.PrplMesh.ManagementMode=Multi-AP-Controller-and-Agent"  > /dev/null
  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=1" | tr -d '\n'
  1 (no-eol)

  $ R "amx_wait_for X_PRPLWARE-COM_WiFiController.Network.Device.1"

  $ R logger -t cram "Test finished!"
