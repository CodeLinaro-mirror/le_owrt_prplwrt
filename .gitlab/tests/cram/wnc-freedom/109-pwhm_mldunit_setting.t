Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R "logger -t cram 'Starting MLDUnitSetting test ...'"

  $ wifi_dm "PrplMesh.Enable=0" "X_PRPLWARE-COM_ProcessManager." "ba-cli"
  X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=0

Silently set Disabled-MLD MLDUnit for all SSIDs (12 instances)
  $ wifi_dm "SSID.*.MLDUnit=-1" "WiFi." "ba-cli" | wc -l
  12


  $ sleep 2

Check 11be is enabled
  $ wifi_dm "AccessPoint.5.RadioReference+.OperatingStandards?" "WiFi." "ba-cli"
  Device.WiFi.Radio.\d+.OperatingStandards="ax,be" (re)

Check MLO Support
  $ wifi_dm "Radio.2.IEEE80211_Caps?" "WiFi." "ba-cli" | grep MLO | wc -l
  1

Disable AccessPoints

$ enable_ap_sync * 0
AccessPoint.*.Enable=0

Enable AccessPoint Under Test
  $ enable_ap_sync 5 1
  AccessPoint.\d+.Enable=1 (re)

  $ wifi_dm "AccessPoint.5.SSIDReference+.Name?" "WiFi." "ba-cli"
  Device.WiFi.SSID.\d+.Name="wlan0.1" (re)

Used later to check hostapd config file
  $ itf=$(wifi_dm "AccessPoint.5.SSIDReference+.Name?" "WiFi." "ba-cli" | cut -d "=" -f 2 | tr -d "\"")

  $ rad_name=$(wifi_dm "AccessPoint.5.RadioReference+.Name?" "WiFi." "ba-cli" | cut -d "=" -f 2 | tr -d "\"")

Subset A : MLDUnit=-1

  $ R "logger -t cram 'MLDUnitSetting: Disabled MLDUnit; MLDUnitSetting=NotRequired'"

Set MLDUnitSetting='NotRequired'
  $ wifi_dm "Radio.*.IEEE80211be.MLDUnitSetting='NotRequired'" "WiFi." "ba-cli"
  WiFi.Radio.1.IEEE80211be.MLDUnitSetting="NotRequired"
  WiFi.Radio.2.IEEE80211be.MLDUnitSetting="NotRequired"
  WiFi.Radio.3.IEEE80211be.MLDUnitSetting="NotRequired"

Set Disabled-MLD MLDUnit
  $ wifi_dm "AccessPoint.5.SSIDReference+.MLDUnit=-1" "WiFi." "ba-cli"
  Device.WiFi.SSID.\d+.MLDUnit=-1 (re)

  $ sleep 15

Check 11be configuration values : {ieee80211be} enabled for Radio, {mld_ap,disable_11be} = {0,0} for interface
  $ R "cat /tmp/${rad_name}_hapd.conf | grep ieee80211be"
  ieee80211be=1

  $ get_hapd_config $itf mld_ap
  0

  $ get_hapd_config $itf disable_11be
  0

  $ R "logger -t cram 'MLDUnitSetting: Disabled MLD; MLDUnitSetting=Required'"

Set MLDUnitSetting='Required'
  $ wifi_dm "Radio.*.IEEE80211be.MLDUnitSetting='Required'" "WiFi." "ba-cli"
  WiFi.Radio.1.IEEE80211be.MLDUnitSetting="Required"
  WiFi.Radio.2.IEEE80211be.MLDUnitSetting="Required"
  WiFi.Radio.3.IEEE80211be.MLDUnitSetting="Required"

  $ sleep 15

Check 11be configuration values : {ieee80211be} disabled for Radio, {mld_ap,disable_11be} absent for interface
  $ R "cat /tmp/${rad_name}_hapd.conf | grep ieee80211be"
  ieee80211be=0

  $ get_hapd_config $itf mld_ap
  Option 'mld_ap' not found

  $ get_hapd_config $itf disable_11be
  Option 'disable_11be' not found

  $ R "logger -t cram 'MLDUnitSetting: Disabled MLD; MLDUnitSetting=Assumed'"

Set MLDUnitSetting='Assumed'; with MLDUnit=-1, this should still result in WiFi7 - EHT + MLO configuration
  $ wifi_dm "Radio.*.IEEE80211be.MLDUnitSetting='Assumed'" "WiFi." "ba-cli"
  WiFi.Radio.1.IEEE80211be.MLDUnitSetting="Assumed"
  WiFi.Radio.2.IEEE80211be.MLDUnitSetting="Assumed"
  WiFi.Radio.3.IEEE80211be.MLDUnitSetting="Assumed"

  $ sleep 15

Check 11be configuration values : {ieee80211be} enabled for Radio, {mld_ap,disable_11be} = {1,0} for interface
  $ R "cat /tmp/${rad_name}_hapd.conf | grep ieee80211be"
  ieee80211be=1

  $ get_hapd_config $itf mld_ap
  1

  $ get_hapd_config $itf disable_11be
  0

Subset B : Valid MLDUnit

  $ R "logger -t cram 'MLDUnitSetting: Enabled MLD; MLDUnitSetting=Required'"

  $ wifi_dm "Radio.*.IEEE80211be.MLDUnitSetting='Required'" "WiFi." "ba-cli"
  WiFi.Radio.1.IEEE80211be.MLDUnitSetting="Required"
  WiFi.Radio.2.IEEE80211be.MLDUnitSetting="Required"
  WiFi.Radio.3.IEEE80211be.MLDUnitSetting="Required"

  $ sleep 15

Set arbitrary MLDUnit>(-1)
  $ wifi_dm "AccessPoint.5.SSIDReference+.MLDUnit=8" "WiFi." "ba-cli"
  Device.WiFi.SSID.\d+.MLDUnit=8 (re)

  $ sleep 15

Check 11be configuration values : {ieee80211be} enabled for Radio, {mld_ap,disable_11be} = {1,0} for interface
  $ R "cat /tmp/${rad_name}_hapd.conf | grep ieee80211be"
  ieee80211be=1

  $ get_hapd_config $itf mld_ap
  1

  $ get_hapd_config $itf disable_11be
  0

  $ R "logger -t cram 'MLDUnitSetting: Enabled MLD; MLDUnitSetting=Required'"

Set MLDUnitSetting='NotRequired'
  $ wifi_dm "Radio.*.IEEE80211be.MLDUnitSetting='NotRequired'" "WiFi." "ba-cli"
  WiFi.Radio.1.IEEE80211be.MLDUnitSetting="NotRequired"
  WiFi.Radio.2.IEEE80211be.MLDUnitSetting="NotRequired"
  WiFi.Radio.3.IEEE80211be.MLDUnitSetting="NotRequired"

  $ sleep 5

Check 11be configuration values : {ieee80211be} enabled for Radio, {mld_ap,disable_11be} = {1,0} for interface
  $ R "cat /tmp/${rad_name}_hapd.conf | grep ieee80211be"
  ieee80211be=1

  $ get_hapd_config $itf mld_ap
  1

  $ get_hapd_config $itf disable_11be
  0

  $ R "logger -t cram 'MLDUnitSetting: Enabled MLD; MLDUnitSetting=NotRequired'"

Set MLDUnitSetting='NotRequired'
  $ wifi_dm "Radio.*.IEEE80211be.MLDUnitSetting='Assumed'" "WiFi." "ba-cli"
  WiFi.Radio.1.IEEE80211be.MLDUnitSetting="Assumed"
  WiFi.Radio.2.IEEE80211be.MLDUnitSetting="Assumed"
  WiFi.Radio.3.IEEE80211be.MLDUnitSetting="Assumed"

  $ sleep 5

Check 11be configuration values : {ieee80211be} enabled for Radio, {mld_ap,disable_11be} = {1,0} for interface
  $ R "cat /tmp/${rad_name}_hapd.conf | grep ieee80211be"
  ieee80211be=1

  $ get_hapd_config $itf mld_ap
  1

  $ get_hapd_config $itf disable_11be
  0

Restore cram-context MLDUnitSetting : 'Required'
  $ wifi_dm "Radio.*.IEEE80211be.MLDUnitSetting='Required'" "WiFi." "ba-cli"
  WiFi.Radio.1.IEEE80211be.MLDUnitSetting="Required"
  WiFi.Radio.2.IEEE80211be.MLDUnitSetting="Required"
  WiFi.Radio.3.IEEE80211be.MLDUnitSetting="Required"

Restore MLDUnit to defaults
  $ set_ssid_mldunit prplOS 0
  0
  0
  0

  $ set_ssid_mldunit prplOS-guest 1
  1
  1
  1

backhaul SSIDs are instantiated with exact indexes by 33_wld-custom-prplmeshVapsConfiguration.odl
  $ wifi_dm "SSID.16.MLDUnit=2" "WiFi." "ba-cli"
  WiFi.SSID.16.MLDUnit=2

  $ wifi_dm "SSID.17.MLDUnit=2" "WiFi." "ba-cli"
  WiFi.SSID.17.MLDUnit=2

  $ wifi_dm "SSID.18.MLDUnit=2" "WiFi." "ba-cli"
  WiFi.SSID.18.MLDUnit=2
