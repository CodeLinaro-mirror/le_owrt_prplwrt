Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Provide common wifi helpers:

  $ get_ssid_status() { R "ba-cli -j -l WiFi.SSID.?0 | jsonfilter -e @[0]'[@.Alias != \"ep2g0\" && @.Alias != \"ep5g0\" && @.Alias != \"ep6g0\"].Status'" | LC_ALL=C sort;}

Check TemperatureStatus root datamodel:

  $ R "ubus -S call TemperatureStatus _get"
  {"TemperatureStatus.":{"TemperatureSensorNumberOfEntries":[1-9][0-9]*,"PollingMaxRetry":-1}} (re)
  {}
  {"amxd-error-code":0}

Check TemperatureSensorNumberOfEntries:

  $ R "ubus-cli 'TemperatureStatus.TemperatureSensorNumberOfEntries?' | grep '=' | sed 's/.*=//'"
  [1-9][0-9]* (re)

Check if directories or symbolic links exist for each TemperatureSensor object:

  $ directories=$(R "ubus-cli 'TemperatureStatus.TemperatureSensor.*.Name?' | grep 'TemperatureStatus.TemperatureSensor.[0-9]*.Name=' | sort | sed 's/.*=//' | tr -d '\"'")

  $ all_exist=true
  $ for directory in $directories; do
  >   result=$(R "test -d $directory && echo $directory exists || echo $directory does not exist")
  >   if echo "$result" | grep -q "does not exist"; then
  >     all_exist=false
  >   fi
  > done

  $ if [ "$all_exist" = true ]; then 
  >   echo "All zones exists"
  > fi
  All zones exists

Enable all wifi interfaces before starting the test, so all thermal zones can be available:

Check default wifi status:

  $ get_ssid_status
  Down
  Down
  Down
  Down
  Down
  Down

Set AutoChannelEnable=0 on all WiFi.Radio. interfaces:

  $ R "ba-cli -j -l WiFi.Radio.*.AutoChannelEnable=0 | sed '/^$/d'"
  [{"WiFi.Radio.1.":{"AutoChannelEnable":0},"WiFi.Radio.2.":{"AutoChannelEnable":0},"WiFi.Radio.3.":{"AutoChannelEnable":0}}]

Set radio channel to a non DFS one:

  $ R "ba-cli -j -l WiFi.Radio.2.Channel=36 | sed '/^$/d'"
  [{"WiFi.Radio.2.":{"Channel":36}}]

Enable all interfaces:

  $ R "ba-cli -j -l WiFi.AccessPoint.*.Enable=1 | sed '/^$/d'"
  [{"WiFi.AccessPoint.3.":{"Enable":1},"WiFi.AccessPoint.4.":{"Enable":1},"WiFi.AccessPoint.5.":{"Enable":1},"WiFi.AccessPoint.6.":{"Enable":1},"WiFi.AccessPoint.1.":{"Enable":1},"WiFi.AccessPoint.2.":{"Enable":1}}]

  $ sleep 10

Check wifi activation:

  $ get_ssid_status
  Up
  Up
  Up
  Up
  Up
  Up

Check that the value is actually synchronized with the system value:

  $ obj_indexes=$(R "ubus-cli 'TemperatureStatus.TemperatureSensor.*.Value?' | grep '=' | sort | sed -E 's/[^.]*\.[^.]*\.([^.]*).*/\1/'")

  $ all_values_match=true

  $ for obj_index in $obj_indexes; do
  >   zone=$(R "ubus-cli "TemperatureStatus.TemperatureSensor.$obj_index.Name?" | grep 'TemperatureStatus.TemperatureSensor.[0-9]*.Name=' | sort | sed 's/.*=//' | tr -d '\"'")
  >   get_temp=$(R "cat $zone/temp")
  >   temp_temperature=$(($(($get_temp+500)) / 1000))
  >   value=$(R "ubus-cli "TemperatureStatus.TemperatureSensor.$obj_index.Value?" | grep '=' | sort | sed 's/.*=//'")
  >   diff_abs="$(echo "$((temp_temperature - value))" | tr -d '-')"
  >   if [ "$diff_abs" -gt 5 ]; then
  >     echo "value $value, average $temp_temperature, objindex $obj_index"
  >     all_values_match=false
  >   fi
  > done

  $ if [ "$all_values_match" = true ]; then 
  >   echo "All values matched"
  > fi
  All values matched

Disable wifi interfaces before leaving the test:

  $ R "ba-cli -j -l WiFi.AccessPoint.*.Enable=0 | sed '/^$/d'"
  [{"WiFi.AccessPoint.3.":{"Enable":0},"WiFi.AccessPoint.4.":{"Enable":0},"WiFi.AccessPoint.5.":{"Enable":0},"WiFi.AccessPoint.6.":{"Enable":0},"WiFi.AccessPoint.1.":{"Enable":0},"WiFi.AccessPoint.2.":{"Enable":0}}]

  $ sleep 10

Check wifi dectivation:

  $ get_ssid_status
  Down
  Down
  Down
  Down
  Down
  Down
