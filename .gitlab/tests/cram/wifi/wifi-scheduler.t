Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting wifi-scheduler test ..."

Wait for Device.WiFi. datamodel availability:

  $ R "amx_wait_for "Device.WiFi." "

Set AutoChannelEnable=0 on all Device.WiFi.Radio. interfaces:

  $ wifi_dm "Radio.*.AutoChannelEnable=0"
  Device.WiFi.Radio.1.AutoChannelEnable=0
  Device.WiFi.Radio.2.AutoChannelEnable=0
  Device.WiFi.Radio.3.AutoChannelEnable=0

Set channel to a non DFS one:

  $ wifi_dm "Radio.2.Channel=36"
  Device.WiFi.Radio.2.Channel=36 (re)

Check default WiFiScheduler configuration:

  $ R "usp-cli  'Device.X_PRPLWARE-COM_WiFiScheduler.?'"  | sed '/^$/d' | tail -n +2
  Device.X_PRPLWARE-COM_WiFiScheduler.
  Device.X_PRPLWARE-COM_WiFiScheduler.Enable=1
  Device.X_PRPLWARE-COM_WiFiScheduler.EnableMethod="Parameter"
  Device.X_PRPLWARE-COM_WiFiScheduler.GlobalTargetConfig="X_PRPLWARE-COM_WiFiController.Network"
  Device.X_PRPLWARE-COM_WiFiScheduler.GroupTargetConfig="X_PRPLWARE-COM_WiFiController.Network.X_PRPLWARE-COM_Group"
  Device.X_PRPLWARE-COM_WiFiScheduler.Network.

Check default APs status:

  $ R logger -t cram "Check default APs status"
  $ wifi_dm AccessPoint.*.Status?
  Device.WiFi.AccessPoint.1.Status="Disabled"
  Device.WiFi.AccessPoint.2.Status="Disabled"
  Device.WiFi.AccessPoint.3.Status="Disabled"
  Device.WiFi.AccessPoint.4.Status="Disabled"
  Device.WiFi.AccessPoint.5.Status="Disabled"
  Device.WiFi.AccessPoint.6.Status="Disabled"
  Device.WiFi.AccessPoint.7.Status="Disabled"
  Device.WiFi.AccessPoint.8.Status="Disabled"
  Device.WiFi.AccessPoint.9.Status="Disabled"

Configure controller:

  $ R logger -t cram "Configuring prplmesh and create a ptivate access point"

  $ R logger -t cram "Stop prplmesh"

  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=0" | tr -d '\n'
  0 (no-eol)

  $ sleep 2
  $ R "sed -i 's/use_dataelements_vap_configs=0/use_dataelements_vap_configs=1/g' /opt/prplmesh/config/beerocks_controller.conf"
  $ R "ba-cli X_PRPLWARE-COM_ProcessManager.PrplMesh.ManagementMode=Multi-AP-Controller-and-Agent"  > /dev/null
  $ R "ba-cli -l X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=1" | tr -d '\n'
  1 (no-eol)

  $ R "ubus -t 60 wait_for X_PRPLWARE-COM_WiFiController.Network.Device.1"

First call of AccessPointCommit, controller should push empty config to agents:

  $ R logger -t cram "first call of AccessPointCommit pushes empty config, global teardown"

  $ R "usp-cli 'Device.WiFi.DataElements.Network.AccessPointCommit()'" | tail -n +2 |  sed '/^$/d'
  Device.WiFi.DataElements.Network.AccessPointCommit() returned
  [
      {
      }
  ]

  $ sleep 10

  $ R "ba-cli -j -l 'X_PRPLWARE-COM_WiFiController.Network.X_PRPLWARE-COM_Group+{Name=\"testGroup\",Enable=1}'" | sed '/^$/d'
  {"X_PRPLWARE-COM_WiFiController.Network.X_PRPLWARE-COM_Group.1.":{}}

Create one instances of Network.AccessPoint and push it to the agent:

  $ R logger -t cram "create instances of Network.AccessPoint and push them to the agent"

  $ R "usp-cli \"Device.WiFi.DataElements.Network.AccessPoint.+(MLDUnit=-1,Band2_4G=1,Band5GH=1,Band5GL=1,Band6G=1,MultiApMode='Fronthaul+Backhaul',X_PRPLWARE-COM_VapType='home',SSID='prplOS',Security.ModeEnabled='WPA3-Personal',Security.KeyPassphrase='password',X_PRPLWARE-COM_GroupName='testGroup')\"" | tail -n +2 | sed '/^$/d'
  Device.WiFi.DataElements.Network.AccessPoint.* (re)

  $ R "ba-cli -j -l 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Enable=1'" | sed '/^$/d'
  [{"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.":{"Enable":1}}]

  $ R "usp-cli 'Device.WiFi.DataElements.Network.AccessPointCommit()'" | tail -n +2 |  sed '/^$/d'
  Device.WiFi.DataElements.Network.AccessPointCommit() returned
  [
      {
      }
  ]

  $ sleep 10

Check access points status:

  $ R logger -t cram "Check that private acceess points are enabled"

As AP indexes may vary from a platform to another, let's use regex and check enbaled/disabled AP spearately:

  $ wifi_dm "AccessPoint.[ Enable == 1 ].Status?"
  Device.WiFi.AccessPoint.\d+.Status="Enabled" (re)
  Device.WiFi.AccessPoint.\d+.Status="Enabled" (re)
  Device.WiFi.AccessPoint.\d+.Status="Enabled" (re)

  $ wifi_dm "AccessPoint.[ Enable == 0 ].Status?"
  Device.WiFi.AccessPoint.\d+.Status="Disabled" (re)
  Device.WiFi.AccessPoint.\d+.Status="Disabled" (re)
  Device.WiFi.AccessPoint.\d+.Status="Disabled" (re)
  Device.WiFi.AccessPoint.\d+.Status="Disabled" (re)
  Device.WiFi.AccessPoint.\d+.Status="Disabled" (re)
  Device.WiFi.AccessPoint.\d+.Status="Disabled" (re)

Disable access point:

  $ R "ba-cli -j -l 'X_PRPLWARE-COM_WiFiController.Network.Enable=0'" | sed '/^$/d'
  [{"X_PRPLWARE-COM_WiFiController.Network.":{"Enable":0}}]

  $ sleep 15

Check access points status:

  $ R logger -t cram "Check that APs are disabled"
  $ wifi_dm "AccessPoint.*.Status?"
  Device.WiFi.AccessPoint.1.Status="Disabled"
  Device.WiFi.AccessPoint.2.Status="Disabled"
  Device.WiFi.AccessPoint.3.Status="Disabled"
  Device.WiFi.AccessPoint.4.Status="Disabled"
  Device.WiFi.AccessPoint.5.Status="Disabled"
  Device.WiFi.AccessPoint.6.Status="Disabled"
  Device.WiFi.AccessPoint.7.Status="Disabled"
  Device.WiFi.AccessPoint.8.Status="Disabled"
  Device.WiFi.AccessPoint.9.Status="Disabled"

Schedule prplMesh network activation:

Wait for the next minute tick to trigger the test, assume it's T0:

  $ delay_sec=$(expr 60 - $(R date +%S))
  $ R logger -t cram "Wait $delay_sec seconds"
  $ sleep $((delay_sec+1))

Calculate next minute with format HH:MM T1=(T0+1min):

  $ R logger -t cram "Schedule prplMesh network activation at the next minute"
  $ now_epoch=$(R date +%s)
  $ current_time=$(R date -d "@$now_epoch" +"%H:%M:%S") 
  $ enable_time_epoch=$((now_epoch + 60)) 
  $ enable_time=$(R date -d "@$enable_time_epoch" +"%H:%M") 
  $ day=$(R date +%A | awk '{print tolower($0)}') 

  $ R logger -t cram  "Current time : $current_time"
  $ R logger -t cram  "Next enable time : ${enable_time}:00"
  $ R logger -t cram  "Next enable day $day"
  $ R logger -t cram  "Create schedule and wait until it starts"

Schedule a network activation at T1 with 1 minute duration:

  $ R "ba-cli -j -l 'Device.X_PRPLWARE-COM_WiFiScheduler.Network.Schedule.+{Enable=1, StartTime=$enable_time, Duration=60, Day=$day}'" | sed '/^$/d'
  {"Device.X_PRPLWARE-COM_WiFiScheduler.Network.Schedule.1.":{"Alias":"cpe-Schedule-1"}}

  $ sleep $((60+10))

Check Wifi schedule is running:

  $ R "ba-cli  'Device.X_PRPLWARE-COM_WiFiScheduler.Network.Schedule.1.Running?'"  | grep -Ev '^(>|$)'
  Device.X_PRPLWARE-COM_WiFiScheduler.Network.Schedule.1.Running=1

Wait few seconds before checking wifi activation:

  $ sleep 10

  $ wifi_dm "AccessPoint.[ Enable == 1 ].Status?"
  Device.WiFi.AccessPoint.\d+.Status="Enabled" (re)
  Device.WiFi.AccessPoint.\d+.Status="Enabled" (re)
  Device.WiFi.AccessPoint.\d+.Status="Enabled" (re)

  $ wifi_dm "AccessPoint.[ Enable == 0 ].Status?"
  Device.WiFi.AccessPoint.\d+.Status="Disabled" (re)
  Device.WiFi.AccessPoint.\d+.Status="Disabled" (re)
  Device.WiFi.AccessPoint.\d+.Status="Disabled" (re)
  Device.WiFi.AccessPoint.\d+.Status="Disabled" (re)
  Device.WiFi.AccessPoint.\d+.Status="Disabled" (re)
  Device.WiFi.AccessPoint.\d+.Status="Disabled" (re)

Wait 1 minute before checking wifi deactivation T1+1min

  $ R logger -t cram "Wait 1 minutes"
  $ sleep 60
  $ R logger -t cram "Check that private acceess points are disabled"
  $ wifi_dm "AccessPoint.*.Status?"
  Device.WiFi.AccessPoint.1.Status="Disabled"
  Device.WiFi.AccessPoint.2.Status="Disabled"
  Device.WiFi.AccessPoint.3.Status="Disabled"
  Device.WiFi.AccessPoint.4.Status="Disabled"
  Device.WiFi.AccessPoint.5.Status="Disabled"
  Device.WiFi.AccessPoint.6.Status="Disabled"
  Device.WiFi.AccessPoint.7.Status="Disabled"
  Device.WiFi.AccessPoint.8.Status="Disabled"
  Device.WiFi.AccessPoint.9.Status="Disabled"

Restore Security.ModeEnabled for AccessPoints used in the test

  $ R "ba-cli  \"WiFi.AccessPoint.[RadioReference == 'Device.WiFi.Radio.1'].Security.ModeEnabled='WPA3-Personal-Transition'\"" | grep 'ModeEnabled=' | sed '/^$/d' | grep -v '>'
  WiFi.AccessPoint.\d+.Security.ModeEnabled="WPA3-Personal-Transition" (re)
  WiFi.AccessPoint.\d+.Security.ModeEnabled="WPA3-Personal-Transition" (re)
  WiFi.AccessPoint.\d+.Security.ModeEnabled="WPA3-Personal-Transition" (re)

  $ R "ba-cli  \"WiFi.AccessPoint.[RadioReference == 'Device.WiFi.Radio.2'].Security.ModeEnabled='WPA3-Personal-Transition'\"" | grep 'ModeEnabled=' | sed '/^$/d' | grep -v '>'
  WiFi.AccessPoint.\d+.Security.ModeEnabled="WPA3-Personal-Transition" (re)
  WiFi.AccessPoint.\d+.Security.ModeEnabled="WPA3-Personal-Transition" (re)
  WiFi.AccessPoint.\d+.Security.ModeEnabled="WPA3-Personal-Transition" (re)

  $ R "ba-cli  \"WiFi.AccessPoint.[RadioReference == 'Device.WiFi.Radio.3'].Security.ModeEnabled='WPA3-Personal'\"" | grep 'ModeEnabled=' | sed '/^$/d' | grep -v '>'
  WiFi.AccessPoint.\d+.Security.ModeEnabled="WPA3-Personal" (re)
  WiFi.AccessPoint.\d+.Security.ModeEnabled="WPA3-Personal" (re)
  WiFi.AccessPoint.\d+.Security.ModeEnabled="WPA3-Personal" (re)

Reset wifi-scehdule:

  $ R "( rm -rf /etc/config/wifi-scheduler/ ; /etc/init.d/wifi-scheduler restart ) > /dev/null 2>&1"

  $ sleep 5

  $ R logger -t cram "Test finished!"
