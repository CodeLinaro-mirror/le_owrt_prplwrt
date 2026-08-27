Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting $TESTFILE"

  $ check_wifi_defaults
  $ testbed_set_wifi_defaults

  $ prplmesh_stop

Disable MLO on private and guest vaps:

  $ R logger -t cram "Disable MLO for all interfaces"

  $ R "ba-cli -j -l Device.WiFi.SSID.*.MLDUnit=-1 | jsonfilter -e @[0]'[*].MLDUnit'"
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

#####################################
# Test activation of access point 1 #
#####################################

  $ R logger -t cram "Test AccessPoint 1 activation \"$(get_ssid_ref 1)\""

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

Save hostap pid:

  $ hostap_pid=$(R pgrep -f 'hostapd')
  $ R logger -t cram "hostap PID : $hostap_pid"

#####################################
# Test activation of access point 2 #
#####################################

  $ R logger -t cram "Test AccessPoint 2 activation \"$(get_ssid_ref 2)\""

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

#####################################
# Test activation of access point 3 #
#####################################

  $ R logger -t cram "Test AccessPoint 3 activation \"$(get_ssid_ref 3)\""

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

#####################################
# Test activation of access point 4 #
#####################################

  $ R logger -t cram "Test AccessPoint 4 activation \"$(get_ssid_ref 4)\""

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

#####################################
# Test activation of access point 5 #
#####################################

  $ R logger -t cram "Test AccessPoint 5 activation \"$(get_ssid_ref 5)\""

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

#####################################
# Test activation of access point 6 #
#####################################

  $ R logger -t cram "Test AccessPoint 6 activation \"$(get_ssid_ref 6)\""

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

#####################################
# Test activation of access point 7 #
#####################################

  $ R logger -t cram "Test AccessPoint 7 activation \"$(get_ssid_ref 7)\""

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

#####################################
# Test activation of access point 8 #
#####################################

  $ R logger -t cram "Test AccessPoint 8 activation \"$(get_ssid_ref 8)\""

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

#####################################
# Test activation of access point 9 #
#####################################

  $ R logger -t cram "Test AccessPoint 9 activation \"$(get_ssid_ref 9)\""

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

Check that hostapd is operating as expected:

  $ R logger -t cram "Check that hostapd is operating"

  $ R "ps axw" | sed -nE 's/.*(hostapd .*)/\1/p' | head -1 | tr -s ' ' '\n' | LC_ALL=C sort
  -g
  -s
  /tmp/wlan2_hapd.conf
  /var/run/hostapd/global\.0x.* (re)
  hostapd

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
  ssid backhaul_(AC:91:9B|58:E4:03|10:E8:A7):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  ssid backhaul_(AC:91:9B|58:E4:03|10:E8:A7):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  ssid backhaul_(AC:91:9B|58:E4:03|10:E8:A7):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  ssid prplOS
  ssid prplOS
  ssid prplOS
  ssid prplOS-guest
  ssid prplOS-guest
  ssid prplOS-guest

Check if hostap pid has changed or not:

  $ if [ "$(R pgrep -f 'hostapd')" = "$hostap_pid" ]; then echo "true"; else echo "hostap restarted during the test !"; fi
  true

  $ R logger -t cram "$TESTFILE finished!"
