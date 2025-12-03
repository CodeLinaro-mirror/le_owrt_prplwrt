Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ C ${TESTDIR}/../scripts/target/pwhm-usp-events.lua root@${TARGET_LAN_IP}:/tmp/event.lua 2>/dev/null

  $ R logger -t cram "Starting pwhm direct USP socket test ..."

Check pwhm usp socket:

  $ R "netstat -ap 2>/dev/null | grep 'LISTENING.*pwhm_usp.sock'"
  .*LISTENING.*pwhm_usp.sock (re)

Check if there is at least one connected client (should be beerocks processes):

  $ R "netstat -ap 2>/dev/null | grep 'CONNECTED.*pwhm_usp.sock'| wc -l"
  [1-9]$ (re)

Test USP events:

  $ R "lua /tmp/event.lua 'Device.WiFi.AccessPoint.1.Enable!' 'dm:object-changed' > /tmp/pwhm_usp_events &"

  $ R "ba-cli WiFi.AccessPoint.1.Enable=1" > /dev/null 2>&1

  $ sleep 5

  $ R "cat /tmp/pwhm_usp_events"
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

  $ sleep 5

  $ R logger -t cram "Test finished!"
