Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting MLO test 1/2 ..."

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
  backhaul_(AC:91:9B|58:E4:03):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  backhaul_(AC:91:9B|58:E4:03):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  backhaul_(AC:91:9B|58:E4:03):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  prplOS
  prplOS
  prplOS
  prplOS-guest
  prplOS-guest
  prplOS-guest

Check that no hostapd instance is running:

  $ R "pgrep -f 'hostapd -ddt'"
  [1]

Check default MLDUnit configuration:

  $ R "ba-cli -j -l WiFi.SSID.?0 | jsonfilter -e @[0]'[*].MLDUnit'" | LC_ALL=C sort
  -1
  -1
  -1
  0
  0
  0
  1
  1
  1
  2
  2
  2

Disable MLO on private and guest vaps:
  $ R logger -t cram "Disable MLO for all interfaces"

  $ R "ba-cli -j -l WiFi.SSID.*.MLDUnit=-1 | jsonfilter -e @[0]'[*].MLDUnit'"
  -1
  -1
  -1
  -1
  -1
  -1
  -1
  -1
  -1
  -1
  -1
  -1

Test activation of access point 1:

  $ R logger -t cram "Enable AP 1 "$(get_ssid_ref 1)""

  $ enable_ap 1
  WiFi.AccessPoint.1 enabled

  $ check_ap_ref_ssid 1 Up
  WiFi.AccessPoint.1 SSID Reference is Up

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

Save hostap pid:

  $ hostap_pid=$(R pgrep -f 'hostapd')
  $ R logger -t cram "hostap PID : $hostap_pid"

Test activation of access point 2:

  $ R logger -t cram "Enable AP 2 "$(get_ssid_ref 2)""

  $ enable_ap 2
  WiFi.AccessPoint.2 enabled

  $ check_ap_ref_ssid 2 Up
  WiFi.AccessPoint.2 SSID Reference is Up

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

Test activation of access point 3:

  $ R logger -t cram "Enable AP 3 "$(get_ssid_ref 3)""

  $ enable_ap 3
  WiFi.AccessPoint.3 enabled

  $ check_ap_ref_ssid 3 Up
  WiFi.AccessPoint.3 SSID Reference is Up

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

Test activation of access point 4:

  $ R logger -t cram "Enable AP 4 "$(get_ssid_ref 4)""

  $ enable_ap 4
  WiFi.AccessPoint.4 enabled

  $ check_ap_ref_ssid 4 Up
  WiFi.AccessPoint.4 SSID Reference is Up

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

Test activation of access point 5:

  $ R logger -t cram "Enable AP 5 "$(get_ssid_ref 5)""

  $ enable_ap 5
  WiFi.AccessPoint.5 enabled

  $ check_ap_ref_ssid 5 Up
  WiFi.AccessPoint.5 SSID Reference is Up

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

Test activation of access point 6:

  $ R logger -t cram "Enable AP 6 "$(get_ssid_ref 6)""

  $ enable_ap 6
  WiFi.AccessPoint.6 enabled

  $ check_ap_ref_ssid 6 Up
  WiFi.AccessPoint.6 SSID Reference is Up

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

Test activation of access point 7:

  $ R logger -t cram "Enable AP 7 "$(get_ssid_ref 7)""

  $ enable_ap 7
  WiFi.AccessPoint.7 enabled

  $ check_ap_ref_ssid 7 Up
  WiFi.AccessPoint.7 SSID Reference is Up

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

Test activation of access point 8:

  $ R logger -t cram "Enable AP 8 "$(get_ssid_ref 8)""

  $ enable_ap 8
  WiFi.AccessPoint.8 enabled

  $ check_ap_ref_ssid 8 Up
  WiFi.AccessPoint.8 SSID Reference is Up

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

Test activation of access point 9:

  $ R logger -t cram "Enable AP 9 "$(get_ssid_ref 9)""

  $ enable_ap 9
  WiFi.AccessPoint.9 enabled

  $ check_ap_ref_ssid 9 Up
  WiFi.AccessPoint.9 SSID Reference is Up

  $ sleep 10

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

  $ R "ps axw" | sed -nE 's/.*(hostapd .*)/\1/p' | head -1 | tr -s ' ' '\n' | LC_ALL=C sort
  -g
  -s
  /tmp/wlan0_hapd.conf
  /tmp/wlan1_hapd.conf
  /tmp/wlan2_hapd.conf
  /var/run/hostapd/global\.0x.* (re)
  hostapd

  $ R "ubus list | grep hostapd. | sort"
  hostapd.wlan0.1
  hostapd.wlan0.2
  hostapd.wlan0.3
  hostapd.wlan1.1
  hostapd.wlan1.2
  hostapd.wlan1.3
  hostapd.wlan2.1
  hostapd.wlan2.2
  hostapd.wlan2.3

Check iw interfaces and beaconing:

  $ R "iw dev | grep -e Interface -e ssid | tr -d '\t' | sort"
  Interface wlan0
  Interface wlan0.1
  Interface wlan0.2
  Interface wlan0.3
  Interface wlan1
  Interface wlan1.1
  Interface wlan1.2
  Interface wlan1.3
  Interface wlan2
  Interface wlan2.1
  Interface wlan2.2
  Interface wlan2.3
  ssid backhaul_(AC:91:9B|58:E4:03):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  ssid backhaul_(AC:91:9B|58:E4:03):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  ssid backhaul_(AC:91:9B|58:E4:03):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  ssid prplOS
  ssid prplOS
  ssid prplOS
  ssid prplOS-guest
  ssid prplOS-guest
  ssid prplOS-guest

Check if hostap pid has changed or not:

  $ if [ "$(R pgrep -f 'hostapd')" = "$hostap_pid" ]; then echo "true"; else echo "hostap restarted during the test !"; fi
  true

  $ R logger -t cram "MLO test 1/2 finished !"
