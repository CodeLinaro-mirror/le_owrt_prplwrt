Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting $TESTFILE"

Save hostap pid:

  $ hostap_pid=$(R pgrep -f 'hostapd')
  $ R logger -t cram "hostap PID : $hostap_pid"

#######################################
# Test deactivation of access point 9 #
#######################################

  $ enable_ap_sync 9 0
  AccessPoint.9.Enable=0

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

#######################################
# Test deactivation of access point 8 #
#######################################

  $ R logger -t cram "Test AccessPoint 8 deactivation \"$(get_ssid_ref 8)\""

  $ enable_ap_sync 8 0
  AccessPoint.8.Enable=0

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

#######################################
# Test deactivation of access point 7 #
#######################################

  $ R logger -t cram "Test AccessPoint 7 deactivation \"$(get_ssid_ref 7)\""

  $ enable_ap_sync 7 0
  AccessPoint.7.Enable=0

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

#######################################
# Test deactivation of access point 6 #
#######################################

  $ enable_ap_sync 6 0
  AccessPoint.6.Enable=0

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

#######################################
# Test deactivation of access point 5 #
#######################################

  $ R logger -t cram "Test AccessPoint 5 deactivation \"$(get_ssid_ref 5)\""

  $ enable_ap_sync 5 0
  AccessPoint.5.Enable=0

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

#######################################
# Test deactivation of access point 4 #
#######################################

  $ R logger -t cram "Test AccessPoint 4 deactivation \"$(get_ssid_ref 4)\""

  $ enable_ap_sync 4 0
  AccessPoint.4.Enable=0

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

#######################################
# Test deactivation of access point 3 #
#######################################

  $ R logger -t cram "Test AccessPoint 3 deactivation \"$(get_ssid_ref 3)\""

  $ enable_ap_sync 3 0
  AccessPoint.3.Enable=0

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

#######################################
# Test deactivation of access point 2 #
#######################################

  $ enable_ap_sync 2 0
  AccessPoint.2.Enable=0

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

Before deactivating last AP (ie stopping hostpad), check if hostap pid has changed or not:

  $ if [ "$(R pgrep -f 'hostapd')" = "$hostap_pid" ]; then echo "true"; else echo "hostap restarted during the test !"; fi
  true


#######################################
# Test deactivation of access point 1 #
#######################################

  $ R logger -t cram "Test AccessPoint 1 deactivation \"$(get_ssid_ref 1)\""

  $ enable_ap_sync 1 0
  AccessPoint.1.Enable=0

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

Check if hostapd process is stopped:

  $ R "pgrep -f 'hostapd'"
  [1]

Restore defautlt MLDUnit values:

  $ set_default_ap_mldunit
  $ sleep 5

Resume prplMesh:

  $ prplmesh_start

  $ R logger -t cram "$TESTFILE finished!"
