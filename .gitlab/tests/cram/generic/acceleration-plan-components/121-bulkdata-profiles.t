Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R "ba-cli 'BulkData.Profile.*.-'" > /dev/null
  $ R "ba-cli 'BulkData.set_trace_zone(zone=http, level=500)'" > /dev/null

Check Bulkdata syslog messages:

  $ check_bulkdata_success() {
  >   local no_sync="$1"
  >   success=true
  >   if [ -z "$no_sync" ]; then
  >     result=$(R "grep 'bulkdata' /var/log/messages | grep 'http request sent successfully for profile' | tail -n 1 | sed 's/.*tr181-bulkdata: //'")
  >     transfer_failed=$(R "grep 'bulkdata' /var/log/messages | grep 'transfer failed' | tail -n 1 | sed 's/.*tr181-bulkdata: //'")
  >     if [ -z "$result" -a -z "$transfer_failed" ]; then
  >       success=false
  >     fi
  >   fi
  >   if [ "$success" = true ]; then
  >     echo "Test Successful"
  >   fi
  > }

Check time synchronization to start BulkData module:

  $ time_sync=$(R "cat /etc/amx/tr181-bulkdata/tr181-bulkdata.odl | grep -i "needs-time-sync" | sed -E 's/.*= ([^;]*);.*/\1/'")
  $ echo "$time_sync"
  true

Disable time synchronization and restart tr181-bulkdata to test BulkData module without time dependency if needed:

  $ if [ "$time_sync" = true ]; then
  >  R "/etc/init.d/tr181-bulkdata restart"
  >  no_sync=$(R "cat /var/log/messages | grep 'bulkdata' | grep 'synchronization not done yet' | tail -n 1 | sed 's/.*tr181-bulkdata: //'")
  >  if [ -n "$no_sync" ]; then
  >      R "sed -i 's/needs-time-sync = true/needs-time-sync = false/' /etc/amx/tr181-bulkdata/tr181-bulkdata.odl"
  >      R "/etc/init.d/tr181-bulkdata restart"
  >  fi
  > fi

Enable BulkData and check object status:

  $ R "ba-cli 'BulkData.Enable=1' | grep -v '>' | grep 'Enable'"
  BulkData.Enable=1

  $ R "ba-cli 'BulkData.Status?' | grep '='"
  BulkData.Status="Enabled"

1-HTTP Profile to send JSON report
Check adding an object with HTTP profile to send JSON report:

  $ R "ba-cli 'BulkData.Profile.+{Alias="http-json", EncodingType="JSON", Name="http-json", Protocol="HTTP", Enable="false", ReportingInterval = 30}' | grep -v '>' | grep 'http-json'"
  BulkData.Profile.[0-9]+.Alias="http-json" (re)

Check to update HTTP object:

  $ R "ba-cli 'BulkData.Profile.http-json.HTTP.URL="https://postman-echo.com/post/"' | grep -v '>' | grep '='"
  BulkData.Profile.[0-9]+.HTTP.URL="https://postman-echo.com/post/" (re)

  $ R "ba-cli 'BulkData.Profile.http-json.HTTP.Method="POST"' | grep -v '>' | grep '='"
  BulkData.Profile.[0-9]+.HTTP.Method="POST" (re)

  $ R "ba-cli 'BulkData.Profile.http-json.HTTP.UseDateHeader=1' | grep -v '>' | grep '='"
  BulkData.Profile.[0-9]+.HTTP.UseDateHeader=1 (re)

Check to update JSON object:

  $ R "ba-cli 'BulkData.Profile.http-json.JSONEncoding.ReportFormat="ObjectHierarchy"' | grep -v '>' | grep '='"
  BulkData.Profile.[0-9]+.JSONEncoding.ReportFormat="ObjectHierarchy" (re)

  $ R "ba-cli 'BulkData.Profile.http-json.JSONEncoding.ReportTimestamp="Unix-Epoch"' | grep -v '>' | grep '='"
  BulkData.Profile.[0-9]+.JSONEncoding.ReportTimestamp="Unix-Epoch" (re)

Check adding a parameter to be sent in the report:

  $ R "ba-cli 'BulkData.Profile.http-json.Parameter.+{Name="Contacts", Reference="Phonebook.Contact."}' | grep -v '>' | grep '.'"
  BulkData.Profile.[0-9]+.Parameter.[0-9]+. (re)

Check after enabling the configured profile:

  $ sleep 5 # wait for object creation
  $ R "ba-cli 'BulkData.Profile.http-json.Enable="true"' | grep -v '>' | grep '='"
  BulkData.Profile.[0-9]+.Enable=1 (re)

Check traces:

  $ check_bulkdata_success "$no_sync"
  Test Successful

2-HTTP Profile to send CSV report
Check adding an object with HTTP profile to send CSV report:

  $ R "ba-cli 'BulkData.Profile.*.-'" > /dev/null

  $ R "ba-cli 'BulkData.Profile.+{Alias="http-csv", EncodingType="CSV", Name="http-csv", Protocol="HTTP", Enable="false", ReportingInterval = 30}' | grep -v '>' | grep 'http-csv'"
  BulkData.Profile.[0-9]+.Alias="http-csv" (re)

Check to update HTTP object:

  $ R "ba-cli 'BulkData.Profile.http-csv.HTTP.URL="https://postman-echo.com/post/"' | grep -v '>' | grep '='"
  BulkData.Profile.[0-9]+.HTTP.URL="https://postman-echo.com/post/" (re)

  $ R "ba-cli 'BulkData.Profile.http-csv.HTTP.Method="POST"' | grep -v '>' | grep '='"
  BulkData.Profile.[0-9]+.HTTP.Method="POST" (re)

  $ R "ba-cli 'BulkData.Profile.http-csv.HTTP.UseDateHeader=1' | grep -v '>' | grep '='"
  BulkData.Profile.[0-9]+.HTTP.UseDateHeader=1 (re)

  $ R "ba-cli 'BulkData.Profile.http-csv.CSVEncoding.EscapeCharacter="\&quot"' | grep -v '>' | grep '='"
  BulkData.Profile.[0-9]+.CSVEncoding.EscapeCharacter="&quot" (re)

  $ R "ba-cli 'BulkData.Profile.http-csv.CSVEncoding.FieldSeparator=\"\,\"' | grep -v '>' | grep '='"
  BulkData.Profile.[0-9]+.CSVEncoding.FieldSeparator="," (re)

  $ R "ba-cli 'BulkData.Profile.http-csv.CSVEncoding.ReportFormat="ParameterPerRow"' | grep -v '>' | grep '='"
  BulkData.Profile.[0-9]+.CSVEncoding.ReportFormat="ParameterPerRow" (re)

  $ R "ba-cli 'BulkData.Profile.http-csv.CSVEncoding.RowSeparator=\"&#13;&#10;\"' | grep -v '>' | grep '='"
  BulkData.Profile.[0-9]+.CSVEncoding.RowSeparator="&#13;&#10;" (re)

  $ R "ba-cli 'BulkData.Profile.http-csv.CSVEncoding.RowTimestamp="Unix-Epoch"' | grep -v '>' | grep '='"
  BulkData.Profile.[0-9]+.CSVEncoding.RowTimestamp="Unix-Epoch" (re)

Check adding a parameter to be sent in the report:

  $ R "ba-cli 'BulkData.Profile.http-csv.Parameter.+{Name="Contacts", Reference="Phonebook.Contact."}' | grep -v '>' | grep '.'"
  BulkData.Profile.[0-9]+.Parameter.[0-9]+. (re)

Check after enabling the configured profile:

  $ sleep 5 # wait for object creation
  $ R "ba-cli 'BulkData.Profile.http-csv.Enable="true"' | grep -v '>' | grep '='"
  BulkData.Profile.[0-9]+.Enable=1 (re)

Check traces:

  $ check_bulkdata_success "$no_sync"
  Test Successful

3-MQTT Profile
Check adding an object with MQTT profile:

  $ R "ba-cli 'BulkData.Profile.*.-'" > /dev/null

  $ R "ba-cli 'BulkData.Profile.+{Alias="mqtt-json", EncodingType="JSON", Name="mqtt-json", Protocol="USPEventNotif", Enable="false", ReportingInterval = 10}' | grep -v '>' | grep 'mqtt-json'"
  BulkData.Profile.[0-9]+.Alias="mqtt-json" (re)

Check to update JSON object:

  $ R "ba-cli 'BulkData.Profile.mqtt-json.JSONEncoding.ReportFormat="ObjectHierarchy"' | grep -v '>' | grep '='"
  BulkData.Profile.[0-9]+.JSONEncoding.ReportFormat="ObjectHierarchy" (re)

  $ R "ba-cli 'BulkData.Profile.mqtt-json.JSONEncoding.ReportTimestamp="Unix-Epoch"' | grep -v '>' | grep '='"
  BulkData.Profile.[0-9]+.JSONEncoding.ReportTimestamp="Unix-Epoch" (re)

Check adding a parameter to be sent in the report:

  $ R "ba-cli 'BulkData.Profile.mqtt-json.Parameter.+{Name="Contacts", Reference="Phonebook.Contact."}' | grep -v '>' | grep '.'"
  BulkData.Profile.[0-9]+.Parameter.[0-9]+. (re)

Check after enabling the configured profile:

  $ sleep 5 # wait for object creation
  $ R "ba-cli 'BulkData.Profile.mqtt-json.Enable="true"' | grep -v '>' | grep '='"
  BulkData.Profile.[0-9]+.Enable=1 (re)

Check traces:

  $ check_bulkdata_success "$no_sync"
  Test Successful

Restore default settings:
  $ if [ "$time_sync" = true -a -n "$no_sync" ]; then
  >  R "sed -i 's/needs-time-sync = false/needs-time-sync = true/' /etc/amx/tr181-bulkdata/tr181-bulkdata.odl"
  > fi

  $ R "ba-cli 'BulkData.set_trace_zone(zone=http, level=200)'" > /dev/null
