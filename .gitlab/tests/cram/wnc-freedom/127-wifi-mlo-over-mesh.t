Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/prplmesh_ap_mld.sh"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ prplmesh_enable_mlo
  01/opt/prplmesh/bin/beerocks_agent
  /opt/prplmesh/bin/beerocks_controller
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan0
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan1
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan2
  /opt/prplmesh/bin/beerocks_vendor_message
  /opt/prplmesh/bin/ieee1905_transport
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

  $ sleep 10

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

Verify EHT Operation for each radio:
  $ get_eht_ops 2.4
  BasicEHT-MCSAndNssSet=1145324612
  CCFS0=1
  CCFS1=0
  ControlChannelWidth=0
  DisabledSubchannelBitmapPresent=0
  EHTDefaultPEDuration=0
  EHTOperationInformationPresent=1
  GroupAddressedBUIndicationExponent=0
  GroupAddressedBUIndicationLimit=0

  $ get_eht_ops 5
  BasicEHT-MCSAndNssSet=1145324612
  CCFS0=42
  CCFS1=0
  ControlChannelWidth=2
  DisabledSubchannelBitmapPresent=0
  EHTDefaultPEDuration=0
  EHTOperationInformationPresent=1
  GroupAddressedBUIndicationExponent=0
  GroupAddressedBUIndicationLimit=0

  $ get_eht_ops 6
  BasicEHT-MCSAndNssSet=1145324612
  CCFS0=47
  CCFS1=31
  ControlChannelWidth=4
  DisabledSubchannelBitmapPresent=0
  EHTDefaultPEDuration=0
  EHTOperationInformationPresent=1
  GroupAddressedBUIndicationExponent=0
  GroupAddressedBUIndicationLimit=0

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

  $ prplmesh_create_network_ap_mlo "prplOS-Guest" 8 "password" 2 guest
  1
  1
  1
  1
  1
  prplOS-Guest
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

  $ sleep 15
  $ verify_mldunit_by_ssid "prplOS-Guest"
  0
  0
  0

  $ R "ba-cli -l 'WiFi.SSID.[SSID==\"prplOS-Guest\"].MLDUnit?'" | sed '/^$/d'
  0
  0
  0

Restore defautlt MLDUnit and config values:

  $ prplmesh_revert_mlo_to_defaults
  [{"Device.WiFi.SSID.1.":{"MLDUnit":0}}]
  [{"Device.WiFi.SSID.3.":{"MLDUnit":1}}]
  [{"Device.WiFi.SSID.4.":{"MLDUnit":0}}]
  [{"Device.WiFi.SSID.6.":{"MLDUnit":1}}]
  [{"Device.WiFi.SSID.7.":{"MLDUnit":0}}]
  [{"Device.WiFi.SSID.9.":{"MLDUnit":1}}]
  [{"Device.WiFi.SSID.16.":{"MLDUnit":2}}]
  [{"Device.WiFi.SSID.17.":{"MLDUnit":2}}]
  [{"Device.WiFi.SSID.18.":{"MLDUnit":2}}]
  01/opt/prplmesh/bin/beerocks_agent
  /opt/prplmesh/bin/beerocks_controller
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan0
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan1
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan2
  /opt/prplmesh/bin/beerocks_vendor_message
  /opt/prplmesh/bin/ieee1905_transport
  MLO_DEFAULTS_RESTORED

Final log:

  $ R logger -t cram "MLO test Completed!"
