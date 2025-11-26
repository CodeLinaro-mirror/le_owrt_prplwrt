Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting PWHM static puncturing test ..."

Set AutoChannelEnable=0 on all WiFi.Radio. interfaces:

  $ R "ba-cli -j -l WiFi.Radio.*.AutoChannelEnable=0 | sed '/^$/d'"
  [{"WiFi.Radio.1.":{"AutoChannelEnable":0},"WiFi.Radio.2.":{"AutoChannelEnable":0},"WiFi.Radio.3.":{"AutoChannelEnable":0}}]

Set channel to a non DFS one:

  $ R "ba-cli -j -l WiFi.Radio.2.Channel=36 | sed '/^$/d'"
  [{"WiFi.Radio.2.":{"Channel":36}}]

Check default static puncturing configuration:

  $ R "ba-cli -j -l \"WiFi.Radio.*.StaticPuncturing.DisabledSubChannels?\"" | sed '/^$/d'
  [{"WiFi.Radio.2.StaticPuncturing.":{"DisabledSubChannels":""},"WiFi.Radio.1.StaticPuncturing.":{"DisabledSubChannels":""},"WiFi.Radio.3.StaticPuncturing.":{"DisabledSubChannels":""}}]

Stop prplMesh:

  $ R logger -t cram "Stop prplmesh"

  $ R "/etc/init.d/prplmesh stop > /dev/null 2>&1"
  $ sleep 2

Enable private vaps:

  $ R logger -t cram "Enable private vaps"
  $ R "ba-cli -j -l \"WiFi.AccessPoint.1.Enable=1\" | jsonfilter -e @[0]'[*].Enable'"
  1

  $ R "ba-cli -j -l \"WiFi.AccessPoint.2.Enable=1\" | jsonfilter -e @[0]'[*].Enable'"
  1

  $ R "ba-cli -j -l \"WiFi.AccessPoint.3.Enable=1\" | jsonfilter -e @[0]'[*].Enable'"
  1

  $ sleep 10

Check that static puncturing is disabled in hostpad config files:

  $ R "grep punct_bitmap /tmp/wlan*_hapd.conf"
  [1]

Check that SSID are enabled:

  $ R "ba-cli -j -l \"WiFi.AccessPoint.1.SSIDReference+.Status?\" | jsonfilter -e @[0]'[*].Status'"
  Up

  $ R "ba-cli -j -l \"WiFi.AccessPoint.2.SSIDReference+.Status?\" | jsonfilter -e @[0]'[*].Status'"
  Up

  $ R "ba-cli -j -l \"WiFi.AccessPoint.3.SSIDReference+.Status?\" | jsonfilter -e @[0]'[*].Status'"
  Up

Check that 5GHz Radio reports opClass 115 channels 36,40,44,48:

  $ R "ba-cli -j -l \"WiFi.Radio.[OperatingFrequencyBand=='5GHz'].ChannelsInUse?\" | jsonfilter -e @[0]'[*].ChannelsInUse'"
  36,40,44,48

  $ R "ba-cli -l \"WiFi.Radio.[OperatingFrequencyBand=='5GHz'].OperatingChannelBandwidth='80MHz'\" | grep 80"
  80MHz

Interacting with pwhm and hostapd.conf now
Hostapd syntax is bitmap with LSB indicating lowest channel; 0x01 - 36; 0x02 - 40; 0x04 - 44; 0x08 - 48; and sums thereof

Test static puncturing on 5GHz band:

  $ R logger -t cram "Test static puncturing on 5GHz band"
  $ R logger -t cram "disable channels 40,44"
  $ R "ba-cli -j -l \"WiFi.Radio.[OperatingFrequencyBand=='5GHz'].StaticPuncturing.DisabledSubChannels='40,44'\" | jsonfilter -e @[0]'[*].DisabledSubChannels'"
  40,44

  $ sleep 5

  $ R "cat /tmp/wlan2_hapd.conf | grep punct"
  punct_bitmap=6

  $ R logger -t cram "disable channels 40,48"
  $ R "ba-cli -j -l \"WiFi.Radio.[OperatingFrequencyBand=='5GHz'].StaticPuncturing.DisabledSubChannels='40,48'\" | jsonfilter -e @[0]'[*].DisabledSubChannels'"
  40,48

  $ sleep 5

  $ R "cat /tmp/wlan2_hapd.conf | grep punct"
  punct_bitmap=10

  $ R logger -t cram "disable channels 40,44,48"
  $ R "ba-cli -j -l \"WiFi.Radio.[OperatingFrequencyBand=='5GHz'].StaticPuncturing.DisabledSubChannels='40,44,48'\" | jsonfilter -e @[0]'[*].DisabledSubChannels'"
  40,44,48

  $ sleep 5

  $ R "cat /tmp/wlan2_hapd.conf | grep punct"
  punct_bitmap=14

  $ R logger -t cram "disable channels 44"
  $ R "ba-cli -j -l \"WiFi.Radio.[OperatingFrequencyBand=='5GHz'].StaticPuncturing.DisabledSubChannels='44'\" | jsonfilter -e @[0]'[*].DisabledSubChannels'"
  44

  $ sleep 5

  $ R "cat /tmp/wlan2_hapd.conf | grep punct"
  punct_bitmap=4

Test static puncturing on 6GHz band:

  $ R logger -t cram "Test static puncturing on 6GHz band"
  $ R "ba-cli -l \"WiFi.Radio.[OperatingFrequencyBand=='6GHz'].OperatingChannelBandwidth='320MHz-1'\" | grep 320"
  320MHz-1

  $ sleep 10

Check that 6GHz Radio reports opClass 137 channels, 16 in total:

  $ R "ba-cli -j -l \"WiFi.Radio.[OperatingFrequencyBand=='6GHz'].ChannelsInUse?\" | jsonfilter -e @[0]'[*].ChannelsInUse'"
  1,5,9,13,17,21,25,29,33,37,41,45,49,53,57,61

Disable top 4 channels : 49,53,57,61; from python:
>>> (1<<15) + (1<<14) + (1<<13) + (1<<12)
61440

  $ R logger -t cram "disable channels 49,53,57,61"
  $ R "ba-cli -j -l \"WiFi.Radio.[OperatingFrequencyBand=='6GHz'].StaticPuncturing.DisabledSubChannels='49,53,57,61'\" | jsonfilter -e @[0]'[*].DisabledSubChannels'"
  49,53,57,61

  $ sleep 5

  $ R "cat /tmp/wlan4_hapd.conf | grep punct"
  punct_bitmap=61440

  $ R "ba-cli -j -l \"WiFi.Radio.3.Channel='37'\" | jsonfilter -e @[0]'[*].Channel'"
  37

Disable all channels except 37:

  $ R logger -t cram "disable all channels except 37"
  $ R "ba-cli -j -l \"WiFi.Radio.[OperatingFrequencyBand=='6GHz'].StaticPuncturing.DisabledSubChannels='1,5,9,13,17,21,25,29,33,41,45,49,53,57,61'\" | jsonfilter -e @[0]'[*].DisabledSubChannels'"
  1,5,9,13,17,21,25,29,33,41,45,49,53,57,61

  $ R sleep 5

  $ R "cat /tmp/wlan4_hapd.conf | grep punct"
  punct_bitmap=65023

MAX Uint16 : 65535 - 65023 is 512 : (2^(10-1)), i.e., all except channel number 10

Push 0b0000 0d00 - clear Radio.StaticPuncturing.DisabledSubChannels list:

  $ R logger -t cram "clear all DisabledSubChannels"
  $ R "ba-cli -j -l \"WiFi.Radio.*.StaticPuncturing.DisabledSubChannels=''\" > /dev/null"

Disable all AccessPoints (implicitly - the ones that was enabled for this test):

  $ R "ba-cli \"WiFi.AccessPoint.*.Enable=0\" > /dev/null"

Restart prplMesh:

  $ R "( /etc/init.d/prplmesh gateway_mode ; sleep 2 ) > /tmp/prplmesh-gw-mode.log 2>&1 ; logger -t prplmesh-gateway-mode < /tmp/prplmesh-gw-mode.log"

  $ R "ubus -t 60 wait_for X_PRPLWARE-COM_WiFiController.Network.Device.1"

Check that prplmesh is running:

  $ R "ps axw" | sed -nE 's/.*(\/opt\/prplmesh\/bin.*)/\1/p' | LC_ALL=C sort
  /opt/prplmesh/bin/beerocks_agent
  /opt/prplmesh/bin/beerocks_controller
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan0
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan2
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan4
  /opt/prplmesh/bin/beerocks_vendor_message
  /opt/prplmesh/bin/ieee1905_transport

  $ R logger -t cram "Test finished!"
