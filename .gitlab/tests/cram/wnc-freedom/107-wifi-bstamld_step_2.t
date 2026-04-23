Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting bSTAMLD test 2/2 ..."

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

Assume that the profile created during the test has index 1. Because of the test split (PCF-2222), we can't read reliably EP1 alias.

  $ R "ba-cli -l \"Device.WiFi.EndPoint.1.Profile.1-\"" | sed '/^$/d'
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

  $ R logger -t cram "bSTAMLD test 1/2 finished!"
