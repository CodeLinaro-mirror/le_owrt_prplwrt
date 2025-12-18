Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ C ${TESTDIR}/../scripts/target/usp-events.lua root@${TARGET_LAN_IP}:/tmp/usp-event.lua 2>/dev/null
  $ C ${TESTDIR}/../scripts/target/ubus-events.lua root@${TARGET_LAN_IP}:/tmp/ubus-event.lua 2>/dev/null

  $ R logger -t cram "Starting DM Mapper test ..."

Check Ubus DM and DataModelMapper USP DM shows same values

  $ WIFI_SSID_1=$(R "ba-cli -j -l WiFi.SSID.1.SSID? | jsonfilter -e '@[0][\"WiFi.SSID.1.\"].SSID'")
  $ MAPPED_WIFI_SSID_1=$(R "ba-cli -j -l Device.WiFi.SSID.1.SSID? | jsonfilter -e '@[0][\"Device.WiFi.SSID.1.\"].SSID'")
  $ USP_WIFI_SSID_1=$(R "obuspa -f /etc/obuspa.db -c get  Device.WiFi.SSID.1.SSID | sed -n 's/^.* => //p'")

  $ [ "$WIFI_SSID_1" = "$MAPPED_WIFI_SSID_1" ]
  $ [ "$USP_WIFI_SSID_1" = "$MAPPED_WIFI_SSID_1" ]

Change a DM from Ubus and Check Again:

  $ R "ba-cli -j -l WiFi.SSID.1.SSID=\"prplOSnew\" | sed '/^$/d'"
  [{"WiFi.SSID.1.":{"SSID":"prplOSnew"}}]

  $ sleep 2

  $ WIFI_SSID_1=$(R "ba-cli -j -l WiFi.SSID.1.SSID? | jsonfilter -e '@[0][\"WiFi.SSID.1.\"].SSID'")
  $ MAPPED_WIFI_SSID_1=$(R "ba-cli -j -l Device.WiFi.SSID.1.SSID? | jsonfilter -e '@[0][\"Device.WiFi.SSID.1.\"].SSID'")
  $ USP_WIFI_SSID_1=$(R "obuspa -f /etc/obuspa.db -c get  Device.WiFi.SSID.1.SSID | sed -n 's/^.* => //p'")

  $ [ "$WIFI_SSID_1" = "$MAPPED_WIFI_SSID_1" ]
  $ [ "$USP_WIFI_SSID_1" = "$MAPPED_WIFI_SSID_1" ]
 
Change a DM from Mapper and Check Again:

  $ R "obuspa -f /etc/obuspa.db -c set Device.WiFi.SSID.2.SSID \"prplOSnew2\""
  Device.WiFi.SSID.2.SSID => prplOSnew2

  $ sleep 2

  $ WIFI_SSID_2=$(R "ba-cli -j -l WiFi.SSID.2.SSID? | jsonfilter -e '@[0][\"WiFi.SSID.2.\"].SSID'")
  $ MAPPED_WIFI_SSID_2=$(R "ba-cli -j -l Device.WiFi.SSID.2.SSID? | jsonfilter -e '@[0][\"Device.WiFi.SSID.2.\"].SSID'")
  $ USP_WIFI_SSID_2=$(R "obuspa -f /etc/obuspa.db -c get  Device.WiFi.SSID.2.SSID | sed -n 's/^.* => //p'")

  $ [ "$WIFI_SSID_2" = "$MAPPED_WIFI_SSID_2" ]
  $ [ "$USP_WIFI_SSID_2" = "$MAPPED_WIFI_SSID_2" ]

Register some data Change event from USP:

  $ R "lua /tmp/usp-event.lua 'Device.WiFi.AccessPoint.1.Enable!' 'dm:object-changed' broker > /tmp/usp_events &"

  $ R "ba-cli WiFi.AccessPoint.1.Enable=1" > /dev/null 2>&1

  $ sleep 15

  $ R "cat /tmp/usp_events"
  Event dm:object-changed
  {
      object = "Device.WiFi.AccessPoint.1.",
      parameters = {
          Enable = {
              from = "",
              to = "true"
          }
      },
      path = "Device.WiFi.AccessPoint.1."
  }

  $ R "ba-cli WiFi.AccessPoint.1.Enable=0" > /dev/null 2>&1

Register some data Change event from UBUS:

  $ R "lua /tmp/ubus-event.lua 'WiFi.AccessPoint.1.Enable!' 'dm:object-changed' > /tmp/ubus_events &"

  $ R "ba-cli Device.WiFi.AccessPoint.1.Enable=1" > /dev/null 2>&1

  $ sleep 5

  $ R "cat /tmp/ubus_events"
  Event dm:object-changed
  {
      eobject = "WiFi.AccessPoint.[DEFAULT_RADIO0_BAND0].",
      object = "WiFi.AccessPoint.DEFAULT_RADIO0_BAND0.",
      parameters = {
          Enable = {
              from = 0,
              to = 1
          }
      },
      path = "WiFi.AccessPoint.1."
  }

  $ R "ba-cli WiFi.AccessPoint.1.Enable=0" > /dev/null 2>&1

Restart WiFiSensing mapper service and verify DM disappears/returns:
 
  $ R "amx_wait_for Device.WiFi.X_PRPLWARE-COM_WiFiSensing."

  $ R "ba-cli -j -l X_PRPLWARE-COM_ProcessManager.Sensing.Enable=0 | sed '/^$/d'"
  [{"X_PRPLWARE-COM_ProcessManager.Sensing.":{"Enable":0}}]

  $ sleep 3

  $ R "ba-cli -j -l X_PRPLWARE-COM_ProcessManager.Sensing.Enable=1 | sed '/^$/d'"
  [{"X_PRPLWARE-COM_ProcessManager.Sensing.":{"Enable":1}}]

  $ R "amx_wait_for Device.WiFi.X_PRPLWARE-COM_WiFiSensing."

Write invalid value to Device.WiFi.AccessPoint.1.Enable and expect error:

  $ R "ba-cli -j -l Device.WiFi.AccessPoint.1.Enable=notabool 2>&1 | sed '/^$/d' | sed 's/ failed.*/ failed is OK/'"
  ERROR: set Device.WiFi.AccessPoint.1.Enable failed is OK

Write to non-existent parameter must fail:

  $ R "ba-cli -j -l Device.WiFi.AccessPoint.1.NotExist=param 2>&1 | sed '/^$/d' | sed 's/ failed.*/ failed is OK/'"
  ERROR: set Device.WiFi.AccessPoint.1.NotExist failed is OK

  $ R logger -t cram "Finished DM Mapper test."

