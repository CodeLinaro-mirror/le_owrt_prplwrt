Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting PWHM test for custom arguments..."

Wait for Device.WiFi. datamodel availability:

  $ R "amx_wait_for "Device.WiFi." "

  $ sleep 10

Stop prplMesh:

  $ R "/etc/init.d/prplmesh stop 2>&1 > /dev/null"

Check that no hostapd instance is running:

  $ R "pgrep -f 'hostapd'"
  [1]

Check that no wpa_supplicant instance is running:

  $ R "pgrep -f 'wpa_supplicant'"
  [1]

Test activation of access point 1:

  $ R logger -t cram "Test AccessPoint 1 activation"

  $ enable_ap 1
  WiFi.AccessPoint.1 enabled

  $ check_ap_ref_ssid 1 Up
  WiFi.AccessPoint.1 SSID Reference is Up

  $ sleep 10

Test activation of access point 2:

  $ R logger -t cram "Test AccessPoint 2 activation"

  $ enable_ap 2
  WiFi.AccessPoint.2 enabled

  $ check_ap_ref_ssid 2 Up
  WiFi.AccessPoint.2 SSID Reference is Up

  $ sleep 10

Test activation of access point 3:

  $ R logger -t cram "Test AccessPoint 3 activation"

  $ enable_ap 3
  WiFi.AccessPoint.3 enabled

  $ check_ap_ref_ssid 3 Up
  WiFi.AccessPoint.3 SSID Reference is Up

  $ sleep 10

Test activation of access point 4:

  $ R logger -t cram "Test AccessPoint 4 activation"

  $ enable_ap 4
  WiFi.AccessPoint.4 enabled

  $ check_ap_ref_ssid 4 Up
  WiFi.AccessPoint.4 SSID Reference is Up

  $ sleep 10

Test activation of access point 5:

  $ R logger -t cram "Test AccessPoint 5 activation"

  $ enable_ap 5
  WiFi.AccessPoint.5 enabled

  $ check_ap_ref_ssid 5 Up
  WiFi.AccessPoint.5 SSID Reference is Up

  $ sleep 10

Test activation of access point 6:

  $ R logger -t cram "Test AccessPoint 6 activation"

  $ enable_ap 6
  WiFi.AccessPoint.6 enabled

  $ check_ap_ref_ssid 6 Up
  WiFi.AccessPoint.6 SSID Reference is Up

  $ sleep 10

Test activation of access point 7:

  $ R logger -t cram "Test AccessPoint 7 activation"

  $ enable_ap 7
  WiFi.AccessPoint.7 enabled

  $ check_ap_ref_ssid 7 Up
  WiFi.AccessPoint.7 SSID Reference is Up

  $ sleep 10

Test activation of access point 8:

  $ R logger -t cram "Test AccessPoint 8 activation"

  $ enable_ap 8
  WiFi.AccessPoint.8 enabled

  $ check_ap_ref_ssid 8 Up
  WiFi.AccessPoint.8 SSID Reference is Up

  $ sleep 10

Test activation of access point 9:

  $ R logger -t cram "Test AccessPoint 9 activation"

  $ enable_ap 9
  WiFi.AccessPoint.9 enabled

  $ check_ap_ref_ssid 9 Up
  WiFi.AccessPoint.9 SSID Reference is Up

  $ sleep 10

Check that hostapd is operating as expected:

  $ R logger -t cram "Check that hostapd is operating"

  $ R "ps axw" | sed -nE 's/.*(hostapd .*)/\1/p' | head -1 | tr -s ' ' '\n' | LC_ALL=C sort
  -g
  -s
  /tmp/wlan2_hapd.conf
  /var/run/hostapd/global\.0x.* (re)
  hostapd

Test custom arguments:

  $ R "ba-cli 'Device.WiFi.EndPoint.*.Enable=1' | sed '1d' | awk 'NF'"
  Device.WiFi.EndPoint.1.
  Device.WiFi.EndPoint.1.Enable=1
  Device.WiFi.EndPoint.2.
  Device.WiFi.EndPoint.2.Enable=1
  Device.WiFi.EndPoint.3.
  Device.WiFi.EndPoint.3.Enable=1

  $ R "ba-cli -j -l 'protected; WiFi.DaemonMgt.Daemon.hostapd.ExecutionSettings.CustomArguments=-dds' | grep CustomArguments"
  [{"WiFi.DaemonMgt.Daemon.1.ExecutionSettings.":{"CustomArguments":"-dds"}}]

  $ R "ba-cli -j -l 'protected; WiFi.DaemonMgt.Daemon.hostapd.ExecutionSettings.CustomArguments?' | grep CustomArguments"
  [{"WiFi.DaemonMgt.Daemon.1.ExecutionSettings.":{"CustomArguments":"-dds"}}]

  $ R "ba-cli -j -l 'protected; WiFi.DaemonMgt.Daemon.wpa_supplicant.ExecutionSettings.CustomArguments=-ds' | grep CustomArguments"
  [{"WiFi.DaemonMgt.Daemon.2.ExecutionSettings.":{"CustomArguments":"-ds"}}]

  $ R "ba-cli -j -l 'protected; WiFi.DaemonMgt.Daemon.wpa_supplicant.ExecutionSettings.CustomArguments?' | grep CustomArguments"
  [{"WiFi.DaemonMgt.Daemon.2.ExecutionSettings.":{"CustomArguments":"-ds"}}]

  $ sleep 10

  $ R logger -t cram "Check that hostapd is operating with new custom argument"

  $ R "ps axw" | sed -nE 's/.*(hostapd .*)/\1/p' | head -1 | tr -s ' ' '\n' | LC_ALL=C sort
  -dds
  -g
  /tmp/wlan0_hapd.conf
  /tmp/wlan1_hapd.conf
  /tmp/wlan2_hapd.conf
  /var/run/hostapd/global\.0x.* (re)
  hostapd

  $ R logger -t cram "Check that wpa_supplicant is operating with new custom argument"

  $ R "ps axw" | sed -n '/[w]pa_supplicant/ { s/^.*\bwpa_supplicant[[:space:]]/wpa_supplicant /; p }' | sort | head -3
  wpa_supplicant -ds -i wlan0 -Dnl80211 -c /tmp/wlan0_wpa_supplicant.conf
  wpa_supplicant -ds -i wlan1 -Dnl80211 -c /tmp/wlan1_wpa_supplicant.conf
  wpa_supplicant -ds -i wlan2 -Dnl80211 -c /tmp/wlan2_wpa_supplicant.conf

Setting the custom arguments back to default value:

  $ R "ba-cli -j -l 'protected; WiFi.DaemonMgt.Daemon.hostapd.ExecutionSettings.CustomArguments="-s"' | grep CustomArguments"
  [{"WiFi.DaemonMgt.Daemon.1.ExecutionSettings.":{"CustomArguments":"-s"}}]

  $ R "ba-cli -j -l 'protected; WiFi.DaemonMgt.Daemon.hostapd.ExecutionSettings.CustomArguments?' | grep CustomArguments"
  [{"WiFi.DaemonMgt.Daemon.1.ExecutionSettings.":{"CustomArguments":"-s"}}]

  $ R "ba-cli -j -l 'protected; WiFi.DaemonMgt.Daemon.wpa_supplicant.ExecutionSettings.CustomArguments="-s"' | grep CustomArguments"
  [{"WiFi.DaemonMgt.Daemon.2.ExecutionSettings.":{"CustomArguments":"-s"}}]

  $ R "ba-cli -j -l 'protected; WiFi.DaemonMgt.Daemon.wpa_supplicant.ExecutionSettings.CustomArguments?' | grep CustomArguments"
  [{"WiFi.DaemonMgt.Daemon.2.ExecutionSettings.":{"CustomArguments":"-s"}}]

  $ sleep 10

  $ R logger -t cram "Check that hostapd and wpa_supplicant are operating with default custom argument"

  $ R "ps axw" | sed -nE 's/.*(hostapd .*)/\1/p' | head -1 | tr -s ' ' '\n' | LC_ALL=C sort
  -g
  -s
  /tmp/wlan0_hapd.conf
  /tmp/wlan1_hapd.conf
  /tmp/wlan2_hapd.conf
  /var/run/hostapd/global\.0x.* (re)
  hostapd

  $ R "ps axw" | sed -n '/[w]pa_supplicant/ { s/^.*\bwpa_supplicant[[:space:]]/wpa_supplicant /; p }' | sort | head -3
  wpa_supplicant -s -i wlan0 -Dnl80211 -c /tmp/wlan0_wpa_supplicant.conf
  wpa_supplicant -s -i wlan1 -Dnl80211 -c /tmp/wlan1_wpa_supplicant.conf
  wpa_supplicant -s -i wlan2 -Dnl80211 -c /tmp/wlan2_wpa_supplicant.conf

  $ R "ba-cli 'Device.WiFi.EndPoint.*.Enable=0' | sed '1d' | awk 'NF'"
  Device.WiFi.EndPoint.1.
  Device.WiFi.EndPoint.1.Enable=0
  Device.WiFi.EndPoint.2.
  Device.WiFi.EndPoint.2.Enable=0
  Device.WiFi.EndPoint.3.
  Device.WiFi.EndPoint.3.Enable=0

Test deactivation of access point 9:

  $ R logger -t cram "Test AccessPoint 9 deactivation"

  $ disable_ap 9
  WiFi.AccessPoint.9 disabled

  $ check_ap_ref_ssid 9 Down
  WiFi.AccessPoint.9 SSID Reference is Down

  $ sleep 10

Test deactivation of access point 8:

  $ R logger -t cram "Test AccessPoint 8 deactivation"

  $ disable_ap 8
  WiFi.AccessPoint.8 disabled

  $ check_ap_ref_ssid 8 Down
  WiFi.AccessPoint.8 SSID Reference is Down

  $ sleep 10

Test deactivation of access point 7:

  $ R logger -t cram "Test AccessPoint 7 deactivation"

  $ disable_ap 7
  WiFi.AccessPoint.7 disabled

  $ check_ap_ref_ssid 7 Down
  WiFi.AccessPoint.7 SSID Reference is Down

  $ sleep 10

Test deactivation of access point 6:

  $ R logger -t cram "Test AccessPoint 6 deactivation"

  $ disable_ap 6
  WiFi.AccessPoint.6 disabled

  $ check_ap_ref_ssid 6 Down
  WiFi.AccessPoint.6 SSID Reference is Down

  $ sleep 10

Test deactivation of access point 5:

  $ R logger -t cram "Test AccessPoint 5 deactivation"

  $ disable_ap 5
  WiFi.AccessPoint.5 disabled

  $ check_ap_ref_ssid 5 Down
  WiFi.AccessPoint.5 SSID Reference is Down

  $ sleep 10

Test deactivation of access point 4:

  $ R logger -t cram "Test AccessPoint 4 deactivation"

  $ disable_ap 4
  WiFi.AccessPoint.4 disabled

  $ check_ap_ref_ssid 4 Down
  WiFi.AccessPoint.4 SSID Reference is Down

  $ sleep 10

Test deactivation of access point 3:

  $ R logger -t cram "Test AccessPoint 3 deactivation"

  $ disable_ap 3
  WiFi.AccessPoint.3 disabled

  $ check_ap_ref_ssid 3 Down
  WiFi.AccessPoint.3 SSID Reference is Down

  $ sleep 10

Test deactivation of access point 2:

  $ R logger -t cram "Test AccessPoint 2 deactivation"

  $ disable_ap 2
  WiFi.AccessPoint.2 disabled

  $ check_ap_ref_ssid 2 Down
  WiFi.AccessPoint.2 SSID Reference is Down

  $ sleep 10

Test deactivation of access point 1:

  $ R logger -t cram "Test AccessPoint 1 deactivation"

  $ disable_ap 1
  WiFi.AccessPoint.1 disabled

  $ check_ap_ref_ssid 1 Down
  WiFi.AccessPoint.1 SSID Reference is Down

  $ sleep 10

Check if hostapd process is stopped:

  $ R "pgrep -f 'hostapd'"
  [1]

  $ sleep 10

Check if wpa_supplicant process is stopped:

  $ R "pgrep -f 'wpa_supplicant'"
  [1]

Resume prplMesh:

  $ R "/etc/init.d/prplmesh start 2>&1 > /dev/null"

  $ R logger -t cram "Stopping PWHM test for custom arguments.."

Wait 20s before leaving the test:

  $ sleep 20

  $ R logger -t cram "Test finished!"

