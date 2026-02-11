Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting MLO test 2/2 ..."

Save hostap pid:

  $ hostap_pid=$(R pgrep -f 'hostapd')
  $ R logger -t cram "hostap PID : $hostap_pid"

Test deactivation of access point 9:

  $ R logger -t cram "Disable AP 9 "$(get_ssid_ref 9)""

  $ disable_ap 9
  WiFi.AccessPoint.9 disabled

  $ check_ap_ref_ssid 9 Down
  WiFi.AccessPoint.9 SSID Reference is Down

  $ sleep 10

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

  $ R logger -t cram "Disable AP 8 "$(get_ssid_ref 8)""

  $ disable_ap 8
  WiFi.AccessPoint.8 disabled

  $ check_ap_ref_ssid 8 Down
  WiFi.AccessPoint.8 SSID Reference is Down

  $ sleep 10

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

  $ R logger -t cram "Disable AP 7 "$(get_ssid_ref 7)""

  $ disable_ap 7
  WiFi.AccessPoint.7 disabled

  $ check_ap_ref_ssid 7 Down
  WiFi.AccessPoint.7 SSID Reference is Down

  $ sleep 10

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

  $ R logger -t cram "Disable AP 6 "$(get_ssid_ref 6)""

  $ disable_ap 6
  WiFi.AccessPoint.6 disabled

  $ check_ap_ref_ssid 6 Down
  WiFi.AccessPoint.6 SSID Reference is Down

  $ sleep 10

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

  $ R logger -t cram "Disable AP 5 "$(get_ssid_ref 5)""

  $ disable_ap 5
  WiFi.AccessPoint.5 disabled

  $ check_ap_ref_ssid 5 Down
  WiFi.AccessPoint.5 SSID Reference is Down

  $ sleep 10

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

  $ R logger -t cram "Disable AP 4 "$(get_ssid_ref 4)""

  $ disable_ap 4
  WiFi.AccessPoint.4 disabled

  $ check_ap_ref_ssid 4 Down
  WiFi.AccessPoint.4 SSID Reference is Down

  $ sleep 10

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

  $ R logger -t cram "Disable AP 3 "$(get_ssid_ref 3)""

  $ disable_ap 3
  WiFi.AccessPoint.3 disabled

  $ check_ap_ref_ssid 3 Down
  WiFi.AccessPoint.3 SSID Reference is Down

  $ sleep 10

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

  $ R logger -t cram "Disable AP 2 "$(get_ssid_ref 2)""

  $ disable_ap 2
  WiFi.AccessPoint.2 disabled

  $ check_ap_ref_ssid 2 Down
  WiFi.AccessPoint.2 SSID Reference is Down

  $ sleep 10

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

Before deactivating last AP (ie stopping hostpad), check if hostap pid has changed or not:

  $ if [ "$(R pgrep -f 'hostapd')" = "$hostap_pid" ]; then echo "true"; else echo "hostap restarted during the test !"; fi
  true

Test deactivation of access point 1:

  $ R logger -t cram "Disable AP 1 "$(get_ssid_ref 1)""

  $ disable_ap 1
  WiFi.AccessPoint.1 disabled

  $ check_ap_ref_ssid 1 Down
  WiFi.AccessPoint.1 SSID Reference is Down

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

Restore defautlt MLDUnit values:

  $ R logger -t cram "Restore default MLD configuration"

  $ R 'ba-cli -l WiFi.AccessPoint.1.SSIDReference+.MLDUnit=0' | sed '/^$/d'
  0

  $ R 'ba-cli -l WiFi.AccessPoint.2.SSIDReference+.MLDUnit=1' | sed '/^$/d'
  1

  $ R 'ba-cli -l WiFi.AccessPoint.3.SSIDReference+.MLDUnit=0' | sed '/^$/d'
  0

  $ R 'ba-cli -l WiFi.AccessPoint.4.SSIDReference+.MLDUnit=1' | sed '/^$/d'
  1

  $ R 'ba-cli -l WiFi.AccessPoint.5.SSIDReference+.MLDUnit=0' | sed '/^$/d'
  0

  $ R 'ba-cli -l WiFi.AccessPoint.6.SSIDReference+.MLDUnit=1' | sed '/^$/d'
  1

  $ R 'ba-cli -l WiFi.AccessPoint.7.SSIDReference+.MLDUnit=2' | sed '/^$/d'
  2

  $ R 'ba-cli -l WiFi.AccessPoint.8.SSIDReference+.MLDUnit=2' | sed '/^$/d'
  2

  $ R 'ba-cli -l WiFi.AccessPoint.9.SSIDReference+.MLDUnit=2' | sed '/^$/d'
  2

Resume prplMesh:

  $ R "/etc/init.d/prplmesh start 2>&1 > /dev/null"

  $ R logger -t cram "Stopping MLO test .."

Wait 20s before leaving the test:

  $ sleep 10
  $ R logger -t cram "MLO test 2/2 finished !"
