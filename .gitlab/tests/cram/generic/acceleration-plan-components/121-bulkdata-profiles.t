Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R "ba-cli 'BulkData.Profile.*.-'" > /dev/null
  $ R "ba-cli 'BulkData.set_trace_zone(zone=http, level=500)'" > /dev/null

Check Bulkdata syslog messages:

  $ check_bulkdata_success() {
  >   local first_line="$1"
  >   local timeout="$2"
  >   local success_pattern="$3"
  >   local attempt logs
  >   for attempt in $(seq 1 "$timeout"); do
  >     logs=$(R "tail -n +$first_line /var/log/messages | grep bulkdata" || true)
  >     if echo "$logs" | grep -Fq 'transfer failed'; then
  >       echo "$logs" >&2
  >       return 1
  >     fi
  >     if echo "$logs" | grep -Fq "$success_pattern"; then
  >       echo "Test Successful"
  >       return 0
  >     fi
  >     sleep 1
  >   done
  >   echo "$logs" >&2
  >   return 1
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

  $ R "ba-cli 'BulkData.Enable=1' | grep -Ev '^(>|$)' | grep 'Enable'"
  BulkData.Enable=1

  $ R "ba-cli 'BulkData.Status?' | grep '='"
  BulkData.Status="Enabled"

1-HTTP Profile to send JSON report
Check adding an object with HTTP profile to send JSON report:

  $ R "ba-cli 'BulkData.Profile.+{Alias="http-json", EncodingType="JSON", Name="http-json", Protocol="HTTP", Enable="false", ReportingInterval = 30}' | grep -Ev '^(>|$)' | grep 'http-json'"
  BulkData.Profile.[0-9]+.Alias="http-json" (re)

Check to update HTTP object:

  $ R "ba-cli 'BulkData.Profile.http-json.HTTP.URL="https://postman-echo.com/post/"' | grep -Ev '^(>|$)' | grep '='"
  BulkData.Profile.[0-9]+.HTTP.URL="https://postman-echo.com/post/" (re)

  $ R "ba-cli 'BulkData.Profile.http-json.HTTP.Method="POST"' | grep -Ev '^(>|$)' | grep '='"
  BulkData.Profile.[0-9]+.HTTP.Method="POST" (re)

  $ R "ba-cli 'BulkData.Profile.http-json.HTTP.UseDateHeader=1' | grep -Ev '^(>|$)' | grep '='"
  BulkData.Profile.[0-9]+.HTTP.UseDateHeader=1 (re)

Check to update JSON object:

  $ R "ba-cli 'BulkData.Profile.http-json.JSONEncoding.ReportFormat="ObjectHierarchy"' | grep -Ev '^(>|$)' | grep '='"
  BulkData.Profile.[0-9]+.JSONEncoding.ReportFormat="ObjectHierarchy" (re)

  $ R "ba-cli 'BulkData.Profile.http-json.JSONEncoding.ReportTimestamp="Unix-Epoch"' | grep -Ev '^(>|$)' | grep '='"
  BulkData.Profile.[0-9]+.JSONEncoding.ReportTimestamp="Unix-Epoch" (re)

Check adding a parameter to be sent in the report:

  $ R "ba-cli 'BulkData.Profile.http-json.Parameter.+{Name="Contacts", Reference="Phonebook.Contact."}' | grep -Ev '^(>|$)' | grep '.'"
  BulkData.Profile.[0-9]+.Parameter.[0-9]+. (re)

Check after enabling the configured profile:

  $ sleep 5 # wait for object creation
  $ log_start=$(R "wc -l < /var/log/messages"); log_start=$((log_start + 1))
  $ R "ba-cli 'BulkData.Profile.http-json.Enable="true"' | grep -Ev '^(>|$)' | grep '='"
  BulkData.Profile.[0-9]+.Enable=1 (re)

Check traces:

  $ check_bulkdata_success "$log_start" 40 "HTTP request sent successfully for profile 'BulkData.Profile.http-json'"
  Test Successful

2-HTTP Profile to send CSV report
Check adding an object with HTTP profile to send CSV report:

  $ R "ba-cli 'BulkData.Profile.*.-'" > /dev/null

  $ R "ba-cli 'BulkData.Profile.+{Alias="http-csv", EncodingType="CSV", Name="http-csv", Protocol="HTTP", Enable="false", ReportingInterval = 30}' | grep -Ev '^(>|$)' | grep 'http-csv'"
  BulkData.Profile.[0-9]+.Alias="http-csv" (re)

Check to update HTTP object:

  $ R "ba-cli 'BulkData.Profile.http-csv.HTTP.URL="https://postman-echo.com/post/"' | grep -Ev '^(>|$)' | grep '='"
  BulkData.Profile.[0-9]+.HTTP.URL="https://postman-echo.com/post/" (re)

  $ R "ba-cli 'BulkData.Profile.http-csv.HTTP.Method="POST"' | grep -Ev '^(>|$)' | grep '='"
  BulkData.Profile.[0-9]+.HTTP.Method="POST" (re)

  $ R "ba-cli 'BulkData.Profile.http-csv.HTTP.UseDateHeader=1' | grep -Ev '^(>|$)' | grep '='"
  BulkData.Profile.[0-9]+.HTTP.UseDateHeader=1 (re)

  $ R "ba-cli 'BulkData.Profile.http-csv.CSVEncoding.EscapeCharacter="\&quot"' | grep -Ev '^(>|$)' | grep '='"
  BulkData.Profile.[0-9]+.CSVEncoding.EscapeCharacter="&quot" (re)

  $ R "ba-cli 'BulkData.Profile.http-csv.CSVEncoding.FieldSeparator=\"\,\"' | grep -Ev '^(>|$)' | grep '='"
  BulkData.Profile.[0-9]+.CSVEncoding.FieldSeparator="," (re)

  $ R "ba-cli 'BulkData.Profile.http-csv.CSVEncoding.ReportFormat="ParameterPerRow"' | grep -Ev '^(>|$)' | grep '='"
  BulkData.Profile.[0-9]+.CSVEncoding.ReportFormat="ParameterPerRow" (re)

  $ R "ba-cli 'BulkData.Profile.http-csv.CSVEncoding.RowSeparator=\"&#13;&#10;\"' | grep -Ev '^(>|$)' | grep '='"
  BulkData.Profile.[0-9]+.CSVEncoding.RowSeparator="&#13;&#10;" (re)

  $ R "ba-cli 'BulkData.Profile.http-csv.CSVEncoding.RowTimestamp="Unix-Epoch"' | grep -Ev '^(>|$)' | grep '='"
  BulkData.Profile.[0-9]+.CSVEncoding.RowTimestamp="Unix-Epoch" (re)

Check adding a parameter to be sent in the report:

  $ R "ba-cli 'BulkData.Profile.http-csv.Parameter.+{Name="Contacts", Reference="Phonebook.Contact."}' | grep -Ev '^(>|$)' | grep '.'"
  BulkData.Profile.[0-9]+.Parameter.[0-9]+. (re)

Check after enabling the configured profile:

  $ sleep 5 # wait for object creation
  $ log_start=$(R "wc -l < /var/log/messages"); log_start=$((log_start + 1))
  $ R "ba-cli 'BulkData.Profile.http-csv.Enable="true"' | grep -Ev '^(>|$)' | grep '='"
  BulkData.Profile.[0-9]+.Enable=1 (re)

Check traces:

  $ check_bulkdata_success "$log_start" 40 "HTTP request sent successfully for profile 'BulkData.Profile.http-csv'"
  Test Successful

3-MQTT Profile
Check adding an object with MQTT profile:

  $ R "ba-cli 'BulkData.Profile.*.-'" > /dev/null

  $ R "ba-cli 'BulkData.Profile.+{Alias="mqtt-json", EncodingType="JSON", Name="mqtt-json", Protocol="USPEventNotif", Enable="false", ReportingInterval = 10}' | grep -Ev '^(>|$)' | grep 'mqtt-json'"
  BulkData.Profile.[0-9]+.Alias="mqtt-json" (re)

Check to update JSON object:

  $ R "ba-cli 'BulkData.Profile.mqtt-json.JSONEncoding.ReportFormat="ObjectHierarchy"' | grep -Ev '^(>|$)' | grep '='"
  BulkData.Profile.[0-9]+.JSONEncoding.ReportFormat="ObjectHierarchy" (re)

  $ R "ba-cli 'BulkData.Profile.mqtt-json.JSONEncoding.ReportTimestamp="Unix-Epoch"' | grep -Ev '^(>|$)' | grep '='"
  BulkData.Profile.[0-9]+.JSONEncoding.ReportTimestamp="Unix-Epoch" (re)

Check adding a parameter to be sent in the report:

  $ R "ba-cli 'BulkData.Profile.mqtt-json.Parameter.+{Name="Contacts", Reference="Phonebook.Contact."}' | grep -Ev '^(>|$)' | grep '.'"
  BulkData.Profile.[0-9]+.Parameter.[0-9]+. (re)

Check after enabling the configured profile:

  $ sleep 5 # wait for object creation
  $ log_start=$(R "wc -l < /var/log/messages"); log_start=$((log_start + 1))
  $ R "ba-cli 'BulkData.Profile.mqtt-json.Enable="true"' | grep -Ev '^(>|$)' | grep '='"
  BulkData.Profile.[0-9]+.Enable=1 (re)

Check traces:

  $ check_bulkdata_success "$log_start" 20 'Unable to get value for Phonebook.Contact.'
  Test Successful

Restore default settings:
  $ if [ "$time_sync" = true -a -n "$no_sync" ]; then
  >  R "sed -i 's/needs-time-sync = false/needs-time-sync = true/' /etc/amx/tr181-bulkdata/tr181-bulkdata.odl"
  > fi

  $ R "ba-cli 'BulkData.set_trace_zone(zone=http, level=200)'" > /dev/null
