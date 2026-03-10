Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R "logger -t cram 'Starting PWHM test (step 1) ...'"

Wait for Device.WiFi. datamodel availability:

  $ R "amx_wait_for Device.WiFi."

Stop prplMesh:

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=0" | tr -d '\n'
  0 (no-eol)

  $ sleep 2

Set AutoChannelEnable=0 on all Device.WiFi.Radio. interfaces:

  $ wifi_dm "Radio.*.AutoChannelEnable=0"
  Device.WiFi.Radio.1.AutoChannelEnable=0
  Device.WiFi.Radio.2.AutoChannelEnable=0
  Device.WiFi.Radio.3.AutoChannelEnable=0

Set channel to a non DFS one:

  $ wifi_dm "Radio.2.Channel=36"
  Device.WiFi.Radio.2.Channel=36 (re)

Check default SSID status:

  $ get_ap_status
  Device.WiFi.AccessPoint.1.Status="Disabled"
  Device.WiFi.AccessPoint.2.Status="Disabled"
  Device.WiFi.AccessPoint.3.Status="Disabled"
  Device.WiFi.AccessPoint.4.Status="Disabled"
  Device.WiFi.AccessPoint.5.Status="Disabled"
  Device.WiFi.AccessPoint.6.Status="Disabled"
  Device.WiFi.AccessPoint.7.Status="Disabled"
  Device.WiFi.AccessPoint.8.Status="Disabled"
  Device.WiFi.AccessPoint.9.Status="Disabled"

Check default SSID configuration of access points:

  $ get_ap_ssid
  AccessPoint.1.SSID="prplOS"
  AccessPoint.2.SSID="prplOS-guest"
  AccessPoint.3.SSID="prplOS"
  AccessPoint.4.SSID="prplOS-guest"
  AccessPoint.5.SSID="prplOS"
  AccessPoint.6.SSID="prplOS-guest"
  AccessPoint.7.SSID="backhaul_(AC:91:9B|58:E4:03):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}" (re)
  AccessPoint.8.SSID="backhaul_(AC:91:9B|58:E4:03):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}" (re)
  AccessPoint.9.SSID="backhaul_(AC:91:9B|58:E4:03):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}" (re)

Check that no hostapd instance is running:

  $ R "pgrep -f 'hostapd'"
  [1]

Test activation of access point 1:

  $ R logger -t cram "Test AccessPoint 1 activation "$(get_ssid_ref 1)""

  $ enable_ap_sync 1 1
  AccessPoint.\d+.Enable=1 (re)

  $ wifi_dm "AccessPoint.*.Status?0"
  Device.WiFi.AccessPoint.1.Status="Enabled"
  Device.WiFi.AccessPoint.2.Status="Disabled"
  Device.WiFi.AccessPoint.3.Status="Disabled"
  Device.WiFi.AccessPoint.4.Status="Disabled"
  Device.WiFi.AccessPoint.5.Status="Disabled"
  Device.WiFi.AccessPoint.6.Status="Disabled"
  Device.WiFi.AccessPoint.7.Status="Disabled"
  Device.WiFi.AccessPoint.8.Status="Disabled"
  Device.WiFi.AccessPoint.9.Status="Disabled"

Check wpacltrl socket file:

  $ ls_ap_hapd_socket 1
  /var/run/hostapd/wlan[0-9.]+_link[0-9].* (re)

  $ ls_hapd_sockets
  wlan2.1
  wlan2.1_link0

Save hostap pid:

  $ hostap_pid=$(R pgrep -f 'hostapd')
  $ R logger -t cram "hostap PID : $hostap_pid"

Test activation of access point 2:

  $ R logger -t cram "Test AccessPoint 2 activation "$(get_ssid_ref 2)""

  $ enable_ap_sync 2 1
  AccessPoint.2.Enable=1

  $ wifi_dm "AccessPoint.*.Status?0"
  Device.WiFi.AccessPoint.1.Status="Enabled"
  Device.WiFi.AccessPoint.2.Status="Enabled"
  Device.WiFi.AccessPoint.3.Status="Disabled"
  Device.WiFi.AccessPoint.4.Status="Disabled"
  Device.WiFi.AccessPoint.5.Status="Disabled"
  Device.WiFi.AccessPoint.6.Status="Disabled"
  Device.WiFi.AccessPoint.7.Status="Disabled"
  Device.WiFi.AccessPoint.8.Status="Disabled"
  Device.WiFi.AccessPoint.9.Status="Disabled"

Check wpacltrl socket file:

  $ ls_ap_hapd_socket 2
  /var/run/hostapd/wlan[0-9.]+_link[0-9] (re)

  $ ls_hapd_sockets
  wlan2.1
  wlan2.1_link0
  wlan2.2
  wlan2.2_link0

Test activation of access point 3:

  $ R logger -t cram "Test AccessPoint 3 activation "$(get_ssid_ref 3)""

  $ enable_ap_sync 3 1
  AccessPoint.3.Enable=1

  $ wifi_dm "AccessPoint.*.Status?0"
  Device.WiFi.AccessPoint.1.Status="Enabled"
  Device.WiFi.AccessPoint.2.Status="Enabled"
  Device.WiFi.AccessPoint.3.Status="Enabled"
  Device.WiFi.AccessPoint.4.Status="Disabled"
  Device.WiFi.AccessPoint.5.Status="Disabled"
  Device.WiFi.AccessPoint.6.Status="Disabled"
  Device.WiFi.AccessPoint.7.Status="Disabled"
  Device.WiFi.AccessPoint.8.Status="Disabled"
  Device.WiFi.AccessPoint.9.Status="Disabled"

Check wpacltrl socket file:

  $ ls_ap_hapd_socket 3
  /var/run/hostapd/wlan[0-9.]+_link[0-9] (re)

  $ ls_hapd_sockets
  wlan2.1
  wlan2.1_link0
  wlan2.1_link1
  wlan2.2
  wlan2.2_link0

Test activation of access point 4:

  $ R logger -t cram "Test AccessPoint 4 activation "$(get_ssid_ref 4)""

  $ enable_ap_sync 4 1
  AccessPoint.4.Enable=1

  $ wifi_dm "AccessPoint.*.Status?0"
  Device.WiFi.AccessPoint.1.Status="Enabled"
  Device.WiFi.AccessPoint.2.Status="Enabled"
  Device.WiFi.AccessPoint.3.Status="Enabled"
  Device.WiFi.AccessPoint.4.Status="Enabled"
  Device.WiFi.AccessPoint.5.Status="Disabled"
  Device.WiFi.AccessPoint.6.Status="Disabled"
  Device.WiFi.AccessPoint.7.Status="Disabled"
  Device.WiFi.AccessPoint.8.Status="Disabled"
  Device.WiFi.AccessPoint.9.Status="Disabled"

Check wpacltrl socket file:

  $ ls_ap_hapd_socket 4
  /var/run/hostapd/wlan[0-9.]+_link[0-9] (re)

  $ ls_hapd_sockets
  wlan2.1
  wlan2.1_link0
  wlan2.1_link1
  wlan2.2
  wlan2.2_link0
  wlan2.2_link1

Test activation of access point 5:

  $ R logger -t cram "Test AccessPoint 5 activation "$(get_ssid_ref 5)""

  $ enable_ap_sync 5 1
  AccessPoint.5.Enable=1

  $ wifi_dm "AccessPoint.*.Status?0"
  Device.WiFi.AccessPoint.1.Status="Enabled"
  Device.WiFi.AccessPoint.2.Status="Enabled"
  Device.WiFi.AccessPoint.3.Status="Enabled"
  Device.WiFi.AccessPoint.4.Status="Enabled"
  Device.WiFi.AccessPoint.5.Status="Enabled"
  Device.WiFi.AccessPoint.6.Status="Disabled"
  Device.WiFi.AccessPoint.7.Status="Disabled"
  Device.WiFi.AccessPoint.8.Status="Disabled"
  Device.WiFi.AccessPoint.9.Status="Disabled"

Check wpacltrl socket file:

  $ ls_ap_hapd_socket 5
  /var/run/hostapd/wlan[0-9.]+_link[0-9] (re)

  $ ls_hapd_sockets
  wlan2.1
  wlan2.1_link0
  wlan2.1_link1
  wlan2.1_link2
  wlan2.2
  wlan2.2_link0
  wlan2.2_link1

Test activation of access point 6:

  $ R logger -t cram "Test AccessPoint 6 activation "$(get_ssid_ref 6)""

  $ enable_ap_sync 6 1
  AccessPoint.6.Enable=1

  $ wifi_dm "AccessPoint.*.Status?0"
  Device.WiFi.AccessPoint.1.Status="Enabled"
  Device.WiFi.AccessPoint.2.Status="Enabled"
  Device.WiFi.AccessPoint.3.Status="Enabled"
  Device.WiFi.AccessPoint.4.Status="Enabled"
  Device.WiFi.AccessPoint.5.Status="Enabled"
  Device.WiFi.AccessPoint.6.Status="Enabled"
  Device.WiFi.AccessPoint.7.Status="Disabled"
  Device.WiFi.AccessPoint.8.Status="Disabled"
  Device.WiFi.AccessPoint.9.Status="Disabled"

Check wpacltrl socket file:

  $ ls_ap_hapd_socket 6
  /var/run/hostapd/wlan[0-9.]+_link[0-9] (re)

  $ ls_hapd_sockets
  wlan2.1
  wlan2.1_link0
  wlan2.1_link1
  wlan2.1_link2
  wlan2.2
  wlan2.2_link0
  wlan2.2_link1
  wlan2.2_link2

Test activation of access point 7:

  $ R logger -t cram "Test AccessPoint 7 activation "$(get_ssid_ref 7)""

  $ enable_ap_sync 7 1
  AccessPoint.7.Enable=1

  $ wifi_dm "AccessPoint.*.Status?0"
  Device.WiFi.AccessPoint.1.Status="Enabled"
  Device.WiFi.AccessPoint.2.Status="Enabled"
  Device.WiFi.AccessPoint.3.Status="Enabled"
  Device.WiFi.AccessPoint.4.Status="Enabled"
  Device.WiFi.AccessPoint.5.Status="Enabled"
  Device.WiFi.AccessPoint.6.Status="Enabled"
  Device.WiFi.AccessPoint.7.Status="Enabled"
  Device.WiFi.AccessPoint.8.Status="Disabled"
  Device.WiFi.AccessPoint.9.Status="Disabled"

Check wpacltrl socket file:

  $ ls_ap_hapd_socket 7
  /var/run/hostapd/wlan[0-9.]+_link[0-9] (re)

  $ ls_hapd_sockets
  wlan2.1
  wlan2.1_link0
  wlan2.1_link1
  wlan2.1_link2
  wlan2.2
  wlan2.2_link0
  wlan2.2_link1
  wlan2.2_link2
  wlan2.3
  wlan2.3_link0


Test activation of access point 8:

  $ R logger -t cram "Test AccessPoint 8 activation "$(get_ssid_ref 8)""

  $ enable_ap_sync 8 1
  AccessPoint.8.Enable=1

  $ wifi_dm "AccessPoint.*.Status?0"
  Device.WiFi.AccessPoint.1.Status="Enabled"
  Device.WiFi.AccessPoint.2.Status="Enabled"
  Device.WiFi.AccessPoint.3.Status="Enabled"
  Device.WiFi.AccessPoint.4.Status="Enabled"
  Device.WiFi.AccessPoint.5.Status="Enabled"
  Device.WiFi.AccessPoint.6.Status="Enabled"
  Device.WiFi.AccessPoint.7.Status="Enabled"
  Device.WiFi.AccessPoint.8.Status="Enabled"
  Device.WiFi.AccessPoint.9.Status="Disabled"

Check wpacltrl socket file:

  $ ls_ap_hapd_socket 8
  /var/run/hostapd/wlan[0-9.]+_link[0-9] (re)

  $ ls_hapd_sockets
  wlan2.1
  wlan2.1_link0
  wlan2.1_link1
  wlan2.1_link2
  wlan2.2
  wlan2.2_link0
  wlan2.2_link1
  wlan2.2_link2
  wlan2.3
  wlan2.3_link0
  wlan2.3_link1

Test activation of access point 9:

  $ R logger -t cram "Test AccessPoint 9 activation "$(get_ssid_ref 9)""

  $ enable_ap_sync 9 1
  AccessPoint.9.Enable=1

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

Check wpacltrl socket file:

  $ ls_ap_hapd_socket 9
  /var/run/hostapd/wlan[0-9.]+_link[0-9] (re)

  $ ls_hapd_sockets
  wlan2.1
  wlan2.1_link0
  wlan2.1_link1
  wlan2.1_link2
  wlan2.2
  wlan2.2_link0
  wlan2.2_link1
  wlan2.2_link2
  wlan2.3
  wlan2.3_link0
  wlan2.3_link1
  wlan2.3_link2

  $ sleep 5

Check if hostap pid has changed or not:

  $ if [ "$(R pgrep -f 'hostapd')" = "$hostap_pid" ]; then echo "true"; else echo "hostap restarted during the test !"; fi
  true
