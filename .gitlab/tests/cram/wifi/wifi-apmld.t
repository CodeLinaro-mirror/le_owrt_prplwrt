Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting APMLD test ..."

Stop prplMesh:

  $ R logger -t cram "Stop prplmesh"

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=0" | tr -d '\n'
  0 (no-eol)

  $ sleep 2

Check default configuration:

  $ R logger -t cram "Check default configuration"
  $ wifi_dm "APMLDMaxLinks?"
  WiFi.APMLDMaxLinks=\d+ (re)

  $ R logger -t cram "Check default configuration"
  $ wifi_dm "MaxNumMLDs?"
  WiFi.MaxNumMLDs=\d+ (re)

  $ wifi_dm "APMLD.?" | LC_ALL=C sort
  WiFi.APMLD.1.APMLDConfig.EMLMREnabled=0
  WiFi.APMLD.1.APMLDConfig.EMLSREnabled=1
  WiFi.APMLD.1.APMLDConfig.NSTREnabled=1
  WiFi.APMLD.1.APMLDConfig.STREnabled=1
  WiFi.APMLD.1.AffiliatedAPNumberOfEntries=0
  WiFi.APMLD.1.MLDID=0
  WiFi.APMLD.1.MLDMACAddress=""
  WiFi.APMLD.2.APMLDConfig.EMLMREnabled=0
  WiFi.APMLD.2.APMLDConfig.EMLSREnabled=1
  WiFi.APMLD.2.APMLDConfig.NSTREnabled=1
  WiFi.APMLD.2.APMLDConfig.STREnabled=1
  WiFi.APMLD.2.AffiliatedAPNumberOfEntries=0
  WiFi.APMLD.2.MLDID=1
  WiFi.APMLD.2.MLDMACAddress=""
  WiFi.APMLD.3.APMLDConfig.EMLMREnabled=0
  WiFi.APMLD.3.APMLDConfig.EMLSREnabled=1
  WiFi.APMLD.3.APMLDConfig.NSTREnabled=1
  WiFi.APMLD.3.APMLDConfig.STREnabled=1
  WiFi.APMLD.3.AffiliatedAPNumberOfEntries=0
  WiFi.APMLD.3.MLDID=2
  WiFi.APMLD.3.MLDMACAddress=""

Configure radio and enable all AccessPoints:

  $ R logger -t cram "Enable all vaps"

  $ wifi_dm "Radio.*.AutoChannelEnable=0"
  WiFi.Radio.1.AutoChannelEnable=0
  WiFi.Radio.2.AutoChannelEnable=0
  WiFi.Radio.3.AutoChannelEnable=0

  $ wifi_dm "Radio.[OperatingFrequencyBand==\"2.4GHz\"].Channel=1"
  WiFi.Radio.\d+.Channel=1 (re)

  $ wifi_dm "Radio.[OperatingFrequencyBand==\"5GHz\"].Channel=36"
  WiFi.Radio.\d+.Channel=36 (re)

  $ wifi_dm "Radio.[OperatingFrequencyBand==\"6GHz\"].Channel=37"
  WiFi.Radio.\d+.Channel=37 (re)

  $ wifi_dm "AccessPoint.*.Enable=1"
  WiFi.AccessPoint.1.Enable=1
  WiFi.AccessPoint.2.Enable=1
  WiFi.AccessPoint.3.Enable=1
  WiFi.AccessPoint.4.Enable=1
  WiFi.AccessPoint.5.Enable=1
  WiFi.AccessPoint.6.Enable=1
  WiFi.AccessPoint.7.Enable=1
  WiFi.AccessPoint.8.Enable=1
  WiFi.AccessPoint.9.Enable=1

  $ sleep 10

Check AccessPoints status:

  $ wifi_dm "AccessPoint.*.Status?0"
  WiFi.AccessPoint.1.Status="Enabled"
  WiFi.AccessPoint.2.Status="Enabled"
  WiFi.AccessPoint.3.Status="Enabled"
  WiFi.AccessPoint.4.Status="Enabled"
  WiFi.AccessPoint.5.Status="Enabled"
  WiFi.AccessPoint.6.Status="Enabled"
  WiFi.AccessPoint.7.Status="Enabled"
  WiFi.AccessPoint.8.Status="Enabled"
  WiFi.AccessPoint.9.Status="Enabled"

Save hostap pid:

  $ hostap_pid=$(R pgrep -f 'hostapd')
  $ R logger -t cram "hostap PID : $hostap_pid"

Read private and guest MLDUnit:

  $ private_mldunit=$(get_private_mldunit)
  $ guest_mldunit=$(get_guest_mldunit)
  $ test_mldunit=12

Check private APMLD number of links:

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

Check APMLD 2 number (guest vaps) of links:

  $ iw_affliated_link_info_from_mldid ${guest_mldunit}
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  channel 1 .* (re)
  channel 36 .* (re)
  channel 37 .* (re)
  link 0
  link 1
  link 2

Read all link IDs (3 links per MLD):
(LinkID values do not matter, uniqueness will be checked implicitly later)

  $ wifi_dm "APMLD.*.AffiliatedAP.*.LinkID?"
  WiFi.APMLD.1.AffiliatedAP.1.LinkID=\d+ (re)
  WiFi.APMLD.1.AffiliatedAP.2.LinkID=\d+ (re)
  WiFi.APMLD.1.AffiliatedAP.3.LinkID=\d+ (re)
  WiFi.APMLD.2.AffiliatedAP.1.LinkID=\d+ (re)
  WiFi.APMLD.2.AffiliatedAP.2.LinkID=\d+ (re)
  WiFi.APMLD.2.AffiliatedAP.3.LinkID=\d+ (re)
  WiFi.APMLD.3.AffiliatedAP.1.LinkID=\d+ (re)
  WiFi.APMLD.3.AffiliatedAP.2.LinkID=\d+ (re)
  WiFi.APMLD.3.AffiliatedAP.3.LinkID=\d+ (re)

Read AffiliatedAP MAC addresses from iw (private):

  $ iw_affilated_mac_list=$(iw_affilated_mac_list_from_mldid ${private_mldunit})
  $ echo "$iw_affilated_mac_list"
  link \d+ addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  link \d+ addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  link \d+ addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)

Read AffiliatedAP MAC addresses from pwhm (private):

  $ dm_affilated_mac_list=$(dm_affilated_mac_list_from_mldid ${private_mldunit})
  $ echo "$dm_affilated_mac_list"
  link \d+ addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  link \d+ addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  link \d+ addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)

Cross check Affilated MACs addresses (private):

  $ merged_list=$(printf "%s\n%s\n" "$dm_affilated_mac_list" "$iw_affilated_mac_list" | tr '[:upper:]' '[:lower:]' | sort -u)

  $ echo "$merged_list" | uniq
  link \d+ addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  link \d+ addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  link \d+ addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)

Read AffiliatedAP MAC addresses from iw (guest):

  $ iw_affilated_mac_list=$(iw_affilated_mac_list_from_mldid ${guest_mldunit})
  $ echo "$iw_affilated_mac_list"
  link \d+ addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  link \d+ addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  link \d+ addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)

Read AffiliatedAP MAC addresses from pwhm (guest):

  $ dm_affilated_mac_list=$(dm_affilated_mac_list_from_mldid ${guest_mldunit})
  $ echo "$dm_affilated_mac_list"
  link \d+ addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  link \d+ addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  link \d+ addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)

Cross check Affilated MACs addresses (guest):

  $ merged_list=$(printf "%s\n%s\n" "$dm_affilated_mac_list" "$iw_affilated_mac_list" | tr '[:upper:]' '[:lower:]' | sort -u)

  $ echo "$merged_list" | uniq
  link \d+ addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  link \d+ addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  link \d+ addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)

Check wpacltrl socket file: default status

  $ ls_hapd_sockets
  wlan2.1
  wlan2.1_link0
  wlan2.1_link1
  wlan2.1_link2
  wlan2.2
  wlan2.2_link0
  wlan2.2_link1
  wlan2.2_link2
  wlan2.3
  wlan2.3_link0
  wlan2.3_link1
  wlan2.3_link2

#########################################
#  Unset MLDUnit of one priv SSID       #
#########################################

Remove AP1 (private) from its APMLD:

  $ R logger -t cram "Remove AP1 from its APMLD"
  $ wifi_dm "AccessPoint.1.SSIDReference+.MLDUnit=-1"
  Device.WiFi.SSID.\d+.MLDUnit=-1 (re)

  $ sleep 10

Check private APMLD number of links:

  $ iw_affliated_link_info_from_mldid ${private_mldunit}
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  channel 36 .* (re)
  channel 37 .* (re)
  link 0
  link 1

Read AffiliatedAP MAC addresses:

  $ iw_affilated_mac_list_from_mldid ${private_mldunit}
  link \d+ addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  link \d+ addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)

Check link id of private MLD:

  $ wifi_dm "APMLD.[ MLDID == ${private_mldunit} ].AffiliatedAP.*.LinkID?"
  WiFi.APMLD.1.AffiliatedAP.1.LinkID=0
  WiFi.APMLD.1.AffiliatedAP.2.LinkID=1

Check wpacltrl socket file: update of main link interface
AP1 (wlan2.1) was the primary link, private MLD should have now another main
link interface with 2 links and AP1 interface should appear with no link (ie MLDUnit=-1)

  $ ls_hapd_sockets
  wlan1.1
  wlan1.1_link0
  wlan1.1_link1
  wlan2.1
  wlan2.2
  wlan2.2_link0
  wlan2.2_link1
  wlan2.2_link2
  wlan2.3
  wlan2.3_link0
  wlan2.3_link1
  wlan2.3_link2

#########################################
# Restore MLDUnit                       #
#########################################

Move back AP1 to its previous APMLD:

  $ R logger -t cram "Move back AP1 to its previous APMLD"
  $ wifi_dm "AccessPoint.1.SSIDReference+.MLDUnit=${private_mldunit}"
  Device.WiFi.SSID.\d+.MLDUnit=0 (re)

  $ sleep 10

Check private APMLD number of links:

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

Check wpacltrl socket file: AP1 (wlan2.1) turns back to previous MLD,
main link interface (wlan1.1) shouldn't change. private MLD should
have again 3 links

  $ ls_hapd_sockets
  wlan1.1
  wlan1.1_link0
  wlan1.1_link1
  wlan1.1_link2
  wlan2.2
  wlan2.2_link0
  wlan2.2_link1
  wlan2.2_link2
  wlan2.3
  wlan2.3_link0
  wlan2.3_link1
  wlan2.3_link2

#########################################
# Set a distinct MLDUnit                #
#########################################

Move AP1 to a new APMLD:

  $ R logger -t cram "Move AP1 to a new APMLD"
  $ wifi_dm "AccessPoint.1.SSIDReference+.MLDUnit=${test_mldunit}"
  Device.WiFi.SSID.1.MLDUnit=12

  $ sleep 10

Check private APMLD number of links:

  $ iw_affliated_link_info_from_mldid ${private_mldunit}
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  channel 36 .* (re)
  channel 37 .* (re)
  link 0
  link 1

Check the new APMLD 3 number of links:

  $ iw_affliated_link_info_from_mldid ${test_mldunit}
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  channel 1 .* (re)
  link 0

Read AffiliatedAP MAC addresses:

  $ iw_affilated_mac_list_from_mldid ${private_mldunit}
  link \d+ addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  link \d+ addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)

  $ iw_affilated_mac_list_from_mldid ${test_mldunit}
  link \d+ addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)

Check wpacltrl socket file: AP1 interface (wlan2.1) should appear as
main link interface with one link

  $ ls_hapd_sockets
  wlan1.1
  wlan1.1_link0
  wlan1.1_link1
  wlan2.1
  wlan2.1_link0
  wlan2.2
  wlan2.2_link0
  wlan2.2_link1
  wlan2.2_link2
  wlan2.3
  wlan2.3_link0
  wlan2.3_link1
  wlan2.3_link2

#########################################
# Restore MLDUnit                       #
#########################################

Move back AP1 to its APMLD:

  $ R logger -t cram "Move back AP1 to its previous APMLD"
  $ wifi_dm "AccessPoint.1.SSIDReference+.MLDUnit=${private_mldunit}"
  Device.WiFi.SSID.1.MLDUnit=0

  $ sleep 10

Check private APMLD number of links:

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

Check if new APMLD was cleared:

  $ get_apmld_mac_from_dm ${test_mldunit}
  not_found

#########################################
# Test Guest MLD deactivation           #
#########################################

Disable guest vaps:

  $ R logger -t cram "Disable guest vaps"
  $ wifi_dm "AccessPoint.[DefaultDeviceType==\"Guest\"].Enable=0"
  WiFi.AccessPoint.\d+.Enable=0 (re)
  WiFi.AccessPoint.\d+.Enable=0 (re)
  WiFi.AccessPoint.\d+.Enable=0 (re)

  $ sleep 10

  $ wifi_dm "AccessPoint.[DefaultDeviceType==\"Guest\"].Status?"
  WiFi.AccessPoint.\d+.Status="Disabled" (re)
  WiFi.AccessPoint.\d+.Status="Disabled" (re)
  WiFi.AccessPoint.\d+.Status="Disabled" (re)

Check if guest apmld is cleared:

  $ wifi_dm "APMLD.2.?"
  WiFi.APMLD.2.APMLDConfig.EMLMREnabled=0
  WiFi.APMLD.2.APMLDConfig.EMLSREnabled=1
  WiFi.APMLD.2.APMLDConfig.NSTREnabled=1
  WiFi.APMLD.2.APMLDConfig.STREnabled=1
  WiFi.APMLD.2.AffiliatedAPNumberOfEntries=0
  WiFi.APMLD.2.MLDID=1
  WiFi.APMLD.2.MLDMACAddress=""


#########################################
# Terminate test                       #
#########################################

Before deactivating all vaps, check if hostap pid has changed or not:

  $ if [ "$(R pgrep -f 'hostapd')" = "$hostap_pid" ]; then echo "true"; else echo "hostap restarted during the test !"; fi
  true

Disable all vaps:

  $ R logger -t cram "Disable all vaps"
  $ wifi_dm "AccessPoint.*.Enable=0"
  WiFi.AccessPoint.1.Enable=0
  WiFi.AccessPoint.2.Enable=0
  WiFi.AccessPoint.3.Enable=0
  WiFi.AccessPoint.4.Enable=0
  WiFi.AccessPoint.5.Enable=0
  WiFi.AccessPoint.6.Enable=0
  WiFi.AccessPoint.7.Enable=0
  WiFi.AccessPoint.8.Enable=0
  WiFi.AccessPoint.9.Enable=0

  $ sleep 10

Check AccessPoints status:

  $ wifi_dm "AccessPoint.*.Status?0"
  WiFi.AccessPoint.1.Status="Disabled"
  WiFi.AccessPoint.2.Status="Disabled"
  WiFi.AccessPoint.3.Status="Disabled"
  WiFi.AccessPoint.4.Status="Disabled"
  WiFi.AccessPoint.5.Status="Disabled"
  WiFi.AccessPoint.6.Status="Disabled"
  WiFi.AccessPoint.7.Status="Disabled"
  WiFi.AccessPoint.8.Status="Disabled"
  WiFi.AccessPoint.9.Status="Disabled"

Check if private apmld is cleared:

  $ sleep 10

  $ wifi_dm "APMLD.1.?"
  WiFi.APMLD.1.APMLDConfig.EMLMREnabled=0
  WiFi.APMLD.1.APMLDConfig.EMLSREnabled=1
  WiFi.APMLD.1.APMLDConfig.NSTREnabled=1
  WiFi.APMLD.1.APMLDConfig.STREnabled=1
  WiFi.APMLD.1.AffiliatedAPNumberOfEntries=0
  WiFi.APMLD.1.MLDID=0
  WiFi.APMLD.1.MLDMACAddress=""


Resume prplMesh:

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=1" | tr -d '\n'
  1 (no-eol)

  $ sleep 10
  $ R logger -t cram "Test finished!"
