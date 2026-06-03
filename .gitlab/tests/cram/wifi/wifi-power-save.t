Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting PWHM power save test ..."

Stop prplMesh:

  $ R logger -t cram "Stop prplMesh"
  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=0" | tr -d '\n'
  0 (no-eol)

  $ sleep 5

Enable all AccessPoints:

  $ R logger -t cram "Enables all vaps"
  $ wifi_dm "AccessPoint.*.Enable=1"
  Device.WiFi.AccessPoint.1.Enable=1
  Device.WiFi.AccessPoint.2.Enable=1
  Device.WiFi.AccessPoint.3.Enable=1
  Device.WiFi.AccessPoint.4.Enable=1
  Device.WiFi.AccessPoint.5.Enable=1
  Device.WiFi.AccessPoint.6.Enable=1
  Device.WiFi.AccessPoint.7.Enable=1
  Device.WiFi.AccessPoint.8.Enable=1
  Device.WiFi.AccessPoint.9.Enable=1

  $ sleep 10

Check AccessPoints status:

  $ wifi_dm "AccessPoint.*.Status?0"
  Device.WiFi.AccessPoint.1.Status="Enabled"
  Device.WiFi.AccessPoint.2.Status="Enabled"
  Device.WiFi.AccessPoint.3.Status="Enabled"
  Device.WiFi.AccessPoint.4.Status="Enabled"
  Device.WiFi.AccessPoint.5.Status="Enabled"
  Device.WiFi.AccessPoint.6.Status="Enabled"
  Device.WiFi.AccessPoint.7.Status="Enabled"
  Device.WiFi.AccessPoint.8.Status="Enabled"
  Device.WiFi.AccessPoint.9.Status="Enabled"

Check radio status:

  $ wifi_dm "Radio.*.Status?"
  Device.WiFi.Radio.1.Status="Up"
  Device.WiFi.Radio.2.Status="Up"
  Device.WiFi.Radio.3.Status="Up"

Save hostap pid:

  $ hostap_pid=$(R pgrep -f 'hostapd')
  $ R logger -t cram "hostap PID : $hostap_pid"

Trigger power save on Radio 1:

  $ R logger -t cram "call SetRadioPowerDown"
  $ R "ba-cli -l 'WiFi.Radio.1.SetRadioPowerDown()'" |  sed '/^$/d'
  WiFi.Radio.1.SetRadioPowerDown() returned
  [
      ""
  ]

  $ sleep 10

Check radio status:

  $ wifi_dm "Radio.1.Status?"
  Device.WiFi.Radio.1.Status="Down"

Check corresponding AccessPoints status:

  $ get_radio_ap_status 1
  WiFi.AccessPoint.\d+.Status="Disabled" (re)
  WiFi.AccessPoint.\d+.Status="Disabled" (re)
  WiFi.AccessPoint.\d+.Status="Disabled" (re)

Before leaving the test, check if hostap pid has changed or not:

  $ if [ "$(R pgrep -f 'hostapd')" = "$hostap_pid" ]; then echo "true"; else echo "hostap restarted during the test !"; fi
  true

Disable all vaps:

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

Enable Radio 1:

  $ wifi_dm "Radio.1.Enable=1"
  Device.WiFi.Radio.1.Enable=1

  $ sleep 10

Check radio status:

  $ wifi_dm "Radio.*.Status?"   
  Device.WiFi.Radio.1.Status="Dormant"
  Device.WiFi.Radio.2.Status="Dormant"
  Device.WiFi.Radio.3.Status="Dormant"

Resume prplMesh:

  $ R logger -t cram "Resume prplMesh"
  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=1" | tr -d '\n'
  1 (no-eol)

  $ sleep 10
  $ R logger -t cram "Test finished!"
