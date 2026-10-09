Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/prplmesh_ap_mld.sh"

  $ R logger -t cram "Starting $TESTFILE"

  $ check_wifi_defaults
  $ testbed_set_wifi_defaults

  $ prplmesh_enable_mlo
  Active
  MLO_ENABLED

Create Network.AccessPoint.1, configure bands/SSID/security/MLDUnit, commit.

  $ prplmesh_create_network_ap_mlo
  1
  1
  1
  1
  1
  prplOS
  WPA3-Personal
  password
  password
  Fronthaul
  home
  7
  OPERATIONAL (15)
  X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit() returned
  [
      ""
  ]
  AP_COMMIT_OK

  $ sleep 20

Verify MLDUnit Set by Agent in 2.4GHz, 5GHz and 6GHz:

  $ R logger -t cram "Verifying MLDUnit values in Data Model..."
  $ R "ba-cli -l 'WiFi.SSID.[SSID==\"prplOS\"].MLDUnit?'" | sed '/^$/d'
  0
  0
  0

Check the MLO group in iw dev:

  $ R logger -t cram " To check interface status"
  $ private_mldunit=$(get_private_mldunit)
  $ iw_affliated_link_info_from_mldid ${private_mldunit}
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  channel 1 .* (re)
  channel 36 .* (re)
  channel 37 .* (re)
  link 0
  link 1
  link 2

  $ wifi_apmld=$(get_wifi_apmld_normalized)
  $ de_apmld=$(get_dataelements_apmld_normalized 2)

  $ [ "$wifi_apmld" = "$de_apmld" ] && echo OK || { echo MISMATCH; echo '--- WiFi.APMLD'; echo "$wifi_apmld"; echo '--- DataElements'; echo "$de_apmld"; }
  OK

Remove one FH link from the MLD group:

  $ prplmesh_restore_one_fh_link_to_mld_group 7 -1 | sed '/^$/d'
  [{"WiFi.SSID.7.":{"MLDUnit":-1}}]

  $ sleep 10
  $ verify_mldunit_by_ssid "prplOS"
  0
  0
  -1

Restore the FH link back into the MLD group:

  $ prplmesh_restore_one_fh_link_to_mld_group 7 0 | sed '/^$/d'
  [{"WiFi.SSID.7.":{"MLDUnit":0}}]

  $ sleep 10
  $ verify_mldunit_by_ssid "prplOS"
  0
  0
  0

  $ sleep 15
  $ R "ba-cli -l 'WiFi.SSID.[SSID==\"prplOS\"].MLDUnit?'" | sed '/^$/d'
  0
  0
  0

Second MLO group (Guest):

  $ prplmesh_create_network_ap_mlo "prplOS-guest" 8 "password" 2 guest
  1
  1
  1
  1
  1
  prplOS-guest
  WPA3-Personal
  password
  password
  Fronthaul
  guest
  8
  OPERATIONAL (15)
  X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit() returned
  [
      ""
  ]
  AP_COMMIT_OK

  $ sleep 20
  $ verify_mldunit_by_ssid "prplOS-guest"
  0
  0
  0

  $ R "ba-cli -l 'WiFi.SSID.[SSID==\"prplOS-guest\"].MLDUnit?'" | sed '/^$/d'
  0
  0
  0

Restore defautlt MLDUnit and config values:

  $ prplmesh_revert_mlo_to_defaults
  Device.WiFi.AccessPoint.1.Enable=0
  Device.WiFi.AccessPoint.2.Enable=0
  Device.WiFi.AccessPoint.3.Enable=0
  Device.WiFi.AccessPoint.4.Enable=0
  Device.WiFi.AccessPoint.5.Enable=0
  Device.WiFi.AccessPoint.6.Enable=0
  Device.WiFi.AccessPoint.7.Enable=0
  Device.WiFi.AccessPoint.8.Enable=0
  Device.WiFi.AccessPoint.9.Enable=0
  Active
  MLO_DEFAULTS_RESTORED

Final log:

  $ R logger -t cram "$TESTFILE finished!"
