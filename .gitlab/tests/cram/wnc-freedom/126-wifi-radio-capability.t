WiFi.Radio.*.Capabilities same as DataElements Device.1.Radio.*.Capabilities

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/prplmesh_ap_mld.sh"

Check Controller, Agent,FrontHaul process are Running:

  $ prplmesh_enable_mlo
  01/opt/prplmesh/bin/beerocks_agent
  /opt/prplmesh/bin/beerocks_controller
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan0
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan1
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan2
  /opt/prplmesh/bin/beerocks_vendor_message
  /opt/prplmesh/bin/ieee1905_transport
  MLO_ENABLED

#########################################
#         WiFi.Radio.1                  #
#########################################

Get WiFi.Radio.1 capabilities (AP + STA), keep only *Support=, normalize and sort:

  $ wifi_out=$(R "ba-cli 'WiFi.Radio.1.Capabilities.WiFi7APRole.?' ; ba-cli 'WiFi.Radio.1.Capabilities.WiFi7STARole.?'" | grep -E 'Support=' | sed 's/.*\.\(EMLMRSupport\|EMLSRSupport\|NSTRSupport\|STRSupport\)=/\1=/' | sort)

  $ R "ba-cli 'WiFi.Radio.1.Capabilities.WiFi7APRole.?' ; ba-cli 'WiFi.Radio.1.Capabilities.WiFi7STARole.?'" | grep -E 'Support=' | sed 's/.*\.\(EMLMRSupport\|EMLSRSupport\|NSTRSupport\|STRSupport\)=/\1=/' | sort
  EMLMRSupport=0
  EMLMRSupport=0
  EMLSRSupport=1
  EMLSRSupport=1
  NSTRSupport=0
  NSTRSupport=1
  STRSupport=0
  STRSupport=1
 
Get DataElements Device.1.Radio.1 capabilities (AP + bSTA), same normalization:

  $ de_out=$(R "ba-cli 'Device.WiFi.DataElements.Network.Device.1.Radio.1.Capabilities.WiFi7APRole.?' ; ba-cli 'Device.WiFi.DataElements.Network.Device.1.Radio.1.Capabilities.WiFi7bSTARole.?'" | grep -E 'Support=' | sed 's/.*\.\(EMLMRSupport\|EMLSRSupport\|NSTRSupport\|STRSupport\)=/\1=/' | sort)

  $ R "ba-cli 'Device.WiFi.DataElements.Network.Device.1.Radio.1.Capabilities.WiFi7APRole.?' ; ba-cli 'Device.WiFi.DataElements.Network.Device.1.Radio.1.Capabilities.WiFi7bSTARole.?'" | grep -E 'Support=' | sed 's/.*\.\(EMLMRSupport\|EMLSRSupport\|NSTRSupport\|STRSupport\)=/\1=/' | sort
  EMLMRSupport=0
  EMLMRSupport=0
  EMLSRSupport=1
  EMLSRSupport=1
  NSTRSupport=0
  NSTRSupport=1
  STRSupport=0
  STRSupport=1

Compare: same values => OK, else MISMATCH and show both:

  $ [ "$wifi_out" = "$de_out" ] && echo OK || { echo MISMATCH; echo '--- WiFi.Radio.1'; echo "$wifi_out"; echo '--- DataElements'; echo "$de_out"; }
  OK

#########################################
#         WiFi.Radio.2                  #
#########################################

Get WiFi.Radio.2 capabilities (AP + STA), keep only *Support=, normalize and sort:

  $ wifi_out=$(R "ba-cli 'WiFi.Radio.2.Capabilities.WiFi7APRole.?' ; ba-cli 'WiFi.Radio.2.Capabilities.WiFi7STARole.?'" | grep -E 'Support=' | sed 's/.*\.\(EMLMRSupport\|EMLSRSupport\|NSTRSupport\|STRSupport\)=/\1=/' | sort)

Get DataElements Device.1.Radio.2 capabilities (AP + bSTA), same normalization:

  $ de_out=$(R "ba-cli 'Device.WiFi.DataElements.Network.Device.1.Radio.2.Capabilities.WiFi7APRole.?' ; ba-cli 'Device.WiFi.DataElements.Network.Device.1.Radio.2.Capabilities.WiFi7bSTARole.?'" | grep -E 'Support=' | sed 's/.*\.\(EMLMRSupport\|EMLSRSupport\|NSTRSupport\|STRSupport\)=/\1=/' | sort)

Compare: same values => OK, else MISMATCH and show both:

  $ [ "$wifi_out" = "$de_out" ] && echo OK || { echo MISMATCH; echo '--- WiFi.Radio.2'; echo "$wifi_out"; echo '--- DataElements'; echo "$de_out"; }
  OK

#########################################
#         WiFi.Radio.3                  #
#########################################

Get WiFi.Radio.3 capabilities (AP + STA), keep only *Support=, normalize and sort:

  $ wifi_out=$(R "ba-cli 'WiFi.Radio.3.Capabilities.WiFi7APRole.?' ; ba-cli 'WiFi.Radio.3.Capabilities.WiFi7STARole.?'" | grep -E 'Support=' | sed 's/.*\.\(EMLMRSupport\|EMLSRSupport\|NSTRSupport\|STRSupport\)=/\1=/' | sort)

Get DataElements Device.1.Radio.3 capabilities (AP + bSTA), same normalization:

  $ de_out=$(R "ba-cli 'Device.WiFi.DataElements.Network.Device.1.Radio.3.Capabilities.WiFi7APRole.?' ; ba-cli 'Device.WiFi.DataElements.Network.Device.1.Radio.3.Capabilities.WiFi7bSTARole.?'" | grep -E 'Support=' | sed 's/.*\.\(EMLMRSupport\|EMLSRSupport\|NSTRSupport\|STRSupport\)=/\1=/' | sort)

Compare: same values => OK, else MISMATCH and show both:

  $ [ "$wifi_out" = "$de_out" ] && echo OK || { echo MISMATCH; echo '--- WiFi.Radio.3'; echo "$wifi_out"; echo '--- DataElements'; echo "$de_out"; }
  OK

########################################
#    Verify the MaxMLDLink             #
########################################

Get WiFi device-level MLD params (normalize to Param=value, sort):

  $ R "ba-cli 'WiFi.MaxNumMLDs?' ; ba-cli 'WiFi.bSTAMLDMaxLinks?' ; ba-cli 'WiFi.APMLDMaxLinks?'" 2>&1 | grep -E 'MaxNumMLDs=|bSTAMLDMaxLinks=|APMLDMaxLinks=' | sed 's/.*\.\(MaxNumMLDs\|bSTAMLDMaxLinks\|APMLDMaxLinks\)=/\1=/' | sort
  APMLDMaxLinks=5
  MaxNumMLDs=19
  bSTAMLDMaxLinks=3

  $ wifi_mld=$(R "ba-cli -l 'Device.WiFi.MaxNumMLDs?' ; ba-cli -l 'Device.WiFi.bSTAMLDMaxLinks?' ; ba-cli -l 'Device.WiFi.APMLDMaxLinks?'" | grep -E 'MaxNumMLDs=|bSTAMLDMaxLinks=|APMLDMaxLinks=' | sed 's/.*\.\(MaxNumMLDs\|bSTAMLDMaxLinks\|APMLDMaxLinks\)=/\1=/' | sort)

Get DataElements Device.1 same params, same normalization:

  $ de_mld=$(R "ba-cli -l 'Device.WiFi.DataElements.Network.Device.1.MaxNumMLDs?' ; ba-cli -l 'Device.WiFi.DataElements.Network.Device.1.bSTAMLDMaxLinks?' ; ba-cli -l 'Device.WiFi.DataElements.Network.Device.1.APMLDMaxLinks?'" | grep -E 'MaxNumMLDs=|bSTAMLDMaxLinks=|APMLDMaxLinks=' | sed 's/.*\.\(MaxNumMLDs\|bSTAMLDMaxLinks\|APMLDMaxLinks\)=/\1=/' | sort)

  $ R "ba-cli 'Device.WiFi.DataElements.Network.Device.1.MaxNumMLDs?' ; ba-cli 'Device.WiFi.DataElements.Network.Device.1.bSTAMLDMaxLinks?' ; ba-cli 'Device.WiFi.DataElements.Network.Device.1.APMLDMaxLinks?'" | grep -E 'MaxNumMLDs=|bSTAMLDMaxLinks=|APMLDMaxLinks=' | sed 's/.*\.\(MaxNumMLDs\|bSTAMLDMaxLinks\|APMLDMaxLinks\)=/\1=/' | sort
  APMLDMaxLinks=5
  MaxNumMLDs=19
  bSTAMLDMaxLinks=3

Compare: same => OK, else MISMATCH and show both:

  $ [ "$wifi_mld" = "$de_mld" ] && echo OK || { echo MISMATCH; echo '--- WiFi'; echo "$wifi_mld"; echo '--- DataElements'; echo "$de_mld"; }
  OK

  $ prplmesh_revert_mlo_to_defaults
  [{"Device.WiFi.SSID.1.":{"MLDUnit":-1}}]
  [{"Device.WiFi.SSID.3.":{"MLDUnit":1}}]
  [{"Device.WiFi.SSID.4.":{"MLDUnit":-1}}]
  [{"Device.WiFi.SSID.6.":{"MLDUnit":1}}]
  [{"Device.WiFi.SSID.7.":{"MLDUnit":-1}}]
  [{"Device.WiFi.SSID.9.":{"MLDUnit":1}}]
  [{"Device.WiFi.SSID.16.":{"MLDUnit":0}}]
  [{"Device.WiFi.SSID.17.":{"MLDUnit":1}}]
  [{"Device.WiFi.SSID.18.":{"MLDUnit":0}}]
  01/opt/prplmesh/bin/beerocks_agent
  /opt/prplmesh/bin/beerocks_controller
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan0
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan1
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan2
  /opt/prplmesh/bin/beerocks_vendor_message
  /opt/prplmesh/bin/ieee1905_transport
  MLO_DEFAULTS_RESTORED

Final log:

  $ R logger -t cram "Radio Capability Test Completed!"
