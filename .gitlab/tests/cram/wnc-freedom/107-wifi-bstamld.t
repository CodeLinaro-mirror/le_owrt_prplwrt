Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting bSTAMLD test ..."

Stop prplMesh:

  $ R logger -t cram "Stop prplmesh"

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=0" | tr -d '\n'
  0 (no-eol)

  $ sleep 2

Check default configuration:

  $ wifi_dm "bSTAMLD.?"
  No data found

  $ wifi_dm "EndPoint.1.SSIDReference+.MLDUnit?0"
  Device.WiFi.SSID.\d+.MLDUnit=-1 (re)

  $ wifi_dm "EndPoint.2.SSIDReference+.MLDUnit?0"
  Device.WiFi.SSID.\d+.MLDUnit=-1 (re)

  $ wifi_dm "EndPoint.3.SSIDReference+.MLDUnit?0"
  Device.WiFi.SSID.\d+.MLDUnit=-1 (re)

  $ wifi_dm "bSTAMLDMaxLinks?"
  Device.WiFi.bSTAMLDMaxLinks=3

  $ wifi_dm "Radio.*.Capabilities.WiFi7STARole.?" "WiFi." "ba-cli"
  WiFi.Radio.1.Capabilities.WiFi7STARole.EMLMRSupport=0
  WiFi.Radio.1.Capabilities.WiFi7STARole.EMLSRSupport=1
  WiFi.Radio.1.Capabilities.WiFi7STARole.NSTRSupport=0
  WiFi.Radio.1.Capabilities.WiFi7STARole.STRSupport=0
  WiFi.Radio.2.Capabilities.WiFi7STARole.EMLMRSupport=0
  WiFi.Radio.2.Capabilities.WiFi7STARole.EMLSRSupport=1
  WiFi.Radio.2.Capabilities.WiFi7STARole.NSTRSupport=0
  WiFi.Radio.2.Capabilities.WiFi7STARole.STRSupport=0
  WiFi.Radio.3.Capabilities.WiFi7STARole.EMLMRSupport=0
  WiFi.Radio.3.Capabilities.WiFi7STARole.EMLSRSupport=1
  WiFi.Radio.3.Capabilities.WiFi7STARole.NSTRSupport=0
  WiFi.Radio.3.Capabilities.WiFi7STARole.STRSupport=0

#########################################
# Nominal use case: Test 3 bands MLO    #
#########################################

Configure an EP MLD with same MLD unit:

  $ R logger -t cram "Configure bSTAMLD"

  $ wifi_dm "EndPoint.1.SSIDReference+.MLDUnit=11"
  Device.WiFi.SSID.\d+.MLDUnit=11 (re)

  $ wifi_dm "EndPoint.2.SSIDReference+.MLDUnit=11"
  Device.WiFi.SSID.\d+.MLDUnit=11 (re)

  $ wifi_dm "EndPoint.3.SSIDReference+.MLDUnit=11"
  Device.WiFi.SSID.\d+.MLDUnit=11 (re)

  $ sleep 5

Check DM. At this step only MLDID can be checked. All other objects can't be updated unless we perform an onboarding.
It's needed to access DM in proteced mode to read UseNeighborProfile object.

  $ wifi_dm "bSTAMLD.?" "Device.WiFi." "ba-cli" protected
  Device.WiFi.bSTAMLD.1.AffiliatedbSTAList=""
  Device.WiFi.bSTAMLD.1.BSSID=""
  Device.WiFi.bSTAMLD.1.MLDID=11
  Device.WiFi.bSTAMLD.1.MLDMACAddress=""
  Device.WiFi.bSTAMLD.1.bSTAMLDConfig.EMLMREnabled=0
  Device.WiFi.bSTAMLD.1.bSTAMLDConfig.EMLSREnabled=1
  Device.WiFi.bSTAMLD.1.bSTAMLDConfig.NSTREnabled=0
  Device.WiFi.bSTAMLD.1.bSTAMLDConfig.STREnabled=0
  Device.WiFi.bSTAMLD.1.bSTAMLDConfig.UseNeighborProfile=1

Create profile for EP 1. As UseNeighborProfile is enbaled by default, no need to provision the other EP1 to do MLO:

  $ R logger -t cram "Create profile on EP1"

  $ ep1_alias=$(R 'ba-cli -l "WiFi.EndPoint.1.Profile+"' | sed '/^$/d')
  $ echo $ep1_alias
  cpe-Profile.* (re)

  $ wifi_dm "EndPoint.1.ProfileReference=WiFi.EndPoint.1.Profile.${ep1_alias}" "Device.WiFi." "ba-cli"
  Device.WiFi.EndPoint.1.ProfileReference="WiFi.EndPoint.1.Profile.* (re)

  $ wifi_dm "EndPoint.1.Profile.${ep1_alias}.Enable=1" "Device.WiFi." "ba-cli"
  Device.WiFi.EndPoint.1.Profile.\d+.Enable=1 (re)

  $ wifi_dm "EndPoint.1.Profile.${ep1_alias}.SSID=\"TEST_MLO\"" "Device.WiFi." "ba-cli"
  Device.WiFi.EndPoint.1.Profile.\d+.SSID="TEST_MLO" (re)

  $ wifi_dm "EndPoint.1.Profile.${ep1_alias}.Security.ModeEnabled=\"WPA2-WPA3-Personal\"" "Device.WiFi." "ba-cli"
  Device.WiFi.EndPoint.1.Profile.\d+.Security.ModeEnabled="WPA2-WPA3-Personal" (re)

  $ wifi_dm "EndPoint.1.Profile.${ep1_alias}.Security.KeyPassphrase=\"password\"" "Device.WiFi." "ba-cli"
  Device.WiFi.EndPoint.1.Profile.\d+.Security.KeyPassphrase="password" (re)

Enable all EPs:

  $ R logger -t cram "Enable all EndPoints"

  $ wifi_dm "EndPoint.*.Enable=1"
  Device.WiFi.EndPoint.1.Enable=1
  Device.WiFi.EndPoint.2.Enable=1
  Device.WiFi.EndPoint.3.Enable=1

  $ sleep 5

  $ R "pgrep wpa_supplicant"
  \d+ (re)

  $ wpa_conf_file=$(R "ps ax | grep '[w]pa_supplicant'" | sed -nE 's/.*-c[[:space:]]*([^[:space:]]+).*/\1/p' | sed '/^$/d')
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

#########################################
# Unset MLDUnit on 6GHz EP              #
#########################################

  $ R logger -t cram "Unset MLDUnit on 6GHz EP"

  $ wifi_dm "EndPoint.3.SSIDReference+.MLDUnit=-1"
  Device.WiFi.SSID.\d+.MLDUnit=-1 (re)

  $ sleep 5

  $ R "pgrep wpa_supplicant"
  \d+ (re)
  \d+ (re)

The 6GHz EP related config file should have only 6GHz channels:
In the bellow regex filter only wlan0_wpa_supplicant.conf (6GHz interface)

  $ wpa_conf_file_6ghz=$(R "ps ax | grep wpa_supplicant" | sed -n '/wlan/ {/wlan0/s/.*-c //p}' | sed '/^$/d')
  $ echo $wpa_conf_file_6ghz
  /tmp/wlan0_wpa_supplicant.conf (re)

  $ freq_list=$(R "cat ${wpa_conf_file_6ghz}" | grep freq_list)

  $ echo $freq_list | grep -oE '24[1-7][0-9]' | wc -l
  0

  $ echo $freq_list | grep -oE '5[1-8][0-9]{2}' | wc -l
  0

  $ echo $freq_list | grep -oE '6[0-9]{3}|7[0-1][0-9]{2}' | wc -l
  [1-9][0-9]* (re)

The other config file should use 2.4GHz and 5GHz frequencies:
In the bellow regex filter only the file that doesn't match  wlan0_wpa_supplicant.conf (6GHz interface)

  $ wpa_conf_file=$(R "ps ax | grep wpa_supplicant" | sed -n '/wlan/ {/wlan0/!s/.*-c //p}' | sed '/^$/d')
  $ echo $wpa_conf_file
  /tmp/wlan\d_wpa_supplicant.conf (re)

  $ freq_list=$(R "cat ${wpa_conf_file}" | grep freq_list)

  $ echo $freq_list | grep -oE '24[1-7][0-9]' | wc -l
  [1-9][0-9]* (re)

  $ echo $freq_list | grep -oE '5[1-8][0-9]{2}' | wc -l
  [1-9][0-9]* (re)

  $ echo $freq_list | grep -oE '6[0-9]{3}|7[0-1][0-9]{2}' | wc -l
  0

Check bSTAMLD (shouldn't change):

  $ wifi_dm "bSTAMLD.?" "Device.WiFi." "ba-cli" protected
  Device.WiFi.bSTAMLD.1.AffiliatedbSTAList=""
  Device.WiFi.bSTAMLD.1.BSSID=""
  Device.WiFi.bSTAMLD.1.MLDID=11
  Device.WiFi.bSTAMLD.1.MLDMACAddress=""
  Device.WiFi.bSTAMLD.1.bSTAMLDConfig.EMLMREnabled=0
  Device.WiFi.bSTAMLD.1.bSTAMLDConfig.EMLSREnabled=1
  Device.WiFi.bSTAMLD.1.bSTAMLDConfig.NSTREnabled=0
  Device.WiFi.bSTAMLD.1.bSTAMLDConfig.STREnabled=0
  Device.WiFi.bSTAMLD.1.bSTAMLDConfig.UseNeighborProfile=1

#########################################
# Unset MLDUnit on 5GHz EP              #
#########################################

  $ R logger -t cram "Unset MLDUnit on 5GHz EP"

  $ wifi_dm "EndPoint.2.SSIDReference+.MLDUnit=-1"
  Device.WiFi.SSID.\d+.MLDUnit=-1 (re)

  $ sleep 5

  $ R "pgrep wpa_supplicant"
  \d+ (re)
  \d+ (re)
  \d+ (re)

Check 6GHz (wlan0) frequencies:

  $ wpa_conf_file_6ghz=$(R "ps ax | grep wpa_supplicant" | sed -n '/wlan/ {/wlan0/s/.*-c //p}' | sed '/^$/d')
  $ echo $wpa_conf_file_6ghz
  /tmp/wlan0_wpa_supplicant.conf (re)

  $ freq_list=$(R "cat ${wpa_conf_file_6ghz}" | grep freq_list)

  $ echo $freq_list | grep -oE '24[1-7][0-9]' | wc -l
  0

  $ echo $freq_list | grep -oE '5[1-8][0-9]{2}' | wc -l
  0

  $ echo $freq_list | grep -oE '6[0-9]{3}|7[0-1][0-9]{2}' | wc -l
  [1-9][0-9]* (re)

Check 5GHz (wlan1) frequencies:

  $ wpa_conf_file_5ghz=$(R "ps ax | grep wpa_supplicant" | sed -n '/wlan/ {/wlan1/s/.*-c //p}' | sed '/^$/d')
  $ echo $wpa_conf_file_5ghz
  /tmp/wlan1_wpa_supplicant.conf (re)

  $ freq_list=$(R "cat ${wpa_conf_file_5ghz}" | grep freq_list)

  $ echo $freq_list | grep -oE '24[1-7][0-9]' | wc -l
  0

  $ echo $freq_list | grep -oE '5[1-8][0-9]{2}' | wc -l
  [1-9][0-9]* (re)

  $ echo $freq_list | grep -oE '6[0-9]{3}|7[0-1][0-9]{2}' | wc -l
  0

Check 2.4GHz (wlan2) frequencies:

  $ wpa_conf_file_2ghz=$(R "ps ax | grep wpa_supplicant" | sed -n '/wlan/ {/wlan2/s/.*-c //p}' | sed '/^$/d')
  $ echo $wpa_conf_file_2ghz
  /tmp/wlan2_wpa_supplicant.conf (re)

  $ freq_list=$(R "cat ${wpa_conf_file_2ghz}" | grep freq_list)

  $ echo $freq_list | grep -oE '24[1-7][0-9]' | wc -l
  [1-9][0-9]* (re)

  $ echo $freq_list | grep -oE '5[1-8][0-9]{2}' | wc -l
  0

  $ echo $freq_list | grep -oE '6[0-9]{3}|7[0-1][0-9]{2}' | wc -l
  0

Check bSTAMLD (shouldn't change):

  $ wifi_dm "bSTAMLD.?" "Device.WiFi." "ba-cli" protected
  Device.WiFi.bSTAMLD.1.AffiliatedbSTAList=""
  Device.WiFi.bSTAMLD.1.BSSID=""
  Device.WiFi.bSTAMLD.1.MLDID=11
  Device.WiFi.bSTAMLD.1.MLDMACAddress=""
  Device.WiFi.bSTAMLD.1.bSTAMLDConfig.EMLMREnabled=0
  Device.WiFi.bSTAMLD.1.bSTAMLDConfig.EMLSREnabled=1
  Device.WiFi.bSTAMLD.1.bSTAMLDConfig.NSTREnabled=0
  Device.WiFi.bSTAMLD.1.bSTAMLDConfig.STREnabled=0
  Device.WiFi.bSTAMLD.1.bSTAMLDConfig.UseNeighborProfile=1

#########################################
# Test MLO with shared profile disabled #
#########################################

  $ R logger -t cram "Disable all EndPoints before disabling UseNeighborProfile"

  $ wifi_dm "EndPoint.*.Enable=0"
  Device.WiFi.EndPoint.1.Enable=0
  Device.WiFi.EndPoint.2.Enable=0
  Device.WiFi.EndPoint.3.Enable=0

  $ sleep 5

Disable UseNeighborProfile:

  $ wifi_dm "bSTAMLD.1.bSTAMLDConfig.UseNeighborProfile=0" "Device.WiFi." "ba-cli" protected
  Device.WiFi.bSTAMLD.1.bSTAMLDConfig.UseNeighborProfile=0

Configure an EP MLD with same MLD unit:

  $ R logger -t cram "Configure bSTAMLD with 3 Links"

  $ wifi_dm "EndPoint.1.SSIDReference+.MLDUnit=11"
  Device.WiFi.SSID.\d+.MLDUnit=11 (re)

  $ wifi_dm "EndPoint.2.SSIDReference+.MLDUnit=11"
  Device.WiFi.SSID.\d+.MLDUnit=11 (re)

  $ wifi_dm "EndPoint.3.SSIDReference+.MLDUnit=11"
  Device.WiFi.SSID.\d+.MLDUnit=11 (re)

Create EP2 and EP3 profiles:

  $ R logger -t cram "Create EP2 and EP3 profiles"

Create profile for EP 2:

  $ ep2_alias=$(R 'ba-cli -l "Device.WiFi.EndPoint.2.Profile+"' | sed '/^$/d')
  $ echo $ep2_alias
  cpe-Profile.* (re)

  $ wifi_dm "EndPoint.2.ProfileReference=WiFi.EndPoint.2.Profile.${ep2_alias}" "Device.WiFi." "ba-cli"
  Device.WiFi.EndPoint.2.Profile.* (re)

  $ wifi_dm "EndPoint.2.Profile.${ep2_alias}.Enable=1" "Device.WiFi." "ba-cli"
  Device.WiFi.EndPoint.2.Profile.\d+.Enable=1 (re)

  $ wifi_dm "EndPoint.2.Profile.${ep2_alias}.SSID=\"TEST_MLO\"" "Device.WiFi." "ba-cli"
  Device.WiFi.EndPoint.2.Profile.\d+.SSID="TEST_MLO" (re)

  $ wifi_dm "EndPoint.2.Profile.${ep2_alias}.Security.ModeEnabled=\"WPA2-WPA3-Personal\"" "Device.WiFi." "ba-cli"
  Device.WiFi.EndPoint.2.Profile.\d+.Security.ModeEnabled="WPA2-WPA3-Personal" (re)

  $ wifi_dm "EndPoint.2.Profile.${ep2_alias}.Security.KeyPassphrase=\"password\"" "Device.WiFi." "ba-cli"
  Device.WiFi.EndPoint.2.Profile.\d+.Security.KeyPassphrase="password" (re)

Create profile for EP 3:

  $ ep3_alias=$(R 'ba-cli -l "Device.WiFi.EndPoint.3.Profile+"' | sed '/^$/d')
  $ echo $ep3_alias
  cpe-Profile.* (re)

  $ wifi_dm "EndPoint.3.ProfileReference=WiFi.EndPoint.3.Profile.${ep3_alias}" "Device.WiFi." "ba-cli"
  Device.WiFi.EndPoint.3.Profile.* (re)

  $ wifi_dm "EndPoint.3.Profile.${ep3_alias}.Enable=1" "Device.WiFi." "ba-cli"
  Device.WiFi.EndPoint.3.Profile.\d+.Enable=1 (re)

  $ wifi_dm "EndPoint.3.Profile.${ep3_alias}.SSID=\"TEST_MLO\"" "Device.WiFi." "ba-cli"
  Device.WiFi.EndPoint.3.Profile.\d+.SSID="TEST_MLO" (re)

  $ wifi_dm "EndPoint.3.Profile.${ep3_alias}.Security.ModeEnabled=\"WPA2-WPA3-Personal\"" "Device.WiFi." "ba-cli"
  Device.WiFi.EndPoint.3.Profile.\d+.Security.ModeEnabled="WPA2-WPA3-Personal" (re)

  $ wifi_dm "EndPoint.3.Profile.${ep3_alias}.Security.KeyPassphrase=\"password\"" "Device.WiFi." "ba-cli"
  Device.WiFi.EndPoint.3.Profile.\d+.Security.KeyPassphrase="password" (re)

Enable all EPs:

  $ R logger -t cram "Enable again all EndPoints"

  $ wifi_dm "EndPoint.*.Enable=1"
  Device.WiFi.EndPoint.1.Enable=1
  Device.WiFi.EndPoint.2.Enable=1
  Device.WiFi.EndPoint.3.Enable=1

  $ sleep 5

  $ R "pgrep wpa_supplicant"
  \d+ (re)

  $ wpa_conf_file=$(R "ps ax | grep '[w]pa_supplicant'" | sed -nE 's/.*-c[[:space:]]*([^[:space:]]+).*/\1/p' | sed '/^$/d')
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

#########################################
# Restore defaults                      #
#########################################

  $ R logger -t cram "Finishing bSTAMLD test"

  $ R logger -t cram "Disable all EndPoints"

  $ wifi_dm "EndPoint.*.Enable=0"
  Device.WiFi.EndPoint.1.Enable=0
  Device.WiFi.EndPoint.2.Enable=0
  Device.WiFi.EndPoint.3.Enable=0

Restore defaults:

  $ R logger -t cram "Finishing bSTAMLD test"

  $ R "ba-cli -l \"Device.WiFi.EndPoint.1.Profile.${ep1_alias}-\"" | sed '/^$/d'
  Device.WiFi.EndPoint.1.Profile.\d+. (re)
  Device.WiFi.EndPoint.1.Profile.\d+.Security. (re)

  $ R "ba-cli -l \"Device.WiFi.EndPoint.2.Profile.${ep2_alias}-\"" | sed '/^$/d'
  Device.WiFi.EndPoint.2.Profile.\d+. (re)
  Device.WiFi.EndPoint.2.Profile.\d+.Security. (re)

  $ R "ba-cli -l \"Device.WiFi.EndPoint.3.Profile.${ep3_alias}-\"" | sed '/^$/d'
  Device.WiFi.EndPoint.3.Profile.\d+. (re)
  Device.WiFi.EndPoint.3.Profile.\d+.Security. (re)

  $ wifi_dm "EndPoint.1.SSIDReference+.MLDUnit=-1"
  Device.WiFi.SSID.\d+.MLDUnit=-1 (re)

  $ wifi_dm "EndPoint.2.SSIDReference+.MLDUnit=-1"
  Device.WiFi.SSID.\d+.MLDUnit=-1 (re)

  $ wifi_dm "EndPoint.3.SSIDReference+.MLDUnit=-1"
  Device.WiFi.SSID.\d+.MLDUnit=-1 (re)

  $ wifi_dm "bSTAMLD.1.bSTAMLDConfig.UseNeighborProfile=1" "Device.WiFi." "ba-cli" protected
  Device.WiFi.bSTAMLD.1.bSTAMLDConfig.UseNeighborProfile=1

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=1" | tr -d '\n'
  1 (no-eol)

  $ R logger -t cram "Test finished!"
