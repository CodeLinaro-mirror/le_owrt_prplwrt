Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting APMLD test ..."

Stop prplMesh:

  $ R "/etc/init.d/prplmesh stop 2>&1 > /dev/null" 2>&1 > /dev/null

Check default configuration:

  $ R logger -t cram "Check default configuration"
  $ R "ba-cli -j -l WiFi.APMLDMaxLinks? | jsonfilter -e @[0]'[*].APMLDMaxLinks'"
  \d+ (re)

  $ R "ba-cli -j -l WiFi.MaxNumMLDs? | jsonfilter -e @[0]'[*].MaxNumMLDs'"
  \d+ (re)

  $ R "ba-cli WiFi.APMLD.?  | sed '/^$/d'" | tail -n +2 | LC_ALL=C sort
  WiFi.APMLD.1.
  WiFi.APMLD.1.APMLDConfig.
  WiFi.APMLD.1.APMLDConfig.EMLMREnabled=-1
  WiFi.APMLD.1.APMLDConfig.EMLSREnabled=-1
  WiFi.APMLD.1.APMLDConfig.NSTREnabled=-1
  WiFi.APMLD.1.APMLDConfig.STREnabled=-1
  WiFi.APMLD.1.AffiliatedAPNumberOfEntries=0
  WiFi.APMLD.1.MLDID=0
  WiFi.APMLD.1.MLDMACAddress=""
  WiFi.APMLD.2.
  WiFi.APMLD.2.APMLDConfig.
  WiFi.APMLD.2.APMLDConfig.EMLMREnabled=-1
  WiFi.APMLD.2.APMLDConfig.EMLSREnabled=-1
  WiFi.APMLD.2.APMLDConfig.NSTREnabled=-1
  WiFi.APMLD.2.APMLDConfig.STREnabled=-1
  WiFi.APMLD.2.AffiliatedAPNumberOfEntries=0
  WiFi.APMLD.2.MLDID=1
  WiFi.APMLD.2.MLDMACAddress=""

Configure radio and enable all AccessPoints:

  $ R logger -t cram "Enable all vaps"

  $ R "ba-cli -l WiFi.Radio.*.AutoChannelEnable=0 | sed '/^$/d'"
  0
  0
  0

  $ R "ba-cli -l \"WiFi.Radio.[OperatingFrequencyBand=='2.4GHz'].Channel='1'\"" | sed '/^$/d'
  1

  $ R "ba-cli -l \"WiFi.Radio.[OperatingFrequencyBand=='5GHz'].Channel='36'\"" | sed '/^$/d'
  36

  $ R "ba-cli -l \"WiFi.Radio.[OperatingFrequencyBand=='6GHz'].Channel='37'\"" | sed '/^$/d'
  37

  $ R "ba-cli WiFi.AccessPoint.*.Enable=1" > 1&2>/dev/null

  $ sleep 10

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

Check APMLD 2 number (guest vaps) of links:

  $ iw_affliated_link_info_from_mldid ${guest_mldunit}
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  channel 1 .* (re)
  channel 36 .* (re)
  channel 37 .* (re)

Read all link IDs (3 links per MLD):

  $ R 'ba-cli "WiFi.APMLD.*.AffiliatedAP.*.LinkID?"' | tail -n +2 | sed '/^$/d'
  WiFi.APMLD.1.AffiliatedAP.1.LinkID=0
  WiFi.APMLD.1.AffiliatedAP.2.LinkID=1
  WiFi.APMLD.1.AffiliatedAP.3.LinkID=2
  WiFi.APMLD.2.AffiliatedAP.1.LinkID=0
  WiFi.APMLD.2.AffiliatedAP.2.LinkID=1
  WiFi.APMLD.2.AffiliatedAP.3.LinkID=2

Read AffiliatedAP MAC addresses from iw (private):

  $ iw_affilated_mac_list=$(iw_affliated_mac_from_mldid ${private_mldunit})
  $ echo "$iw_affilated_mac_list"
  ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)

Read AffiliatedAP MAC addresses from pwhm (private):

  $ dm_affilated_mac_list=$(dm_affilated_mac_list_from_mldid ${private_mldunit})
  $ echo "$dm_affilated_mac_list"
  ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)

Cross check Affilated MACs addresses (private):

  $ merged_list=$(printf "%s\n%s\n" "$dm_affilated_mac_list" "$iw_affilated_mac_list" | tr '[:upper:]' '[:lower:]' | sort -u)

  $ echo "$merged_list" | uniq
  ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)

Read AffiliatedAP MAC addresses from iw (guest):

  $ iw_affilated_mac_list=$(iw_affliated_mac_from_mldid ${guest_mldunit})
  $ echo "$iw_affilated_mac_list"
  ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)

Read AffiliatedAP MAC addresses from pwhm (guest):

  $ dm_affilated_mac_list=$(dm_affilated_mac_list_from_mldid ${guest_mldunit})
  $ echo "$dm_affilated_mac_list"
  ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)

Cross check Affilated MACs addresses (guest):

  $ merged_list=$(printf "%s\n%s\n" "$dm_affilated_mac_list" "$iw_affilated_mac_list" | tr '[:upper:]' '[:lower:]' | sort -u)

  $ echo "$merged_list" | uniq
  ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)

Remove AP1 (private) from its APMLD:

  $ R logger -t cram "Remove AP1 from its APMLD"
  $ R "ba-cli -j -l WiFi.AccessPoint.1.SSIDReference+.MLDUnit=-1 | jsonfilter -e @[0]'[*].MLDUnit' "
  -1

  $ sleep 10

Check private APMLD number of links:

  $ iw_affliated_link_info_from_mldid ${private_mldunit}
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  channel 36 .* (re)
  channel 37 .* (re)

Read AffiliatedAP MAC addresses:

  $ iw_affliated_mac_from_mldid ${private_mldunit}
  ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)

Check link id of private MLD:

  $ R "ba-cli -j -l "WiFi.APMLD.[ MLDID == ${private_mldunit} ].AffiliatedAP.*.LinkID?" | jsonfilter -e @[0]'[*].LinkID'" | LC_ALL=C sort
  0
  1

Move back AP1 to its previous APMLD:

  $ R logger -t cram "Move back AP1 to its previous APMLD"
  $ R "ba-cli -j -l WiFi.AccessPoint.1.SSIDReference+.MLDUnit=${private_mldunit} | jsonfilter -e @[0]'[*].MLDUnit' "
  0

  $ sleep 10

Check private APMLD number of links:

  $ iw_affliated_link_info_from_mldid ${private_mldunit}
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  channel 1 .* (re)
  channel 36 .* (re)
  channel 37 .* (re)

Move AP1 to a new APMLD:

  $ R logger -t cram "Move AP1 to a new APMLD"
  $ R "ba-cli -j -l WiFi.AccessPoint.1.SSIDReference+.MLDUnit=${test_mldunit} | jsonfilter -e @[0]'[*].MLDUnit' "
  12

  $ sleep 10

Check private APMLD number of links:

  $ iw_affliated_link_info_from_mldid ${private_mldunit}
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  channel 36 .* (re)
  channel 37 .* (re)

Check the new APMLD 3 number of links:

  $ iw_affliated_link_info_from_mldid ${test_mldunit}
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  channel 1 .* (re)

Read AffiliatedAP MAC addresses:

  $ iw_affliated_mac_from_mldid ${private_mldunit}
  ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)

  $ iw_affliated_mac_from_mldid ${test_mldunit}
  ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)

Move back AP1 to its  APMLD

  $ R logger -t cram "Move back AP1 to its previous APMLD"
  $ R "ba-cli -j -l "WiFi.AccessPoint.1.SSIDReference+.MLDUnit=${private_mldunit}" | jsonfilter -e @[0]'[*].MLDUnit'"
  0

  $ sleep 10

Check private APMLD number of links:

  $ iw_affliated_link_info_from_mldid ${private_mldunit}
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  addr ([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2} (re)
  channel 1 .* (re)
  channel 36 .* (re)
  channel 37 .* (re)

Check if new APMLD was cleared:

  $ get_apmld_mac_from_dm ${test_mldunit}
  not_found

Disable guest vaps:

  $ R logger -t cram "Disable guest vaps"
  $ R 'ba-cli  -j -l  "WiFi.AccessPoint.[DefaultDeviceType==\"Guest\"].Enable=0" | jsonfilter -e @[0]'[*].Enable''
  0
  0
  0

  $ sleep 10

  $ R 'ba-cli -j -l  "WiFi.AccessPoint.[DefaultDeviceType==\"Guest\"].Status?0" | jsonfilter -e @[0]'[*].Status''
  Disabled
  Disabled
  Disabled

Check if guest apmld is cleared:

  $ R "ba-cli WiFi.APMLD.2.?  | sed '/^$/d'" | tail -n +2 | LC_ALL=C sort
  WiFi.APMLD.2.
  WiFi.APMLD.2.APMLDConfig.
  WiFi.APMLD.2.APMLDConfig.EMLMREnabled=-1
  WiFi.APMLD.2.APMLDConfig.EMLSREnabled=-1
  WiFi.APMLD.2.APMLDConfig.NSTREnabled=-1
  WiFi.APMLD.2.APMLDConfig.STREnabled=-1
  WiFi.APMLD.2.AffiliatedAPNumberOfEntries=0
  WiFi.APMLD.2.MLDID=1
  WiFi.APMLD.2.MLDMACAddress=""

Disable all AP:

  $ R logger -t cram "Disable all vaps"
  $ R "ba-cli WiFi.AccessPoint.*.Enable=0" > 1&2>/dev/null

Check if private apmld is cleared:

  $ sleep 10

  $ R "ba-cli WiFi.APMLD.1.?  | sed '/^$/d'" | tail -n +2 | LC_ALL=C sort
  WiFi.APMLD.1.
  WiFi.APMLD.1.APMLDConfig.
  WiFi.APMLD.1.APMLDConfig.EMLMREnabled=-1
  WiFi.APMLD.1.APMLDConfig.EMLSREnabled=-1
  WiFi.APMLD.1.APMLDConfig.NSTREnabled=-1
  WiFi.APMLD.1.APMLDConfig.STREnabled=-1
  WiFi.APMLD.1.AffiliatedAPNumberOfEntries=0
  WiFi.APMLD.1.MLDID=0
  WiFi.APMLD.1.MLDMACAddress=""

Resume prplMesh:

  $ R "/etc/init.d/prplmesh start 2>&1 > /dev/null"
  $ sleep 10
  $ R logger -t cram "Test finished!"
