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
  backhaul_(AC:91:9B|58:E4:03):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  backhaul_(AC:91:9B|58:E4:03):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  backhaul_(AC:91:9B|58:E4:03):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  prplOS
  prplOS
  prplOS
  prplOS-guest
  prplOS-guest
  prplOS-guest


Create instances of Network.AccessPoint and push them to the agent:

  $ R logger -t cram "create instances of Network.AccessPoint and push them to the agent"

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint _add"
  {"object":"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.","index":1,"name":"1","parameters":{},"path":"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1."}
  {}
  {"amxd-error-code":0}

Create first instance of Network.AccessPoint for priv 2.4/5 GHz VAPs:
Since no persistent storage of NbAPI Network subsection, always index:1 after controller restart:

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1 _set '{\"parameters\":{\"Band2_4G\":1,\"Band5GH\":1,\"Band5GL\":1,\"Band6G\":0}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.":{"Band5GH":true,"Band6G":false,"Band2_4G":true,"Band5GL":true}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1 _set '{\"parameters\":{\"MultiApMode\":\"Fronthaul+Backhaul\",\"X_PRPLWARE_VapType\":\"home\"}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.":{"X_PRPLWARE_VapType":"home","MultiApMode":"Fronthaul+Backhaul"}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Security _set '{\"parameters\":{\"ModeEnabled\":\"WPA2-Personal\",\"KeyPassphrase\":\"passwordPriv\"}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Security.":{"KeyPassphrase":"passwordPriv","ModeEnabled":"WPA2-Personal"}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1 _set '{\"parameters\":{\"SSID\":\"prplOSpriv110\"}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.":{"SSID":"prplOSpriv110"}}
  {}
  {"amxd-error-code":0}

Create second instance of Network.AccessPoint for guest 2.4/5 GHz VAPs:

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint _add"
  {"object":"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2.","index":2,"name":"2","parameters":{},"path":"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2."}
  {}
  {"amxd-error-code":0}
  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2 _set '{\"parameters\":{\"Band2_4G\":1,\"Band5GH\":1,\"Band5GL\":1,\"Band6G\":0}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2.":{"Band5GH":true,"Band6G":false,"Band2_4G":true,"Band5GL":true}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2 _set '{\"parameters\":{\"MultiApMode\":\"Fronthaul\",\"X_PRPLWARE_VapType\":\"guest\"}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2.":{"X_PRPLWARE_VapType":"guest","MultiApMode":"Fronthaul"}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2.Security _set '{\"parameters\":{\"ModeEnabled\":\"WPA2-Personal\",\"KeyPassphrase\":\"passwordGuest\"}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2.Security.":{"KeyPassphrase":"passwordGuest","ModeEnabled":"WPA2-Personal"}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2 _set '{\"parameters\":{\"SSID\":\"prplOSguest110\"}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2.":{"SSID":"prplOSguest110"}}
  {}
  {"amxd-error-code":0}

Create third instance of Network.AccessPoint for private 6GHz VAP:

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint _add"
  {"object":"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.3.","index":3,"name":"3","parameters":{},"path":"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.3."}
  {}
  {"amxd-error-code":0}
  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.3 _set '{\"parameters\":{\"Band2_4G\":0,\"Band5GH\":0,\"Band5GL\":0,\"Band6G\":1}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.3.":{"Band5GH":false,"Band6G":true,"Band2_4G":false,"Band5GL":false}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.3 _set '{\"parameters\":{\"MultiApMode\":\"Fronthaul+Backhaul\",\"X_PRPLWARE_VapType\":\"home\"}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.3.":{"X_PRPLWARE_VapType":"home","MultiApMode":"Fronthaul+Backhaul"}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.3.Security _set '{\"parameters\":{\"ModeEnabled\":\"WPA3-Personal\",\"KeyPassphrase\":\"passwordPriv\"}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.3.Security.":{"KeyPassphrase":"passwordPriv","ModeEnabled":"WPA3-Personal"}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.3 _set '{\"parameters\":{\"SSID\":\"prplOSpriv110\"}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.3.":{"SSID":"prplOSpriv110"}}
  {}
  {"amxd-error-code":0}

Create fourth instance of Network.AccessPoint for guest 6GHz VAP:

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint _add"
  {"object":"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.4.","index":4,"name":"4","parameters":{},"path":"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.4."}
  {}
  {"amxd-error-code":0}
  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.4 _set '{\"parameters\":{\"Band2_4G\":0,\"Band5GH\":0,\"Band5GL\":0,\"Band6G\":1}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.4.":{"Band5GH":false,"Band6G":true,"Band2_4G":false,"Band5GL":false}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.4 _set '{\"parameters\":{\"MultiApMode\":\"Fronthaul\",\"X_PRPLWARE_VapType\":\"guest\"}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.4.":{"X_PRPLWARE_VapType":"guest","MultiApMode":"Fronthaul"}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.4.Security _set '{\"parameters\":{\"ModeEnabled\":\"WPA3-Personal\",\"KeyPassphrase\":\"passwordGuest\"}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.4.Security.":{"KeyPassphrase":"passwordGuest","ModeEnabled":"WPA3-Personal"}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.4 _set '{\"parameters\":{\"SSID\":\"prplOSguest110\"}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.4.":{"SSID":"prplOSguest110"}}
  {}
  {"amxd-error-code":0}

  $ R "ba-cli 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.*.Enable=1' | grep -v '>'  | grep '='"
  X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Enable=1
  X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2.Enable=1
  X_PRPLWARE-COM_WiFiController.Network.AccessPoint.3.Enable=1
  X_PRPLWARE-COM_WiFiController.Network.AccessPoint.4.Enable=1


  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network AccessPointCommit"
  {"retval":""}
  {}
  {"amxd-error-code":0}


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
  backhaul_(AC:91:9B|58:E4:03):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  backhaul_(AC:91:9B|58:E4:03):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  backhaul_(AC:91:9B|58:E4:03):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
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
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan1
  /opt/prplmesh/bin/beerocks_fronthaul -i wlan2
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

Restore MultiApType, KeyPassPhrase, and, for 2.4/5GHz - ModeEnabled - to default values

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1 _set '{\"parameters\":{\"MultiApMode\":\"Fronthaul\"}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.":{"MultiApMode":"Fronthaul"}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Security _set '{\"parameters\":{\"ModeEnabled\":\"WPA3-Personal-Transition\",\"KeyPassphrase\":\"password\"}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Security.":{"KeyPassphrase":"password","ModeEnabled":"WPA3-Personal-Transition"}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.3 _set '{\"parameters\":{\"MultiApMode\":\"Fronthaul\"}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.3.":{"MultiApMode":"Fronthaul"}}
  {}
  {"amxd-error-code":0}

  $ R "ubus -S call X_PRPLWARE-COM_WiFiController.Network.AccessPoint.3.Security _set '{\"parameters\":{\"KeyPassphrase\":\"password\"}}'"
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.3.Security.":{"KeyPassphrase":"password"}}
  {}
  {"amxd-error-code":0}

Pipe to grep to remove empty lines

  $ R "ba-cli -a -j -l 'X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit()' | grep '.' "
  X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit() returned
  [""]

To disable wireless, disable instances of Network.AccessPoint{i} and call AccessPointCommit():

  $ R logger -t cram "Stop wireless"

  $ R "ba-cli 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.*.Enable=0' | grep -v '>'  | grep '='"
  X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Enable=0
  X_PRPLWARE-COM_WiFiController.Network.AccessPoint.2.Enable=0
  X_PRPLWARE-COM_WiFiController.Network.AccessPoint.3.Enable=0
  X_PRPLWARE-COM_WiFiController.Network.AccessPoint.4.Enable=0

Pipe to grep to remove empty lines

  $ R "ba-cli -a -j -l 'X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit()' | grep '.' "
  X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit() returned
  [""]

  $ sleep 20

  $ R "ba-cli -a \"WiFi.SSID.[SSID=='prplOSpriv110'].SSID=prplOS\" | grep -v '>' | grep '='"
  WiFi.SSID.1.SSID="prplOS"
  WiFi.SSID.4.SSID="prplOS"
  WiFi.SSID.7.SSID="prplOS"

  $ R "ba-cli -a \"WiFi.SSID.[SSID=='prplOSguest110'].SSID='prplOS-guest'\" | grep -v '>' | grep '='"
  WiFi.SSID.3.SSID="prplOS-guest"
  WiFi.SSID.6.SSID="prplOS-guest"
  WiFi.SSID.9.SSID="prplOS-guest"

Check that wireless is disabled:

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

Check that SSIDs did not change:

  $ get_ssid_ssid
  backhaul_(AC:91:9B|58:E4:03):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  backhaul_(AC:91:9B|58:E4:03):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  backhaul_(AC:91:9B|58:E4:03):[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2} (re)
  prplOS
  prplOS
  prplOS
  prplOS-guest
  prplOS-guest
  prplOS-guest

Restore Security Mode to default values

  $ R "ba-cli  \"WiFi.AccessPoint.[RadioReference == 'Device.WiFi.Radio.1'].Security.ModeEnabled='WPA2-WPA3-Personal'\"" | grep 'ModeEnabled=' | sed '/^$/d' | grep -v '>'
  WiFi.AccessPoint.\d+.Security.ModeEnabled="WPA2-WPA3-Personal" (re)
  WiFi.AccessPoint.\d+.Security.ModeEnabled="WPA2-WPA3-Personal" (re)
  WiFi.AccessPoint.\d+.Security.ModeEnabled="WPA2-WPA3-Personal" (re)

  $ R "ba-cli  \"WiFi.AccessPoint.[RadioReference == 'Device.WiFi.Radio.2'].Security.ModeEnabled='WPA2-WPA3-Personal'\"" | grep 'ModeEnabled=' | sed '/^$/d' | grep -v '>'
  WiFi.AccessPoint.\d+.Security.ModeEnabled="WPA2-WPA3-Personal" (re)
  WiFi.AccessPoint.\d+.Security.ModeEnabled="WPA2-WPA3-Personal" (re)
  WiFi.AccessPoint.\d+.Security.ModeEnabled="WPA2-WPA3-Personal" (re)

  $ R "ba-cli  \"WiFi.AccessPoint.[RadioReference == 'Device.WiFi.Radio.3'].Security.ModeEnabled='WPA3-Personal'\"" | grep 'ModeEnabled=' | sed '/^$/d' | grep -v '>'
  WiFi.AccessPoint.\d+.Security.ModeEnabled="WPA3-Personal" (re)
  WiFi.AccessPoint.\d+.Security.ModeEnabled="WPA3-Personal" (re)
  WiFi.AccessPoint.\d+.Security.ModeEnabled="WPA3-Personal" (re)

Restore Controller 'VAP Configuration Source'-configuration to default

  $ R "sed -i 's/use_dataelements_vap_configs=1/use_dataelements_vap_configs=0/g' /opt/prplmesh/config/beerocks_controller.conf"

Restart prplmesh:

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=1" | tr -d '\n'
  1 (no-eol)

Check the default ChipsetVendor param configurations:

  $ R logger -t cram "Check the default ChipsetVendor param configurations:"
  $ R "ba-cli -j -l WiFi.Radio.*.ChipsetVendor?0 | jsonfilter -e @[0]'[*].ChipsetVendor'"
  Qualcomm
  Qualcomm
  Qualcomm
