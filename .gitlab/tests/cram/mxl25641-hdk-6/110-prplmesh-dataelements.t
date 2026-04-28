Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

Set AutoChannelEnable=0 on all Device.WiFi.Radio. interfaces:

  $ R "ba-cli -j -l WiFi.Radio.*.AutoChannelEnable=0 | sed '/^$/d'"
  [{"WiFi.Radio.1.":{"AutoChannelEnable":0},"WiFi.Radio.2.":{"AutoChannelEnable":0},"WiFi.Radio.3.":{"AutoChannelEnable":0}}]

Set channel to a non DFS one:

  $ R "usp-cli -j -l Device.WiFi.Radio.2.Channel=36 | sed '/^$/d'"
  [{"Device.WiFi.Radio.2.":{"Channel":36}}]

  $ sleep 5

Configure controller, requires PPM-3022 to work:

  $ R logger -t cram "Stop prplmesh"

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=0" | tr -d '\n'
  0 (no-eol)

  $ sleep 2
  $ R "sed -i 's/use_dataelements_vap_configs=0/use_dataelements_vap_configs=1/g' /opt/prplmesh/config/beerocks_controller.conf"

Restart prplmesh:

  $ R logger -t cram "Restart prplmesh"

  $ R "ba-cli X_PRPLWARE-COM_ProcessManager.PrplMesh.ManagementMode=Multi-AP-Controller-and-Agent"  > /dev/null

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=1" | tr -d '\n'
  1 (no-eol)

  $ R "ubus -t 60 wait_for X_PRPLWARE-COM_WiFiController.Network.Device.1"

First call of AccessPointCommit, controller should push empty config to agents:

  $ R logger -t cram "first call of AccessPointCommit pushes empty config, global teardown"

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network AccessPointCommit"
  {"retval":""}
  {}
  {"amxd-error-code":0}

  $ R sleep 15

Check all AccessPoint.SSIDReference+ instances are disabled

  $ get_ssid_status
  Down
  Down
  Down
  Down
  Down
  Down
  Down
  Down
  Down

  $ get_ssid_ssid
  backhaul_(4C:BA:7D|A8:C2:46|AC:9A:96):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  backhaul_(4C:BA:7D|A8:C2:46|AC:9A:96):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  backhaul_(4C:BA:7D|A8:C2:46|AC:9A:96):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  prplOS
  prplOS
  prplOS
  prplOS-guest
  prplOS-guest
  prplOS-guest


Create instances of Network.AccessPoint and push them to the agent:

  $ R logger -t cram "create instances of Network.AccessPoint and push them to the agent"

First 2 Instances : Priv and Guest for 2.4/5GHz

  $ R "ba-cli \"X_PRPLWARE-COM_WiFiController.Network.AccessPoint+(MLDUnit=-1,Band2_4G=1,Band5GH=1,Band5GL=1,MultiApMode=\"Fronthaul+Backhaul\",X_PRPLWARE_VapType=\"home\",SSID=\"prplOSpriv110\",Security.ModeEnabled=\"WPA3-Personal\",Security.KeyPassphrase=\"passwordPriv\",Enable=1)\"" | tail -n +2 | sed '/^$/d'
  X_PRPLWARE-COM_WiFiController.Network.AccessPoint.* (re)

  $ R "ba-cli \"X_PRPLWARE-COM_WiFiController.Network.AccessPoint+(MLDUnit=-1,Band2_4G=1,Band5GH=1,Band5GL=1,MultiApMode=\"Fronthaul\",X_PRPLWARE_VapType=\"guest\",SSID=\"prplOSguest110\",Security.ModeEnabled=\"WPA2-Personal\",Security.KeyPassphrase=\"passwordGuest\",Enable=1)\"" | tail -n +2 | sed '/^$/d'
  X_PRPLWARE-COM_WiFiController.Network.AccessPoint.* (re)

Last 2 Instances : Priv and Guest for 6GHz

  $ R "ba-cli \"X_PRPLWARE-COM_WiFiController.Network.AccessPoint+(MLDUnit=-1,Band6G=1,MultiApMode=\"Fronthaul+Backhaul\",X_PRPLWARE_VapType=\"home\",SSID=\"prplOSpriv110\",Security.ModeEnabled=\"WPA3-Personal\",Security.KeyPassphrase=\"passwordPriv\",Enable=1)\"" | tail -n +2 | sed '/^$/d'
  X_PRPLWARE-COM_WiFiController.Network.AccessPoint.* (re)

  $ R "ba-cli \"X_PRPLWARE-COM_WiFiController.Network.AccessPoint+(MLDUnit=-1,Band6G=1,MultiApMode=\"Fronthaul\",X_PRPLWARE_VapType=\"guest\",SSID=\"prplOSguest110\",Security.ModeEnabled=\"WPA3-Personal\",Security.KeyPassphrase=\"passwordGuest\",Enable=1)\"" | tail -n +2 | sed '/^$/d'
  X_PRPLWARE-COM_WiFiController.Network.AccessPoint.* (re)

  $ R "ba-cli \"X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit()\"" | tail -n +2 |  sed '/^$/d'
  X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit() returned
  [
      ""
  ]

  $ sleep 15

Check that wireless is operating:

  $ get_ssid_status
  Down
  Down
  Down
  Up
  Up
  Up
  Up
  Up
  Up

  $ get_ssid_ssid
  backhaul_(4C:BA:7D|A8:C2:46):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  backhaul_(4C:BA:7D|A8:C2:46):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  backhaul_(4C:BA:7D|A8:C2:46):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  prplOSguest110
  prplOSguest110
  prplOSguest110
  prplOSpriv110
  prplOSpriv110
  prplOSpriv110

Check that prplmesh processes are running:

  $ R logger -t cram "Check that prplmesh processes are running"

  $ R "ps axw" | sed -nE 's/.*(\/opt\/prplmesh\/bin.*)/\1/p' | LC_ALL=C sort
  /opt/prplmesh/bin/beerocks_agent
  /opt/prplmesh/bin/beerocks_controller
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan0
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan2
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan4
  /opt/prplmesh/bin/beerocks_vendor_message
  /opt/prplmesh/bin/ieee1905_transport

Check that prplmesh is operational:

  $ R logger -t cram "Check that prplmesh is operational"

  $ R "ba-cli -a X_PRPLWARE-COM_Agent.Info.CurrentState? | grep '='"
  X_PRPLWARE-COM_Agent.Info.CurrentState="OPERATIONAL \(15\)"

  $ R "ba-cli -a X_PRPLWARE-COM_Agent.Info.BestState? | grep '='"
  X_PRPLWARE-COM_Agent.Info.BestState="OPERATIONAL \(15\)"

Check Fronthaul Processes CurrentState and BestState

  $ R "ba-cli -a X_PRPLWARE-COM_Agent.Info.Fronthaul.*.CurrentState? | grep '='"
  X_PRPLWARE-COM_Agent.Info.Fronthaul.1.CurrentState="OPERATIONAL \(4\)"
  X_PRPLWARE-COM_Agent.Info.Fronthaul.2.CurrentState="OPERATIONAL \(4\)"
  X_PRPLWARE-COM_Agent.Info.Fronthaul.3.CurrentState="OPERATIONAL \(4\)"

  $ R "ba-cli -a X_PRPLWARE-COM_Agent.Info.Fronthaul.*.BestState? | grep '='"
  X_PRPLWARE-COM_Agent.Info.Fronthaul.1.BestState="OPERATIONAL \(4\)"
  X_PRPLWARE-COM_Agent.Info.Fronthaul.2.BestState="OPERATIONAL \(4\)"
  X_PRPLWARE-COM_Agent.Info.Fronthaul.3.BestState="OPERATIONAL \(4\)"

  $ dm_check_prplmesh_status
  X_PRPLWARE-COM_ProcessManager.PrplMesh.CertificationMode=0
  X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=1
  X_PRPLWARE-COM_ProcessManager.PrplMesh.FaultCode="NoFault"
  X_PRPLWARE-COM_ProcessManager.PrplMesh.ManagementMode="Multi-AP-Controller-and-Agent"
  X_PRPLWARE-COM_ProcessManager.PrplMesh.Status="Active"

Check Controller knownled about network

  $ dm_check_controller_number_of_bsses_per_radio
  X_PRPLWARE-COM_WiFiController.Network.Device.1.Radio.1.BSSNumberOfEntries=2
  X_PRPLWARE-COM_WiFiController.Network.Device.1.Radio.2.BSSNumberOfEntries=2
  X_PRPLWARE-COM_WiFiController.Network.Device.1.Radio.3.BSSNumberOfEntries=2

Check Controller Known SSID List (Transported via AP Operational BSS TLV)

  $ R "ba-cli -l \"X_PRPLWARE-COM_WiFiController.Network.Device.1.Radio.*.BSS.*.SSID?\"" | sed '/^$/d' | sort
  prplOSguest110
  prplOSguest110
  prplOSguest110
  prplOSpriv110
  prplOSpriv110
  prplOSpriv110

Check current security modes (AccessPoints 7, 8, 9 are not part of the test, no change expected there)

  $ R "ba-cli -a 'WiFi.AccessPoint.*.Security.ModeEnabled?' | grep -v '>' | grep '.'"
  WiFi.AccessPoint.1.Security.ModeEnabled="WPA3-Personal"
  WiFi.AccessPoint.2.Security.ModeEnabled="WPA3-Personal"
  WiFi.AccessPoint.3.Security.ModeEnabled="WPA3-Personal"
  WiFi.AccessPoint.4.Security.ModeEnabled="WPA2-Personal"
  WiFi.AccessPoint.5.Security.ModeEnabled="WPA2-Personal"
  WiFi.AccessPoint.6.Security.ModeEnabled="WPA3-Personal"
  WiFi.AccessPoint.7.Security.ModeEnabled="WPA3-Personal-Transition"
  WiFi.AccessPoint.8.Security.ModeEnabled="WPA3-Personal-Transition"
  WiFi.AccessPoint.9.Security.ModeEnabled="WPA3-Personal"


Restore Default Configuration through NBAPI:

2.4/5GHz priv: Security.ModeEnabled, MultiApType, Passphrase, SSID

  $ R "ba-cli -l X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Security.ModeEnabled=\"WPA3-Personal-Transition\"" | sed '/^$/d'
  WPA3-Personal-Transition

  $ R "ba-cli -l X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.MultiApMode=\"Fronthaul\"" | sed '/^$/d'
  Fronthaul

  $ R "ba-cli -l X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Security.KeyPassphrase=\"password\"" | sed '/^$/d'
  password

  $ R "ba-cli -l X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.SSID=\"prplOS\"" | sed '/^$/d'
  prplOS

2.4/5GHz guest: Security.ModeEnabled, SSID

  $ R "ba-cli -l X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2.Security.ModeEnabled=\"WPA3-Personal-Transition\"" | sed '/^$/d'
  WPA3-Personal-Transition

  $ R "ba-cli -l X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2.SSID=\"prplOS-guest\"" | sed '/^$/d'
  prplOS-guest

6GHz priv : MultiApType, Passphrase, SSID

  $ R "ba-cli -l X_PRPLWARE-COM_WiFiController.Network.AccessPoint.3.MultiApMode=\"Fronthaul\"" | sed '/^$/d'
  Fronthaul

  $ R "ba-cli -l X_PRPLWARE-COM_WiFiController.Network.AccessPoint.3.Security.KeyPassphrase=\"password\"" | sed '/^$/d'
  password

  $ R "ba-cli -l X_PRPLWARE-COM_WiFiController.Network.AccessPoint.3.SSID=\"prplOS\"" | sed '/^$/d'
  prplOS

6GHz guest : SSID

  $ R "ba-cli -l X_PRPLWARE-COM_WiFiController.Network.AccessPoint.4.SSID=\"prplOS-guest\"" | sed '/^$/d'
  prplOS-guest

  $ R "ba-cli \"X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit()\"" | tail -n +2 | sed '/^$/d'
  X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit() returned
  [
      ""
  ]

Empirical 10s value for sleep; pwhm datamodel takes 'some time' to propagate back to controller

  $ sleep 20

  $ R "ba-cli -l \"X_PRPLWARE-COM_WiFiController.Network.Device.1.Radio.*.BSS.*.SSID?\"" | sed '/^$/d' | sort
  prplOS
  prplOS
  prplOS
  prplOS-guest
  prplOS-guest
  prplOS-guest

To disable wireless, disable instances of Network.AccessPoint{i} and call AccessPointCommit():

  $ R logger -t cram "Stop wireless"

  $ R "ba-cli -l 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.*.Enable=0'" |  sed '/^$/d'
  0
  0
  0
  0

  $ R "ba-cli \"X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit()\"" | tail -n +2 |  sed '/^$/d'
  X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit() returned
  [
      ""
  ]

  $ sleep 10

Check that SSIDs are disabled in pwhm:

  $ get_ssid_status
  Down
  Down
  Down
  Down
  Down
  Down
  Down
  Down
  Down

  $ dm_check_controller_number_of_bsses_per_radio
  X_PRPLWARE-COM_WiFiController.Network.Device.1.Radio.1.BSSNumberOfEntries=0
  X_PRPLWARE-COM_WiFiController.Network.Device.1.Radio.2.BSSNumberOfEntries=0
  X_PRPLWARE-COM_WiFiController.Network.Device.1.Radio.3.BSSNumberOfEntries=0

Stop prplmesh

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=0" | tr -d '\n'
  0 (no-eol)

Check that SSID names are back to defaults:

  $ get_ssid_ssid
  backhaul_(4C:BA:7D|A8:C2:46):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  backhaul_(4C:BA:7D|A8:C2:46):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  backhaul_(4C:BA:7D|A8:C2:46):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  prplOS
  prplOS
  prplOS
  prplOS-guest
  prplOS-guest
  prplOS-guest

Check default security modes

  $ R "ba-cli -a 'WiFi.AccessPoint.*.Security.ModeEnabled?' | grep -v '>' | grep '.'"
  WiFi.AccessPoint.1.Security.ModeEnabled="WPA3-Personal-Transition"
  WiFi.AccessPoint.2.Security.ModeEnabled="WPA3-Personal-Transition"
  WiFi.AccessPoint.3.Security.ModeEnabled="WPA3-Personal"
  WiFi.AccessPoint.4.Security.ModeEnabled="WPA3-Personal-Transition"
  WiFi.AccessPoint.5.Security.ModeEnabled="WPA3-Personal-Transition"
  WiFi.AccessPoint.6.Security.ModeEnabled="WPA3-Personal"
  WiFi.AccessPoint.7.Security.ModeEnabled="WPA3-Personal-Transition"
  WiFi.AccessPoint.8.Security.ModeEnabled="WPA3-Personal-Transition"
  WiFi.AccessPoint.9.Security.ModeEnabled="WPA3-Personal"

Restore Controller 'VAP Configuration Source'-configuration to default

  $ R "sed -i 's/use_dataelements_vap_configs=1/use_dataelements_vap_configs=0/g' /opt/prplmesh/config/beerocks_controller.conf"

Restart prplmesh:

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=1" | tr -d '\n'
  1 (no-eol)

Check the default ChipsetVendor param configurations:

  $ R logger -t cram "Check the default ChipsetVendor param configurations:"
  $ R "ba-cli -j -l WiFi.Radio.*.ChipsetVendor?0 | jsonfilter -e @[0]'[*].ChipsetVendor'"
  MaxLinear
  MaxLinear
  MaxLinear
