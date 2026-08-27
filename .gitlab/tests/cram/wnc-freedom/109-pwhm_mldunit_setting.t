Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting $TESTFILE"

  $ check_wifi_defaults
  $ testbed_set_wifi_defaults

  $ prplmesh_stop

Disable MLDUnit for all SSIDs:

  $ wifi_dm "SSID.*.MLDUnit=-1"
  Device.WiFi.SSID.1.MLDUnit=-1
  Device.WiFi.SSID.16.MLDUnit=-1
  Device.WiFi.SSID.17.MLDUnit=-1
  Device.WiFi.SSID.18.MLDUnit=-1
  Device.WiFi.SSID.2.MLDUnit=-1
  Device.WiFi.SSID.3.MLDUnit=-1
  Device.WiFi.SSID.4.MLDUnit=-1
  Device.WiFi.SSID.5.MLDUnit=-1
  Device.WiFi.SSID.6.MLDUnit=-1
  Device.WiFi.SSID.7.MLDUnit=-1
  Device.WiFi.SSID.8.MLDUnit=-1
  Device.WiFi.SSID.9.MLDUnit=-1

  $ sleep 2

Check 11be is enabled:

  $ wifi_dm "AccessPoint.5.RadioReference+.OperatingStandards?" "WiFi." "ba-cli"
  Device.WiFi.Radio.\d+.OperatingStandards="ax,be" (re)

Check MLO Support:

  $ wifi_dm "Radio.2.IEEE80211_Caps?" "WiFi." "ba-cli" | grep MLO | wc -l
  1


Enable AccessPoint under test:

  $ enable_ap_sync 5 1
  AccessPoint.\d+.Enable=1 (re)

Used later to check hostapd config file:

  $ itf=$(wifi_dm "AccessPoint.5.SSIDReference+.Name?" "WiFi." "ba-cli" | cut -d "=" -f 2 | tr -d "\"")
  $ rad_name=$(wifi_dm "AccessPoint.5.RadioReference+.Name?" "WiFi." "ba-cli" | cut -d "=" -f 2 | tr -d "\"")

Subset A : MLDUnit=-1

  $ R "logger -t cram 'MLDUnitSetting: Disabled MLDUnit; MLDUnitSetting=NotRequired'"

Set MLDUnitSetting='NotRequired':

  $ wifi_dm "Radio.*.IEEE80211be.MLDUnitSetting='NotRequired'" "WiFi." "ba-cli"
  WiFi.Radio.1.IEEE80211be.MLDUnitSetting="NotRequired"
  WiFi.Radio.2.IEEE80211be.MLDUnitSetting="NotRequired"
  WiFi.Radio.3.IEEE80211be.MLDUnitSetting="NotRequired"

Set Disabled-MLD MLDUnit:

  $ wifi_dm "AccessPoint.5.SSIDReference+.MLDUnit=-1" "WiFi." "ba-cli"
  Device.WiFi.SSID.\d+.MLDUnit=-1 (re)

  $ sleep 15

Check 11be configuration values : {ieee80211be} enabled for Radio, {mld_ap,disable_11be} = {0,0} for interface:

  $ R "cat /tmp/${rad_name}_hapd.conf | grep ieee80211be"
  ieee80211be=1

  $ get_hapd_config $itf mld_ap
  0

  $ get_hapd_config $itf disable_11be
  0

  $ R "logger -t cram 'MLDUnitSetting: Disabled MLD; MLDUnitSetting=Required'"

Set MLDUnitSetting='Required':

  $ wifi_dm "Radio.*.IEEE80211be.MLDUnitSetting='Required'" "WiFi." "ba-cli"
  WiFi.Radio.1.IEEE80211be.MLDUnitSetting="Required"
  WiFi.Radio.2.IEEE80211be.MLDUnitSetting="Required"
  WiFi.Radio.3.IEEE80211be.MLDUnitSetting="Required"

  $ sleep 15

Check 11be configuration values : {ieee80211be} disabled for Radio, {mld_ap,disable_11be} absent for interface:

  $ R "cat /tmp/${rad_name}_hapd.conf | grep ieee80211be"
  ieee80211be=0

  $ get_hapd_config $itf mld_ap
  Option 'mld_ap' not found

  $ get_hapd_config $itf disable_11be
  Option 'disable_11be' not found

  $ R "logger -t cram 'MLDUnitSetting: Disabled MLD; MLDUnitSetting=Assumed'"

Set MLDUnitSetting='Assumed'; with MLDUnit=-1, this should still result in WiFi7 - EHT + MLO configuration:

  $ wifi_dm "Radio.*.IEEE80211be.MLDUnitSetting='Assumed'" "WiFi." "ba-cli"
  WiFi.Radio.1.IEEE80211be.MLDUnitSetting="Assumed"
  WiFi.Radio.2.IEEE80211be.MLDUnitSetting="Assumed"
  WiFi.Radio.3.IEEE80211be.MLDUnitSetting="Assumed"

  $ sleep 15

Check 11be configuration values : {ieee80211be} enabled for Radio, {mld_ap,disable_11be} = {1,0} for interface:

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

Set arbitrary MLDUnit>(-1):

  $ wifi_dm "AccessPoint.5.SSIDReference+.MLDUnit=8" "WiFi." "ba-cli"
  Device.WiFi.SSID.\d+.MLDUnit=8 (re)

  $ sleep 15

Check 11be configuration values : {ieee80211be} enabled for Radio, {mld_ap,disable_11be} = {1,0} for interface:

  $ R "cat /tmp/${rad_name}_hapd.conf | grep ieee80211be"
  ieee80211be=1

  $ get_hapd_config $itf mld_ap
  1

  $ get_hapd_config $itf disable_11be
  0

  $ R "logger -t cram 'MLDUnitSetting: Enabled MLD; MLDUnitSetting=Required'"

Set MLDUnitSetting='NotRequired':

  $ wifi_dm "Radio.*.IEEE80211be.MLDUnitSetting='NotRequired'" "WiFi." "ba-cli"
  WiFi.Radio.1.IEEE80211be.MLDUnitSetting="NotRequired"
  WiFi.Radio.2.IEEE80211be.MLDUnitSetting="NotRequired"
  WiFi.Radio.3.IEEE80211be.MLDUnitSetting="NotRequired"

  $ sleep 5

Check 11be configuration values : {ieee80211be} enabled for Radio, {mld_ap,disable_11be} = {1,0} for interface:

  $ R "cat /tmp/${rad_name}_hapd.conf | grep ieee80211be"
  ieee80211be=1

  $ get_hapd_config $itf mld_ap
  1

  $ get_hapd_config $itf disable_11be
  0

  $ R "logger -t cram 'MLDUnitSetting: Enabled MLD; MLDUnitSetting=NotRequired'"

Set MLDUnitSetting='NotRequired':

  $ wifi_dm "Radio.*.IEEE80211be.MLDUnitSetting='Assumed'" "WiFi." "ba-cli"
  WiFi.Radio.1.IEEE80211be.MLDUnitSetting="Assumed"
  WiFi.Radio.2.IEEE80211be.MLDUnitSetting="Assumed"
  WiFi.Radio.3.IEEE80211be.MLDUnitSetting="Assumed"

  $ sleep 5

Check 11be configuration values : {ieee80211be} enabled for Radio, {mld_ap,disable_11be} = {1,0} for interface:

  $ R "cat /tmp/${rad_name}_hapd.conf | grep ieee80211be"
  ieee80211be=1

  $ get_hapd_config $itf mld_ap
  1

  $ get_hapd_config $itf disable_11be
  0

Disable AccessPoint under test:

  $ enable_ap_sync 5 0
  AccessPoint.\d+.Enable=0 (re)

Restore cram-context MLDUnitSetting : 'Required':

  $ wifi_dm "Radio.*.IEEE80211be.MLDUnitSetting='Required'" "WiFi." "ba-cli"
  WiFi.Radio.1.IEEE80211be.MLDUnitSetting="Required"
  WiFi.Radio.2.IEEE80211be.MLDUnitSetting="Required"
  WiFi.Radio.3.IEEE80211be.MLDUnitSetting="Required"

Restore MLDUnit to defaults:

  $ set_default_ap_mldunit
  $ sleep 5

  $ prplmesh_start

  $ R logger -t cram "$TESTFILE finished!"
