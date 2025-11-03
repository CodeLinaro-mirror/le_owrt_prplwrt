Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . ${CRAM_FUNCTIONS}

  $ R logger -t cram "Starting APMLD test ..."

  $ R "ba-cli -j -l WiFi.APMLDMaxLinks? | jsonfilter -e @[0]'[*].APMLDMaxLinks'"
  4

  $ R "ba-cli -j -l WiFi.MaxNumMLDs? | jsonfilter -e @[0]'[*].MaxNumMLDs'"
  3

Check default values: 

  $ R "ba-cli WiFi.APMLD.?  | sed '/^$/d'" | tail -n +2 | LC_ALL=C sort
  WiFi.APMLD.1.
  WiFi.APMLD.1.APMLDConfig.
  WiFi.APMLD.1.APMLDConfig.EMLMREnabled=-1
  WiFi.APMLD.1.APMLDConfig.EMLSREnabled=-1
  WiFi.APMLD.1.APMLDConfig.NSTREnabled=-1
  WiFi.APMLD.1.APMLDConfig.STREnabled=-1
  WiFi.APMLD.1.AffiliatedAPNumberOfEntries=0
  WiFi.APMLD.1.MLDID=0
  WiFi.APMLD.1.MLDMACAddress=.* (re)
  WiFi.APMLD.2.
  WiFi.APMLD.2.APMLDConfig.
  WiFi.APMLD.2.APMLDConfig.EMLMREnabled=-1
  WiFi.APMLD.2.APMLDConfig.EMLSREnabled=-1
  WiFi.APMLD.2.APMLDConfig.NSTREnabled=-1
  WiFi.APMLD.2.APMLDConfig.STREnabled=-1
  WiFi.APMLD.2.AffiliatedAPNumberOfEntries=3
  WiFi.APMLD.2.MLDID=1
  WiFi.APMLD.2.MLDMACAddress=.* (re)

Enables all AccessPoints:

  $ R "ba-cli WiFi.AccessPoint.*.Enable=1" > 1&2>/dev/null

  $ sleep 10

Save hostap pid:

  $ hostap_pid=$(R pgrep -f 'hostapd')
  $ R logger -t cram "hostap PID : $hostap_pid"

Check APMLD 1 number of links:

  $ link_number_from_apmld 1
  3

Check APMLD 2 number of links:

  $ link_number_from_apmld 2
  3

Remove AP1 from it's APMLD:

  $ R "ba-cli -j -l WiFi.SSID.1.MLDUnit=-1 | jsonfilter -e @[0]'[*].MLDUnit' "
  -1

  $ sleep 10

Check APMLD 1 number of links:

  $ link_number_from_apmld 1
  2

Move back AP to its preivous APMLD

  $ R "ba-cli -j -l WiFi.SSID.1.MLDUnit=0 | jsonfilter -e @[0]'[*].MLDUnit' "
  0

  $ sleep 10

Check APMLD 1 number of links:

  $ link_number_from_apmld 1
  3

Move AP1 to a new APMLD:

  $ R "ba-cli -j -l WiFi.SSID.1.MLDUnit=2 | jsonfilter -e @[0]'[*].MLDUnit' "
  2

  $ sleep 10

Check APMLD 1 number of links:

  $ link_number_from_apmld 1
  2

Check the new APMLD 3 number of links:

  $ link_number_from_apmld 3
  1

Move back AP to its preivous APMLD

  $ R "ba-cli -j -l WiFi.SSID.1.MLDUnit=0 | jsonfilter -e @[0]'[*].MLDUnit' "
  0

  $ sleep 10

Check APMLD 1 number of links:

  $ link_number_from_apmld 1
  3

Check the new APMLD 3 number of links:

  $ link_number_from_apmld 3
  0

Before deactivating last AP (ie stopping hostpad), check if hostap pid has changed or not:

  $ if [ "$(R pgrep -f 'hostapd')" = "$hostap_pid" ]; then echo "true"; else echo "hostap restarted during the test !"; fi
  true

Disable all AP:

  $ R "ba-cli WiFi.AccessPoint.*.Enable=1" > 1&2>/dev/null

  $ sleep 10
