Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting wifi-scheduler test ..."

Wait for Device.WiFi. datamodel availability:

  $ R "amx_wait_for "Device.WiFi." "

  $ sleep 10

Set AutoChannelEnable=0 on all WiFi.Radio. interfaces:

  $ R "ba-cli -j -l WiFi.Radio.*.AutoChannelEnable=0 | sed '/^$/d'"
  [{"WiFi.Radio.1.":{"AutoChannelEnable":0},"WiFi.Radio.2.":{"AutoChannelEnable":0},"WiFi.Radio.3.":{"AutoChannelEnable":0}}]

Set channel to a non DFS one:

  $ R "ba-cli -j -l WiFi.Radio.2.Channel=36 | sed '/^$/d'"
  [{"WiFi.Radio.2.":{"Channel":36}}]

  $ sleep 5

Check default WiFiScheduler configuration:

  $ R "ba-cli  'Device.X_PRPLWARE-COM_WiFiScheduler.?'"  | sed '/^$/d' | tail -n +2
  Device.X_PRPLWARE-COM_WiFiScheduler.
  Device.X_PRPLWARE-COM_WiFiScheduler.Enable=1
  Device.X_PRPLWARE-COM_WiFiScheduler.EnableMethod="Parameter"
  Device.X_PRPLWARE-COM_WiFiScheduler.GlobalTargetConfig="X_PRPLWARE-COM_WiFiController.Network"
  Device.X_PRPLWARE-COM_WiFiScheduler.GroupTargetConfig="X_PRPLWARE-COM_WiFiController.Network.X-PRPL_ORG_Group"
  Device.X_PRPLWARE-COM_WiFiScheduler.Network.

Check default SSID status:

  $ R logger -t cram "Check default SSID status"
  $ get_ssid_status
  Down
  Down
  Down
  Down
  Down
  Down

Configure controller:

  $ R logger -t cram "Configuring prplmesh and create a ptivate access point"

  $ R logger -t cram "Stop prplmesh"

  $ R "( /etc/init.d/prplmesh stop ; sleep 2 )  2>&1 > /dev/null"

  $ R "sed -i 's/use_dataelements_vap_configs=0/use_dataelements_vap_configs=1/g' /opt/prplmesh/config/beerocks_controller.conf"
  $ R "( /etc/init.d/prplmesh gateway_mode ; sleep 2 ) > /tmp/prplmesh-gw-mode.log 2>&1 ; logger -t prplmesh-gateway-mode < /tmp/prplmesh-gw-mode.log"

  $ R "ubus -t 60 wait_for X_PRPLWARE-COM_WiFiController.Network.Device.1"

Create prplMesh acces point and enable it:

  $ R logger -t cram "first call of AccessPointCommit pushes empty config, global teardown"

  $ R "ba-cli -j -l 'X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit()'" | sed '/^$/d'
  X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit() returned
  [""]

  $ R "ba-cli -j -l 'X_PRPLWARE-COM_WiFiController.Network.X-PRPL_ORG_Group+{Name=\"testGroup\",Enable=1}'" | sed '/^$/d'
  {"X_PRPLWARE-COM_WiFiController.Network.X-PRPL_ORG_Group.1.":{}}

  $ R "ba-cli -j -l 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint+{Band2_4G=1,Band5GH=1,Band5GL=1,Band6G=1,MultiApMode=\"Fronthaul+Backhaul\",SSID=\"prplOS\",X-PRPL_ORG_GroupName=\"testGroup\"}'" | sed '/^$/d'
  {"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.":{}}

  $ R "ba-cli -j -l 'X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.Enable=1'" | sed '/^$/d'
  [{"X_PRPLWARE-COM_WiFiController.Network.AccessPoint.1.":{"Enable":1}}]

  $ R "ba-cli -j -l 'X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit()'" | sed '/^$/d'
  X_PRPLWARE-COM_WiFiController.Network.AccessPointCommit() returned
  [""]

  $ sleep 10

Check access points status:

  $ R logger -t cram "Check that private acceess points are enabled"
  $ get_ssid_status
  Down
  Down
  Down
  Up
  Up
  Up

Disable access point:

  $ R "ba-cli -j -l 'X_PRPLWARE-COM_WiFiController.Network.Enable=0'" | sed '/^$/d'
  [{"X_PRPLWARE-COM_WiFiController.Network.":{"Enable":0}}]

  $ sleep 10

Check access points status:

  $ R logger -t cram "Check that SSIDs are disabled"
  $ get_ssid_status
  Down
  Down
  Down
  Down
  Down
  Down

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

  $ R "ba-cli  'Device.X_PRPLWARE-COM_WiFiScheduler.Network.Schedule.1.Running?'"  | sed '/^$/d' | tail -n +2
  Device.X_PRPLWARE-COM_WiFiScheduler.Network.Schedule.1.Running=1

Wait few seconds before checking wifi activation:

  $ sleep 10
  $ R logger -t cram "Check that private acceess points are enabled"
  $ get_ssid_status
  Down
  Down
  Down
  Up
  Up
  Up

Wait 1 minute before checking wifi deactivation T1+1min

  $ R logger -t cram "Wait 1 minutes"
  $ sleep 60
  $ R logger -t cram "Check that private acceess points are disabled"
  $ get_ssid_status
  Down
  Down
  Down
  Down
  Down
  Down

Reset wifi-scehdule:

  $ R "( rm -rf /etc/config/wifi-scheduler/ ; /etc/init.d/wifi-scheduler restart )  2>&1 > /dev/null"

  $ sleep 5

  $ R logger -t cram "Test finished!"
