Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting bSTAMLD test ..."

Stop prplMesh:

  $ R "/etc/init.d/prplmesh stop 2>&1 > /dev/null" 2>&1 > /dev/null

Check default configuration:

  $ R "ba-cli -l -j WiFi.bSTAMLD.?" | sed '/^$/d'
  [{}]

  $ R "ba-cli -l WiFi.EndPoint.1.SSIDReference+.MLDUnit?0" | sed '/^$/d'
  -1

  $ R "ba-cli -l WiFi.EndPoint.2.SSIDReference+.MLDUnit?0" | sed '/^$/d'
  -1

  $ R "ba-cli -l WiFi.EndPoint.3.SSIDReference+.MLDUnit?0" | sed '/^$/d'
  -1

Configure an EP MLD with same MLD unit:

  $ R logger -t cram "Configure bSTAMLD"

  $ R "ba-cli -l WiFi.EndPoint.1.SSIDReference+.MLDUnit=11" | sed '/^$/d'
  11

  $ R "ba-cli -l WiFi.EndPoint.2.SSIDReference+.MLDUnit=11" | sed '/^$/d'
  11

  $ R "ba-cli -l WiFi.EndPoint.3.SSIDReference+.MLDUnit=11" | sed '/^$/d'
  11

  $ sleep 5

Check DM. At this step only MLDID can be checked. All other objects can't be updated unless we perform an onboarding:

  $ R "ba-cli \"  WiFi.bSTAMLD.?\"" | tail -n+2 | sed '/^$/d' | sort
  WiFi.bSTAMLD.1.
  WiFi.bSTAMLD.1.AffiliatedbSTAList=""
  WiFi.bSTAMLD.1.BSSID=""
  WiFi.bSTAMLD.1.MLDID=11
  WiFi.bSTAMLD.1.MLDMACAddress=""
  WiFi.bSTAMLD.1.bSTAMLDConfig.
  WiFi.bSTAMLD.1.bSTAMLDConfig.EMLMREnabled=-1
  WiFi.bSTAMLD.1.bSTAMLDConfig.EMLSREnabled=-1
  WiFi.bSTAMLD.1.bSTAMLDConfig.NSTREnabled=-1
  WiFi.bSTAMLD.1.bSTAMLDConfig.STREnabled=-1

Create profile for EP 1:

  $ ep1_alias=$(R 'ba-cli -l "WiFi.EndPoint.1.Profile+"' | sed '/^$/d')
  $ echo $ep1_alias
  cpe-Profile.* (re)

  $ R "ba-cli -l \"WiFi.EndPoint.1.ProfileReference=WiFi.EndPoint.1.Profile.${ep1_alias}\"" | sed '/^$/d'
  WiFi.EndPoint.1.Profile.* (re)

  $ R "ba-cli -l \"WiFi.EndPoint.1.Profile.${ep1_alias}.Enable=1\"" | sed '/^$/d'
  1

  $ R "ba-cli -l \"WiFi.EndPoint.1.Profile.${ep1_alias}.SSID=\"TEST_MLO\"\"" | sed '/^$/d'
  TEST_MLO

  $ R "ba-cli -l \"WiFi.EndPoint.1.Profile.${ep1_alias}.Security.ModeEnabled=\"WPA2-WPA3-Personal\"\"" | sed '/^$/d'
  WPA2-WPA3-Personal

  $ R "ba-cli -l \"WiFi.EndPoint.1.Profile.${ep1_alias}.Security.KeyPassPhrase=\"password\"\"" | sed '/^$/d'
  password

Create profile for EP 2:

  $ ep2_alias=$(R 'ba-cli -l "WiFi.EndPoint.2.Profile+"' | sed '/^$/d')
  $ echo $ep2_alias
  cpe-Profile.* (re)

  $ R "ba-cli -l \"WiFi.EndPoint.2.ProfileReference=WiFi.EndPoint.2.Profile.${ep2_alias}\"" | sed '/^$/d'
  WiFi.EndPoint.2.Profile.* (re)

  $ R "ba-cli -l \"WiFi.EndPoint.2.Profile.${ep2_alias}.Enable=1\"" | sed '/^$/d'
  1

  $ R "ba-cli -l \"WiFi.EndPoint.2.Profile.${ep2_alias}.SSID=\"TEST_MLO\"\"" | sed '/^$/d'
  TEST_MLO

  $ R "ba-cli -l \"WiFi.EndPoint.2.Profile.${ep2_alias}.Security.ModeEnabled=\"WPA2-WPA3-Personal\"\"" | sed '/^$/d'
  WPA2-WPA3-Personal

  $ R "ba-cli -l \"WiFi.EndPoint.2.Profile.${ep2_alias}.Security.KeyPassPhrase=\"password\"\"" | sed '/^$/d'
  password

Create profile for EP 3:

  $ ep3_alias=$(R 'ba-cli -l "WiFi.EndPoint.3.Profile+"' | sed '/^$/d')
  $ echo $ep3_alias
  cpe-Profile.* (re)

  $ R "ba-cli -l \"WiFi.EndPoint.3.ProfileReference=WiFi.EndPoint.3.Profile.${ep3_alias}\"" | sed '/^$/d'
  WiFi.EndPoint.3.Profile.* (re)

  $ R "ba-cli -l \"WiFi.EndPoint.3.Profile.${ep3_alias}.Enable=1\"" | sed '/^$/d'
  1

  $ R "ba-cli -l \"WiFi.EndPoint.3.Profile.${ep3_alias}.SSID=\"TEST_MLO\"\"" | sed '/^$/d'
  TEST_MLO

  $ R "ba-cli -l \"WiFi.EndPoint.3.Profile.${ep3_alias}.Security.ModeEnabled=\"WPA2-WPA3-Personal\"\"" | sed '/^$/d'
  WPA2-WPA3-Personal

  $ R "ba-cli -l \"WiFi.EndPoint.3.Profile.${ep3_alias}.Security.KeyPassPhrase=\"password\"\"" | sed '/^$/d'
  password

Enable all EPs:

  $ R logger -t cram "Enable all EndPoints"

  $ R "ba-cli \"WiFi.EndPoint.*.Enable=1\"" | sed '/^$/d' | grep Enable | tail -n +2
  WiFi.EndPoint.1.Enable=1
  WiFi.EndPoint.2.Enable=1
  WiFi.EndPoint.3.Enable=1

  $ sleep 5

  $ R "pgrep wpa_supplicant"
  \d+ (re)

  $ wpa_conf_file=$(R "ps ax | grep wpa_supplicant" | sed -n 's/.*-c\([^ ]*\).*/\1/p' | sed '/^$/d')
  $ echo $wpa_conf_file
  /tmp/wlan\d_wpa_supplicant.conf (re)

Check if 3 bands are used in frequencies list:

  $ freq_list=$(R "cat ${wpa_conf_file}" | grep freq_list)

  $ echo $freq_list | grep -oE '24[1-7][0-9]' | wc -l
  [1-9][0-9]* (re)

  $ echo $freq_list | grep -oE '5[1-8][0-9]{2}' | wc -l
  [1-9][0-9]* (re)

  $ echo $freq_list | grep -oE '6[0-9]{3}|7[0-1][0-9]{2}' | wc -l
  [1-9][0-9]* (re)

Restore defaults:

  $ R logger -t cram "Finishing bSTAMLD test"

  $ R "ba-cli -l \"WiFi.EndPoint.1.Profile.${ep1_alias}-\"" | sed '/^$/d'
  WiFi.EndPoint.1.Profile.\d+. (re)
  WiFi.EndPoint.1.Profile.\d+.Security. (re)

  $ R "ba-cli -l \"WiFi.EndPoint.2.Profile.${ep2_alias}-\"" | sed '/^$/d'
  WiFi.EndPoint.2.Profile.\d+. (re)
  WiFi.EndPoint.2.Profile.\d+.Security. (re)

  $ R "ba-cli -l \"WiFi.EndPoint.3.Profile.${ep3_alias}-\"" | sed '/^$/d'
  WiFi.EndPoint.3.Profile.\d+. (re)
  WiFi.EndPoint.3.Profile.\d+.Security. (re)

  $ R "ba-cli -l WiFi.EndPoint.1.SSIDReference+.MLDUnit=-1" | sed '/^$/d'
  -1

  $ R "ba-cli -l WiFi.EndPoint.2.SSIDReference+.MLDUnit=-1" | sed '/^$/d'
  -1

  $ R "ba-cli -l WiFi.EndPoint.3.SSIDReference+.MLDUnit=-1" | sed '/^$/d'
  -1

  $ R "/etc/init.d/prplmesh start 2>&1 > /dev/null"

  $ R logger -t cram "Test finished!"
