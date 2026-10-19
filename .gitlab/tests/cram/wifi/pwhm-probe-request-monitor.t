Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting $TESTFILE"

  $ check_wifi_defaults
  $ testbed_set_wifi_defaults


Check default configuration:

  $ R logger -t cram "Check default configuration"

  $ wifi_dm "Radio.*.ProbeRequestMonitoring.?"
  Device.WiFi.Radio.1.ProbeRequestMonitoring.AggregationTimer=0
  Device.WiFi.Radio.1.ProbeRequestMonitoring.BufferSize=40
  Device.WiFi.Radio.1.ProbeRequestMonitoring.Enable=0
  Device.WiFi.Radio.2.ProbeRequestMonitoring.AggregationTimer=0
  Device.WiFi.Radio.2.ProbeRequestMonitoring.BufferSize=40
  Device.WiFi.Radio.2.ProbeRequestMonitoring.Enable=0
  Device.WiFi.Radio.3.ProbeRequestMonitoring.AggregationTimer=0
  Device.WiFi.Radio.3.ProbeRequestMonitoring.BufferSize=40
  Device.WiFi.Radio.3.ProbeRequestMonitoring.Enable=0

Call getProbeRequests RPC: Since the probe request monitoring is not enabled the RPC should return an empty list:

  $ R logger -t cram "call getProbeRequests"

  $ R ba-cli "WiFi.Radio.1.getProbeRequests\(\)" | grep -v '>'
  WiFi.Radio.1.getProbeRequests() returned
  [
      {
          FromTime = ".*", (re)
          StaList = [
          ],
          TimeStamp = ".*" (re)
      }
  ]

  $ R logger -t cram "$TESTFILE finished!"
