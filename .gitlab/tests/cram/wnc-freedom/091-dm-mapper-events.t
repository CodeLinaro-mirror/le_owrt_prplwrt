Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ C ${TESTDIR}/../scripts/target/usp-events.lua root@${TARGET_LAN_IP}:/tmp/usp-event.lua 2>/dev/null
  $ C ${TESTDIR}/../scripts/target/ubus-events.lua root@${TARGET_LAN_IP}:/tmp/ubus-event.lua 2>/dev/null

  $ R logger -t cram "Starting DM Mapper events test ..."

Register some data Change event from USP:

  $ R "ba-cli WiFi.AccessPoint.1.Enable=0" > /dev/null 2>&1

  $ sleep 1

  $ R "lua /tmp/usp-event.lua 'Device.WiFi.AccessPoint.1.Enable!' 'dm:object-changed' \"contains('parameters.Enable')\"  broker > /tmp/usp_events &"

  $ sleep 1

  $ R "ba-cli WiFi.AccessPoint.1.Enable=1" > /dev/null 2>&1

  $ sleep 20

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

  $ sleep 1

Register some data Change event from UBUS:

  $ R "lua /tmp/ubus-event.lua 'WiFi.AccessPoint.1.Enable!' 'dm:object-changed' \"contains('parameters.Enable')\" > /tmp/ubus_events &"

  $ sleep 1

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

  $ R logger -t cram "Finished DM Mapper events test."

