Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R "logger -t cram 'Starting PWHM test (step 2) ...'"

Check that hostapd is operating as expected:

  $ R logger -t cram "Check that hostapd is operating"

  $ R "ps axw" | sed -nE 's/.*(hostapd.*)/\1/p' | head -3 | LC_ALL=C sort
  hostapd -t /tmp/wlan0_hapd.conf /tmp/wlan2_hapd.conf /tmp/wlan4_hapd.conf

Check iw interfaces and beaconing:

  $ R "iw dev | grep -e Interface -e ssid | tr -d '\t' | sort"
  Interface wlan0
  Interface wlan0.1
  Interface wlan0.2
  Interface wlan0.3
  Interface wlan1
  Interface wlan2
  Interface wlan2.1
  Interface wlan2.2
  Interface wlan2.3
  Interface wlan3
  Interface wlan4
  Interface wlan4.1
  Interface wlan4.2
  Interface wlan4.3
  Interface wlan5
  ssid backhaul_(4C:BA:7D|A8:C2:46|AC:9A:96):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  ssid backhaul_(4C:BA:7D|A8:C2:46|AC:9A:96):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  ssid backhaul_(4C:BA:7D|A8:C2:46|AC:9A:96):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  ssid dummy_ssid_2.4GHz
  ssid dummy_ssid_5GHz
  ssid dummy_ssid_6GHz
  ssid prplOS
  ssid prplOS
  ssid prplOS
  ssid prplOS-guest
  ssid prplOS-guest
  ssid prplOS-guest

Test deactivation of access point 9:

  $ R logger -t cram "Test AccessPoint 9 deactivation "$(get_ssid_ref 9)""

  $ disable_ap 9
  Device.WiFi.AccessPoint.9 disabled

  $ check_ap_ref_ssid 9 Down
  Device.WiFi.AccessPoint.9 SSID Reference is Down

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

Test deactivation of access point 8:

  $ R logger -t cram "Test AccessPoint 8 deactivation "$(get_ssid_ref 8)""

  $ disable_ap 8
  Device.WiFi.AccessPoint.8 disabled

  $ check_ap_ref_ssid 8 Down
  Device.WiFi.AccessPoint.8 SSID Reference is Down

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

Test deactivation of access point 7:

  $ R logger -t cram "Test AccessPoint 7 deactivation "$(get_ssid_ref 7)""

  $ disable_ap 7
  Device.WiFi.AccessPoint.7 disabled

  $ check_ap_ref_ssid 7 Down
  Device.WiFi.AccessPoint.7 SSID Reference is Down

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

Test deactivation of access point 6:

  $ R logger -t cram "Test AccessPoint 6 deactivation "$(get_ssid_ref 6)""

  $ disable_ap 6
  Device.WiFi.AccessPoint.6 disabled

  $ check_ap_ref_ssid 6 Down
  Device.WiFi.AccessPoint.6 SSID Reference is Down

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

Test deactivation of access point 5:

  $ R logger -t cram "Test AccessPoint 5 deactivation "$(get_ssid_ref 5)""

  $ disable_ap 5
  Device.WiFi.AccessPoint.5 disabled

  $ check_ap_ref_ssid 5 Down
  Device.WiFi.AccessPoint.5 SSID Reference is Down

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

Test deactivation of access point 4:

  $ R logger -t cram "Test AccessPoint 4 deactivation "$(get_ssid_ref 4)""

  $ disable_ap 4
  Device.WiFi.AccessPoint.4 disabled

  $ check_ap_ref_ssid 4 Down
  Device.WiFi.AccessPoint.4 SSID Reference is Down

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

Test deactivation of access point 3:

  $ R logger -t cram "Test AccessPoint 3 deactivation "$(get_ssid_ref 3)""

  $ disable_ap 3
  Device.WiFi.AccessPoint.3 disabled

  $ check_ap_ref_ssid 3 Down
  Device.WiFi.AccessPoint.3 SSID Reference is Down

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

Test deactivation of access point 2:

  $ R logger -t cram "Test AccessPoint 2 deactivation "$(get_ssid_ref 2)""

  $ disable_ap 2
  Device.WiFi.AccessPoint.2 disabled

  $ check_ap_ref_ssid 2 Down
  Device.WiFi.AccessPoint.2 SSID Reference is Down

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

Test deactivation of access point 1:

  $ R logger -t cram "Test AccessPoint 1 deactivation "$(get_ssid_ref 1)""

  $ disable_ap 1
  Device.WiFi.AccessPoint.1 disabled

  $ check_ap_ref_ssid 1 Down
  Device.WiFi.AccessPoint.1 SSID Reference is Down

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
  Down

Check if hostapd process is stopped:

  $ R "pgrep -f 'hostapd -ddt'"
  [1]

Resume prplMesh:

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=1" | tr -d '\n'
  1 (no-eol)

  $ R logger -t cram "Stopping PWHM test .."

Wait 20s before leaving the test:

  $ sleep 20

  $ R logger -t cram "Test finished!"
