Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting WiFi Sensing test ..."

Check default WiFi Sensing configuration:

  $ R "ba-cli -j -l WiFi.Radio.*.Sensing.Enable?0 | jsonfilter -e @[0]'[*].Enable'"
  1
  1
  1

  $ R "ba-cli -j -l WiFi.Radio.*.SupportedSensingDataTypes?0 | jsonfilter -e @[0]'[*].SupportedSensingDataTypes'"
  AC9A9680
  AC9A9680
  AC9A9680

  $ R "ba-cli -j -l WiFi.Radio.*.SupportedSensingExchangeTypes?0 | jsonfilter -e @[0]'[*].SupportedSensingExchangeTypes'"
  qosnull
  qosnull
  qosnull

Check root object and default session number:

  $ R "ba-cli -j -l X_PRPLWARE-COM_WiFiSensing.?  | jsonfilter -e @[0]'[*].SessionNumberOfEntries'"
  0

Test session creation & deletion:

  $ R "ba-cli -j -l 'Device.WiFi.Sensing.CreateSession(ApplicationName='TestSession')' | sed '/^$/d' | tail -n +2 | jsonfilter -e '@[0].SessionID' -e '@[0].DataSocketPath'" | LC_ALL=C sort
  /var/run/wifisensing/session-[0-9]+.sock (re)
  \d+ (re)


Store SessionID and DataSocketPath for next operations

  $ SessionID=$(R "ba-cli -j -l 'Device.WiFi.Sensing.?'  | jsonfilter -e @[0]'[*].SessionID'")
  $ DataSocketPath=$(R "ba-cli -j -l 'Device.WiFi.Sensing.Session.$SessionID.DataSocketPath?' | sed '/^$/d' | jsonfilter -e '@[0].*[\"DataSocketPath\"]'")
  $ R logger -t cram "SessionID:$SessionID"
  $ R logger -t cram "DataSocketPath:$DataSocketPath"

Check socket presence:

  $ R "ls $DataSocketPath >/dev/null 2>&1 && echo found || echo not_found"
  found

Check sessions number:

  $ R "ba-cli -j -l 'Device.WiFi.Sensing.?'  | jsonfilter -e @[0]'[*].SessionNumberOfEntries'" | LC_ALL=C sort
  1

Check AddExchange API: 
Note: To fully test this API an associated station is required but let's test with a dummy MAC so we check that the API is reacting

  $ R "ba-cli -j -l   'X_PRPLWARE-COM_WiFiSensing.Session.$SessionID.AddExchange(Transmitter = "AA:AA:AA:AA:AA:AA")'" | sed '/^$/d' | tail -n +2
  [{"ExchangeID":0,"ErrorCode":"NOT_PRESENT"}]

Delete session using SessionID:

  $ R "ba-cli -j -l 'Device.WiFi.Sensing.Session.$SessionID.DeleteSession()'" | sed '/^$/d' | tail -n +2
  [""]

Check that socket is deleted and sessions number is zero:

  $ R "ls $DataSocketPath >/dev/null 2>&1 && echo found || echo not_found"
  not_found

  $ R "ba-cli -j -l Device.WiFi.Sensing.?  | jsonfilter -e @[0]'[*].SessionNumberOfEntries'" 
  0

  $ R logger -t cram "Test finished!"
