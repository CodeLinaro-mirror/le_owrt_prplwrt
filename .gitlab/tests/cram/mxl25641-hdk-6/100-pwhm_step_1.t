Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R "logger -t cram 'Starting PWHM test (step 1) ...'"

Wait for Device.WiFi. datamodel availability:

  $ R "amx_wait_for 'Device.WiFi.Radio.'"

  $ sleep 10

Stop prplMesh:

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=0" | tr -d '\n'
  0 (no-eol)

  $ sleep 2

Set AutoChannelEnable=0 on all Device.WiFi.Radio. interfaces:

  $ R "ba-cli -j -l WiFi.Radio.*.AutoChannelEnable=0 | sed '/^$/d'"
  [{"WiFi.Radio.1.":{"AutoChannelEnable":0},"WiFi.Radio.2.":{"AutoChannelEnable":0},"WiFi.Radio.3.":{"AutoChannelEnable":0}}]

Set channel to a non DFS one:

  $ R "usp-cli -j -l Device.WiFi.Radio.2.Channel=36 | sed '/^$/d'"
  [{"Device.WiFi.Radio.2.":{"Channel":36}}]

  $ sleep 5

Check default SSID status:

  $ get_ssid_status
  Down
  Down
  Down
  Down
  Down
  Down
  Down
  Down
  Down

Check default SSID configuration of access points:

  $ R "usp-cli -j -l Device.WiFi.SSID.?0 | jsonfilter -e @[0]'[@.Alias != \"ep2g0\" && @.Alias != \"ep5g0\" && @.Alias != \"ep6g0\"].SSID'" | LC_ALL=C sort
  backhaul_(4C:BA:7D|A8:C2:46|AC:9A:96):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  backhaul_(4C:BA:7D|A8:C2:46|AC:9A:96):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  backhaul_(4C:BA:7D|A8:C2:46|AC:9A:96):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  prplOS
  prplOS
  prplOS
  prplOS-guest
  prplOS-guest
  prplOS-guest

Check that no hostapd instance is running:

  $ R "pgrep -f 'hostapd -ddt'"
  [1]

Test activation of access point 1:

  $ R logger -t cram "Test AccessPoint 1 activation "$(get_ssid_ref 1)""

  $ enable_ap 1
  Device.WiFi.AccessPoint.1 enabled

  $ check_ap_ref_ssid 1 Up
  Device.WiFi.AccessPoint.1 SSID Reference is Up

  $ sleep 5

  $ get_ssid_status
  Down
  Down
  Down
  Down
  Down
  Down
  Down
  Down
  Up

Test activation of access point 2:

  $ R logger -t cram "Test AccessPoint 2 activation "$(get_ssid_ref 2)""

  $ enable_ap 2
  Device.WiFi.AccessPoint.2 enabled

  $ check_ap_ref_ssid 2 Up
  Device.WiFi.AccessPoint.2 SSID Reference is Up

  $ sleep 5

  $ get_ssid_status
  Down
  Down
  Down
  Down
  Down
  Down
  Down
  Up
  Up

Test activation of access point 3:

  $ R logger -t cram "Test AccessPoint 3 activation "$(get_ssid_ref 3)""

  $ enable_ap 3
  Device.WiFi.AccessPoint.3 enabled

  $ check_ap_ref_ssid 3 Up
  Device.WiFi.AccessPoint.3 SSID Reference is Up

  $ sleep 5

  $ get_ssid_status
  Down
  Down
  Down
  Down
  Down
  Down
  Up
  Up
  Up

Test activation of access point 4:

  $ R logger -t cram "Test AccessPoint 4 activation "$(get_ssid_ref 4)""

  $ enable_ap 4
  Device.WiFi.AccessPoint.4 enabled

  $ check_ap_ref_ssid 4 Up
  Device.WiFi.AccessPoint.4 SSID Reference is Up

  $ sleep 5

  $ get_ssid_status
  Down
  Down
  Down
  Down
  Down
  Up
  Up
  Up
  Up

Test activation of access point 5:

  $ R logger -t cram "Test AccessPoint 5 activation "$(get_ssid_ref 5)""

  $ enable_ap 5
  Device.WiFi.AccessPoint.5 enabled

  $ check_ap_ref_ssid 5 Up
  Device.WiFi.AccessPoint.5 SSID Reference is Up

  $ sleep 5

  $ get_ssid_status
  Down
  Down
  Down
  Down
  Up
  Up
  Up
  Up
  Up

Test activation of access point 6:

  $ R logger -t cram "Test AccessPoint 6 activation "$(get_ssid_ref 6)""

  $ enable_ap 6
  Device.WiFi.AccessPoint.6 enabled

  $ check_ap_ref_ssid 6 Up
  Device.WiFi.AccessPoint.6 SSID Reference is Up

  $ sleep 5

  $ get_ssid_status
  Down
  Down
  Down
  Up
  Up
  Up
  Up
  Up
  Up

Test activation of access point 7:

  $ R logger -t cram "Test AccessPoint 7 activation "$(get_ssid_ref 7)""

  $ enable_ap 7
  Device.WiFi.AccessPoint.7 enabled

  $ check_ap_ref_ssid 7 Up
  Device.WiFi.AccessPoint.7 SSID Reference is Up

  $ sleep 5

  $ get_ssid_status
  Down
  Down
  Up
  Up
  Up
  Up
  Up
  Up
  Up

Test activation of access point 8:

  $ R logger -t cram "Test AccessPoint 8 activation "$(get_ssid_ref 8)""

  $ enable_ap 8
  Device.WiFi.AccessPoint.8 enabled

  $ check_ap_ref_ssid 8 Up
  Device.WiFi.AccessPoint.8 SSID Reference is Up

  $ sleep 5

  $ get_ssid_status
  Down
  Up
  Up
  Up
  Up
  Up
  Up
  Up
  Up

Test activation of access point 9:

  $ R logger -t cram "Test AccessPoint 9 activation "$(get_ssid_ref 9)""

  $ enable_ap 9
  Device.WiFi.AccessPoint.9 enabled

  $ check_ap_ref_ssid 9 Up
  Device.WiFi.AccessPoint.9 SSID Reference is Up

  $ sleep 5

  $ get_ssid_status
  Up
  Up
  Up
  Up
  Up
  Up
  Up
  Up
  Up
