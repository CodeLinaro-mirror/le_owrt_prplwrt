Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Cleanup from previous runs if there are any:

  $ R "rm -f /tmp/mock_power"

Add a dummy PowerSensor instance and restart the tr181-powerstatus service:

  $ R "echo '%populate{object PowerStatus.PowerSensor{instance add(0, \"dummy-sensor\"){parameter Name=\"Dummy Power Sensor\"; parameter Enable=0; parameter PowerPath=\"\";}}}' > /etc/amx/tr181-powerstatus/tr181-powerstatus_defaults/01_tr181-powerstatus_defaults.odl"

  $ R "sleep 1; /etc/init.d/tr181-powerstatus stop  > /dev/null 2>&1"

  $ R "sleep 1; rm /etc/config/tr181-powerstatus/odl/tr181-powerstatus.odl  > /dev/null 2>&1"

  $ R "sleep 1; /etc/init.d/tr181-powerstatus start  > /dev/null 2>&1"

Check the current number of PowerSensor instances:

  $ R "ba-cli 'PowerStatus.PowerSensorNumberOfEntries?' | grep -v '>' | grep '='"
  PowerStatus.PowerSensorNumberOfEntries=[0-9]+ (re)

Check the dummy PowerSensor instance:

  $ R "ba-cli 'PowerStatus.PowerSensor.?' | grep -v '>' | grep '=' | sort"
  PowerStatus.PowerSensor.[0-9]+.Alias="dummy-sensor" (re)
  PowerStatus.PowerSensor.[0-9]+.Current=0 (re)
  PowerStatus.PowerSensor.[0-9]+.Enable=[0-9]+ (re)
  PowerStatus.PowerSensor.[0-9]+.LastUpdate="[0-9]{4}-[0-9]{2}-[0-9]{2}T.*Z" (re)
  PowerStatus.PowerSensor.[0-9]+.Name="Dummy Power Sensor" (re)
  PowerStatus.PowerSensor.[0-9]+.Power=[0-9]+ (re)
  PowerStatus.PowerSensor.[0-9]+.Status=".*" (re)
  PowerStatus.PowerSensor.[0-9]+.Voltage=0 (re)

Disable the dummy PowerSensor instance:

  $ R "ba-cli 'PowerStatus.PowerSensor.[Alias==\"dummy-sensor\"].Enable=0' | grep -v '>' | grep '='"
  PowerStatus.PowerSensor.[0-9]+.Enable=0 (re)

Check the status of dummy PowerSensor instance:

  $ R "ba-cli 'PowerStatus.PowerSensor.[Alias==\"dummy-sensor\"].Status?' | grep -v '>' | grep '=' | sed -E 's/.*Status=\"([^\"]+)\"/\\1/'"
  Disabled

Enable the dummy PowerSensor instance:

  $ R "ba-cli 'PowerStatus.PowerSensor.[Alias==\"dummy-sensor\"].Enable=1' | grep -v '>' | grep '='"
  PowerStatus.PowerSensor.[0-9]+.Enable=1 (re)

Check the status of dummy PowerSensor instance:

  $ R "ba-cli 'PowerStatus.PowerSensor.[Alias==\"dummy-sensor\"].Status?' | grep -v '>' | grep '=' | sed -E 's/.*Status=\"([^\"]+)\"/\\1/'"
  Error

Create a mock power file and verify the sensor becomes enabled:

  $ R "echo '10000\n' > /tmp/mock_power"

  $ R "chmod 644 /tmp/mock_power"

Configure protected parameters and enable the sensor:

  $ R "ba-cli 'PowerStatus.PowerSensor.[Alias==\"dummy-sensor\"].PowerPath=\"/tmp/mock_power\"' | grep -v '>' | grep '='"
  PowerStatus.PowerSensor.[0-9]+.PowerPath="/tmp/mock_power" (re)

  $ R "ba-cli 'PowerStatus.PowerSensor.[Alias==\"dummy-sensor\"].PollingInterval=1' | grep -v '>' | grep '='"
  PowerStatus.PowerSensor.[0-9]+.PollingInterval=1 (re)

  $ R "ba-cli 'PowerStatus.PowerSensor.[Alias==\"dummy-sensor\"].Enable=1' | grep -v '>' | grep '='"
  PowerStatus.PowerSensor.[0-9]+.Enable=1 (re)

Check the status of dummy PowerSensor instance:

  $ R "sleep 2; ba-cli 'PowerStatus.PowerSensor.[Alias==\"dummy-sensor\"].Status?' | grep -v '>' | grep '=' | sed -E 's/.*Status=\"([^\"]+)\"/\\1/'"
  Enabled

Change the power value and verify the update:

  $ R "echo '5000\n' > /tmp/mock_power"

  $ R "sleep 2; ba-cli 'PowerStatus.PowerSensor.[Alias==\"dummy-sensor\"].Power?' | grep -v '>' | grep '=' | sed -E 's/.*Power=([0-9]+)/\\1/'"
  5000

Cleanup:

  $ R "rm -f /tmp/mock_power"

  $ R "rm -f /etc/amx/tr181-powerstatus/tr181-powerstatus_defaults/01_tr181-powerstatus_defaults.odl"

  $ R "sleep 1; /etc/init.d/tr181-powerstatus stop  > /dev/null 2>&1"

  $ R "sleep 1; rm /etc/config/tr181-powerstatus/odl/tr181-powerstatus.odl  > /dev/null 2>&1"

  $ R "sleep 1; /etc/init.d/tr181-powerstatus start  > /dev/null 2>&1"