Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R "logger -t cram 'Starting MLDUnitSetting test ...'"

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=0 | grep '.'"
  0

SIlently set invalid MLDUnits for all SSIDs
  $ R "ba-cli WiFi.SSID.*.MLDUnit=-1 > /dev/null"

  $ sleep 2

Check 11be is enabled
  $ R "ba-cli -al WiFi.Radio.2.OperatingStandards? | grep '.'"
  a,n,ac,ax,be
//$ R "ba-cli WiFi.Radio.2.OperatingStandards='b,g,n,ac,ax,be' > /dev/null"

Check MLO Support
  $ R "ba-cli 'WiFi.Radio.2.IEEE80211_Caps?' | grep MLO | wc -l"
  1

Enable AccessPoint Under Test
  $ enable_ap_sync 3 1
  AccessPoint.\d+.Enable=1 (re)

  $ sleep 5

  $ R "ba-cli -l Device.WiFi.AccessPoint.3.SSIDReference+.Name? | grep '.'"
  wlan1.1

Used later to check hostapd config file
  $ itf=$(R "ba-cli -l Device.WiFi.AccessPoint.3.SSIDReference+.Name?" | sed '/^$/d')

Subset A : Invalid MLDUnit

  $ R "logger -t cram 'MLDUnitSetting Invalid MLDUnit; MLDUnitSetting=NotRequired'"

Set Invalid MLDUnit
  $ R "ba-cli -l \"WiFi.AccessPoint.3.SSIDReference+.MLDUnit=-1\" | sed '/^$/d'"
  -1

Set MLDUnitSetting='NotRequired'
  $ R "ba-cli -l -a \"protected; WiFi.Radio.2.IEEE80211be.MLDUnitSetting='NotRequired'\" | grep NotRequired"
  NotRequired

  $ sleep 15

  $ R "cat /tmp/wlan1_hapd.conf | grep -E \"ieee80211be|mld_ap|disable_11be\""
  ieee80211be=1
  disable_11be=0
  mld_ap=0

  $ rad_be=$(R "cat /tmp/wlan1_hapd.conf | grep ieee80211be | cut -d '=' -f2")

  $ itf_mld=$(get_hapd_config $itf mld_ap)

  $ itf_disable_be=$(get_hapd_config $itf disable_11be)

  $ mld_conf=$((rad_be*100+$itf_mld*10+$itf_disable_be))

  $ echo $mld_conf
  100

  $ R "logger -t cram 'MLDUnitSetting Invalid MLDUnit; MLDUnitSetting=Required'"

Set MLDUnitSetting='Required'
  $ R "ba-cli -l -a \"protected; WiFi.Radio.2.IEEE80211be.MLDUnitSetting='Required'\" | grep Required"
  Required

  $ sleep 15

  $ R "cat /tmp/wlan1_hapd.conf | grep -E \"ieee80211be|mld_ap|disable_11be\""
  ieee80211be=0

Check 11be configuration : ieee80211be absent, other options absent as well
  $ R "cat /tmp/wlan1_hapd.conf | grep ieee80211be"
  ieee80211be=0

should be absent:
  $ get_hapd_config $itf mld_ap
  Option 'mld_ap' not found

  $ get_hapd_config $itf disable_11be
  Option 'disable_11be' not found

  $ R "logger -t cram 'MLDUnitSetting Invalid MLDUnit; MLDUnitSetting=Assumed'"

Set MLDUnitSetting='Assumed'; with invalid MLDUnit, this should still result in WiFi7 - EHT + MLO configuration
  $ R "ba-cli -l -a \"protected; WiFi.Radio.2.IEEE80211be.MLDUnitSetting='Assumed'\" | grep Assumed"
  Assumed

  $ sleep 15

  $ R "cat /tmp/wlan1_hapd.conf | grep -E \"ieee80211be|mld_ap|disable_11be\""
  ieee80211be=1
  mld_ap=1
  disable_11be=0

  $ rad_be=$(R "cat /tmp/wlan1_hapd.conf | grep ieee80211be | cut -d '=' -f2")

  $ itf_mld=$(get_hapd_config $itf mld_ap)

  $ itf_disable_be=$(get_hapd_config $itf disable_11be)

  $ mld_conf=$((rad_be*100+$itf_mld*10+$itf_disable_be))

  $ echo $mld_conf
  110

Subset B : Valid MLDUnit

  $ R "logger -t cram 'MLDUnitSetting MLDUnit; MLDUnitSetting=Assumed'"

Set arbitrary Valid MLDUnit
  $ R "ba-cli 'WiFi.AccessPoint.3.SSIDReference+.MLDUnit=8' | grep -v '>' | grep '='"
  Device.WiFi.SSID.*.MLDUnit=8 (re)

  $ sleep 15

  $ R "cat /tmp/wlan1_hapd.conf | grep -E \"ieee80211be|mld_ap|disable_11be\""
  ieee80211be=1
  mld_ap=1
  disable_11be=0

  $ rad_be=$(R "cat /tmp/wlan1_hapd.conf | grep ieee80211be | cut -d '=' -f2")

  $ itf_mld=$(get_hapd_config $itf mld_ap)

  $ itf_disable_be=$(get_hapd_config $itf disable_11be)

  $ mld_conf=$((rad_be*100+$itf_mld*10+$itf_disable_be))

  $ echo $mld_conf
  110

  $ R "logger -t cram 'MLDUnitSetting MLDUnit; MLDUnitSetting=Required'"

Set MLDUnitSetting='Required'
  $ R "ba-cli -l -a \"protected; WiFi.Radio.2.IEEE80211be.MLDUnitSetting='Required'\" | grep Required"
  Required

  $ sleep 15

  $ R "cat /tmp/wlan1_hapd.conf | grep -E \"ieee80211be|mld_ap|disable_11be\""
  ieee80211be=1
  mld_ap=1
  disable_11be=0

  $ rad_be=$(R "cat /tmp/wlan1_hapd.conf | grep ieee80211be | cut -d '=' -f2")

  $ itf_mld=$(get_hapd_config $itf mld_ap)

  $ itf_disable_be=$(get_hapd_config $itf disable_11be)

  $ mld_conf=$((rad_be*100+$itf_mld*10+$itf_disable_be))

  $ echo $mld_conf
  110

  $ R "logger -t cram 'MLDUnitSetting MLDUnit; MLDUnitSetting=NotRequired'"

Set MLDUnitSetting='NotRequired'
  $ R "ba-cli -l -a \"protected; WiFi.Radio.2.IEEE80211be.MLDUnitSetting='NotRequired'\" | grep NotRequired"
  NotRequired

  $ sleep 15

  $ R "cat /tmp/wlan1_hapd.conf | grep -E \"ieee80211be|mld_ap|disable_11be\""
  ieee80211be=1
  mld_ap=1
  disable_11be=0

Check 11be configuration : 11BE enabled for Radio, mld_ap enabled for interface
  $ R "cat /tmp/wlan1_hapd.conf | grep ieee80211be"
  ieee80211be=1

  $ get_hapd_config $itf mld_ap
  1

  $ get_hapd_config $itf disable_11be
  0

Restore default MLDUnitSetting : 'Assumed'
  $ R "ba-cli -l -a \"protected; WiFi.Radio.2.IEEE80211be.MLDUnitSetting='Assumed'\" | grep Assumed"
  Assumed
