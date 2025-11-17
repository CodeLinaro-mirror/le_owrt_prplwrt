Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting PWHM test ..."

Wait for Device.WiFi. datamodel availability:

  $ R "amx_wait_for "Device.WiFi." "

  $ sleep 10

Stop prplMesh:

  $ R "/etc/init.d/prplmesh stop 2>&1 > /dev/null"

Set AutoChannelEnable=0 on all WiFi.Radio. interfaces:

  $ R "ba-cli -j -l WiFi.Radio.*.AutoChannelEnable=0 | sed '/^$/d'"
  [{"WiFi.Radio.1.":{"AutoChannelEnable":0},"WiFi.Radio.2.":{"AutoChannelEnable":0},"WiFi.Radio.3.":{"AutoChannelEnable":0}}]

Set channel to a non DFS one:

  $ R "ba-cli -j -l WiFi.Radio.2.Channel=36 | sed '/^$/d'"
  [{"WiFi.Radio.2.":{"Channel":36}}]

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

  $ R "ba-cli -j -l WiFi.SSID.?0 | jsonfilter -e @[0]'[@.Alias != \"ep2g0\" && @.Alias != \"ep5g0\" && @.Alias != \"ep6g0\"].SSID'" | LC_ALL=C sort
  backhaul_(4C:BA:7D|A8:C2:46):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  backhaul_(4C:BA:7D|A8:C2:46):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  backhaul_(4C:BA:7D|A8:C2:46):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
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
  WiFi.AccessPoint.1 enabled

  $ check_ap_ref_ssid 1 Up
  WiFi.AccessPoint.1 SSID Reference is Up

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
  WiFi.AccessPoint.2 enabled

  $ check_ap_ref_ssid 2 Up
  WiFi.AccessPoint.2 SSID Reference is Up

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
  WiFi.AccessPoint.3 enabled

  $ check_ap_ref_ssid 3 Up
  WiFi.AccessPoint.3 SSID Reference is Up

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
  WiFi.AccessPoint.4 enabled

  $ check_ap_ref_ssid 4 Up
  WiFi.AccessPoint.4 SSID Reference is Up

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
  WiFi.AccessPoint.5 enabled

  $ check_ap_ref_ssid 5 Up
  WiFi.AccessPoint.5 SSID Reference is Up

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
  WiFi.AccessPoint.6 enabled

  $ check_ap_ref_ssid 6 Up
  WiFi.AccessPoint.6 SSID Reference is Up

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
  WiFi.AccessPoint.7 enabled

  $ check_ap_ref_ssid 7 Up
  WiFi.AccessPoint.7 SSID Reference is Up

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
  WiFi.AccessPoint.8 enabled

  $ check_ap_ref_ssid 8 Up
  WiFi.AccessPoint.8 SSID Reference is Up

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
  WiFi.AccessPoint.9 enabled

  $ check_ap_ref_ssid 9 Up
  WiFi.AccessPoint.9 SSID Reference is Up

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
  ssid backhaul_(4C:BA:7D|A8:C2:46):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  ssid backhaul_(4C:BA:7D|A8:C2:46):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  ssid backhaul_(4C:BA:7D|A8:C2:46):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
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
  WiFi.AccessPoint.9 disabled

  $ check_ap_ref_ssid 9 Down
  WiFi.AccessPoint.9 SSID Reference is Down

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
  WiFi.AccessPoint.8 disabled

  $ check_ap_ref_ssid 8 Down
  WiFi.AccessPoint.8 SSID Reference is Down

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
  WiFi.AccessPoint.7 disabled

  $ check_ap_ref_ssid 7 Down
  WiFi.AccessPoint.7 SSID Reference is Down

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
  WiFi.AccessPoint.6 disabled

  $ check_ap_ref_ssid 6 Down
  WiFi.AccessPoint.6 SSID Reference is Down

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
  WiFi.AccessPoint.5 disabled

  $ check_ap_ref_ssid 5 Down
  WiFi.AccessPoint.5 SSID Reference is Down

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
  WiFi.AccessPoint.4 disabled

  $ check_ap_ref_ssid 4 Down
  WiFi.AccessPoint.4 SSID Reference is Down

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
  WiFi.AccessPoint.3 disabled

  $ check_ap_ref_ssid 3 Down
  WiFi.AccessPoint.3 SSID Reference is Down

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
  WiFi.AccessPoint.2 disabled

  $ check_ap_ref_ssid 2 Down
  WiFi.AccessPoint.2 SSID Reference is Down

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

Resume prplMesh:

  $ R "/etc/init.d/prplmesh start 2>&1 > /dev/null"

  $ R logger -t cram "Stopping PWHM test .."

Wait 20s before leaving the test:

  $ sleep 20

  $ R logger -t cram "Test finished!"

