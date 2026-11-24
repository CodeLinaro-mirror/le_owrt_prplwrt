Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting $TESTFILE"

  $ check_wifi_defaults
  $ testbed_set_wifi_defaults

  $ prplmesh_stop

Check default static puncturing configuration:

  $ R "ba-cli -j -l \"WiFi.Radio.*.StaticPuncturing.DisabledSubChannels?\"" | sed '/^$/d'
  [{"WiFi.Radio.2.StaticPuncturing.":{"DisabledSubChannels":""},"WiFi.Radio.1.StaticPuncturing.":{"DisabledSubChannels":""},"WiFi.Radio.3.StaticPuncturing.":{"DisabledSubChannels":""}}]

Enable private vaps:

  $ R logger -t cram "Enable private vaps"
  $ R "ba-cli -j -l \"Device.WiFi.AccessPoint.1.Enable=1\" | jsonfilter -e @[0]'[*].Enable'"
  1

  $ R "ba-cli -j -l \"Device.WiFi.AccessPoint.3.Enable=1\" | jsonfilter -e @[0]'[*].Enable'"
  1

  $ R "ba-cli -j -l \"Device.WiFi.AccessPoint.5.Enable=1\" | jsonfilter -e @[0]'[*].Enable'"
  1

  $ sleep 10

Check that static puncturing is disabled in hostpad config files:

  $ R "grep punct_bitmap /tmp/wlan*_hapd.conf"
  [1]

Check that SSID are enabled:

  $ R "ba-cli -j -l \"Device.WiFi.AccessPoint.1.SSIDReference+.Status?\" | jsonfilter -e @[0]'[*].Status'"
  Up

  $ R "ba-cli -j -l \"Device.WiFi.AccessPoint.3.SSIDReference+.Status?\" | jsonfilter -e @[0]'[*].Status'"
  Up

  $ R "ba-cli -j -l \"Device.WiFi.AccessPoint.5.SSIDReference+.Status?\" | jsonfilter -e @[0]'[*].Status'"
  Up

Check that 5GHz Radio reports opClass 115 channels 36,40,44,48:

  $ R "ba-cli -j -l \"Device.WiFi.Radio.[OperatingFrequencyBand=='5GHz'].ChannelsInUse?\" | jsonfilter -e @[0]'[*].ChannelsInUse'"
  36,40,44,48

  $ R "ba-cli -l \"Device.WiFi.Radio.[OperatingFrequencyBand=='5GHz'].OperatingChannelBandwidth='80MHz'\" | grep 80"
  80MHz

Interacting with pwhm and hostapd.conf now
Hostapd syntax is bitmap with LSB indicating lowest channel; 0x01 - 36; 0x02 - 40; 0x04 - 44; 0x08 - 48; and sums thereof

Test static puncturing on 5GHz band:

  $ R logger -t cram "Test static puncturing on 5GHz band"
  $ R logger -t cram "disable channels 44"
  $ R "ba-cli -j -l \"Device.WiFi.Radio.[OperatingFrequencyBand=='5GHz'].StaticPuncturing.DisabledSubChannels='44'\" | jsonfilter -e @[0]'[*].DisabledSubChannels'"
  44

  $ sleep 5

  $ R "cat /tmp/wlan1_hapd.conf | grep punct"
  punct_bitmap=4

Try to set invalid DisabledSubChannels:
On 5GHz with 80MHz bandwith only one channel can be punctured (IEEE Std 802.11be - Part 11 - Table 36-30)

  $ R "ba-cli \"Device.WiFi.Radio.[OperatingFrequencyBand=='5GHz'].StaticPuncturing.DisabledSubChannels='40,44'\"" | sed '/^$/d' | grep ERROR
  .*ERROR.* (re)

Test static puncturing on 6GHz band:

  $ R logger -t cram "Test static puncturing on 6GHz band"
  $ R "ba-cli -l \"Device.WiFi.Radio.[OperatingFrequencyBand=='6GHz'].OperatingChannelBandwidth='320MHz-1'\" | grep 320"
  320MHz-1

  $ sleep 10

Check that 6GHz Radio reports opClass 137 channels, 16 in total:

  $ R "ba-cli -j -l \"Device.WiFi.Radio.[OperatingFrequencyBand=='6GHz'].ChannelsInUse?\" | jsonfilter -e @[0]'[*].ChannelsInUse'"
  1,5,9,13,17,21,25,29,33,37,41,45,49,53,57,61

Disable top 2 channels : 57,61; from python:
>>> (1<<15) + (1<<14)
49152

  $ R logger -t cram "disable channels 57,61"
  $ R "ba-cli -j -l \"WiFi.Radio.[OperatingFrequencyBand=='6GHz'].StaticPuncturing.DisabledSubChannels='57,61'\" | jsonfilter -e @[0]'[*].DisabledSubChannels'"
  57,61

  $ sleep 5

  $ R "cat /tmp/wlan0_hapd.conf | grep punct"
  punct_bitmap=49152

  $ R "ba-cli -j -l \"Device.WiFi.Radio.3.Channel='37'\" | jsonfilter -e @[0]'[*].Channel'"
  37

Try to set invalid DisabledSubChannels:

  $ R "ba-cli \"Device.WiFi.Radio.[OperatingFrequencyBand=='6GHz'].StaticPuncturing.DisabledSubChannels='1,5,9,13,17,21,25,29,33,41,45,49,53,57,61'\"" | sed '/^$/d' | grep ERROR
  .*ERROR.* (re)

Push 0b0000 0d00 - clear Radio.StaticPuncturing.DisabledSubChannels list:

  $ R logger -t cram "clear all DisabledSubChannels"
  $ R "ba-cli -j -l \"Device.WiFi.Radio.*.StaticPuncturing.DisabledSubChannels=''\" > /dev/null"

Disable all AccessPoints (implicitly - the ones that was enabled for this test):

  $ R "ba-cli \"Device.WiFi.AccessPoint.*.Enable=0\" > /dev/null"

Wait VAP disabled completely:

  $ sleep 15

Restart prplMesh:

  $ prplmesh_start

  $ R logger -t cram "$TESTFILE finished!"
