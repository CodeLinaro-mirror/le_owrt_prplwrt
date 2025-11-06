Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

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

If test is running on a mxl, skip the next part because of PPW-423
  $ if echo "$CI_JOB_NAME" | grep -q -E "MXL|URX"; then exit 80; fi

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
