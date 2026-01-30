Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Add two schedule objects:

  $ R "ba-cli 'Device.Schedules.Schedule.+{Alias=\"work-hours\", Day=\"Monday,Tuesday,Wednesday,Thursday,Friday\", Duration=32400, Enable=0, StartTime=\"08:00\", Description=\"Schedule active during working hours\"}'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Schedules.Schedule.+{Alias=\"weekend\", Day=\"Saturday,Sunday\", Duration=0, Enable=0, StartTime=\"\", Description=\"Schedule active on saturday and sunday\"}'" > /dev/null 2>&1

Check that we have expected datamodel:

  $ R "ba-cli -lj Device.Hardware.PowerManagement.?" | jq .
  [
    {
      "Device.Hardware.PowerManagement.": {},
      "Device.Hardware.PowerManagement.Standby.": {
        "Capability": "DeepSleep",
        "ScheduleRef": "",
        "NetworkAware": 0,
        "Status": "Disabled",
        "StandbyOccurred": 0,
        "TimerAware": 0
      }
    }
  ]

Ensure the Capability parameter is read-only:

  $ R "ba-cli 'Device.Hardware.PowerManagement.Standby.Capability=\"Test\"'" | tail -n 1
  ERROR: set Device.Hardware.PowerManagement.Standby.Capability failed (15 - is read only)

Ensure the Status parameter is read-only:

  $ R "ba-cli 'Device.Hardware.PowerManagement.Standby.Status=\"Test\"'" | tail -n 1
  ERROR: set Device.Hardware.PowerManagement.Standby.Status failed (15 - is read only)

Reject a ScheduleRef referencing a non-existent schedule:

  $ R "ba-cli 'Device.Hardware.PowerManagement.Standby.ScheduleRef=\"Schedules.Schedule.non-existent-schedule.\"'" | tail -n 1
  ERROR: set Device.Hardware.PowerManagement.Standby.ScheduleRef failed (21 - invalid path)

Reject a ScheduleRef with an empty StartTime:

  $ R "ba-cli 'Device.Schedules.Schedule.+{Alias=\"invalid-schedule\", Enable=0, Description=\"Invalid Schedule with an empty StartTime parameter for test purpose\"}'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Hardware.PowerManagement.Standby.ScheduleRef=\"Schedules.Schedule.invalid-schedule.\"'" | tail -n 1
  ERROR: set Device.Hardware.PowerManagement.Standby.ScheduleRef failed (10 - invalid value)

Reject a ScheduleRef with overlapping schedules:

  $ R "ba-cli 'Schedules.Schedule.weekend.InverseMode=1'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Hardware.PowerManagement.Standby.ScheduleRef=\"Schedules.Schedule.work-hours.,Schedules.Schedule.weekend.\"'" | tail -n 1
  ERROR: set Device.Hardware.PowerManagement.Standby.ScheduleRef failed (10 - invalid value)

  $ R "ba-cli 'Device.Hardware.PowerManagement.Standby.ScheduleRef?'" | tail -n 1
  Device.Hardware.PowerManagement.Standby.ScheduleRef=""

Accept a ScheduleRef containing a valid schedule:

  $ R "ba-cli 'Device.Hardware.PowerManagement.Standby.ScheduleRef=\"Schedules.Schedule.work-hours.\"'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Hardware.PowerManagement.Standby.ScheduleRef?'" | tail -n 1
  Device.Hardware.PowerManagement.Standby.ScheduleRef="Schedules.Schedule.3"

Accept a valid ScheduleRef list of schedules:

  $ R "ba-cli 'Schedules.Schedule.weekend.InverseMode=0'" > /dev/null 2>&1
  $ R "ba-cli 'Schedules.Schedule.weekend.Duration=500'" > /dev/null 2>&1
  $ R "ba-cli 'Schedules.Schedule.weekend.StartTime=\"08:00\"'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Hardware.PowerManagement.Standby.ScheduleRef=\"Schedules.Schedule.work-hours.,Schedules.Schedule.weekend.\"'" | tail -n 1
  Device.Hardware.PowerManagement.Standby.ScheduleRef="Schedules.Schedule.3,Schedules.Schedule.4"

  $ R "ba-cli 'Device.Hardware.PowerManagement.Standby.ScheduleRef?'" | tail -n 1
  Device.Hardware.PowerManagement.Standby.ScheduleRef="Schedules.Schedule.3,Schedules.Schedule.4"

Remove schedule and check ScheduleRef list is updated:

  $ R "ba-cli 'Schedules.Schedule.weekend.-'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Hardware.PowerManagement.Standby.ScheduleRef?'" | tail -n 1
  Device.Hardware.PowerManagement.Standby.ScheduleRef="Schedules.Schedule.3"

Simulate DeepStandby:

  $ R "ba-cli 'Device.Hardware.PowerManagement.Standby.ScheduleRef=\"\"'" > /dev/null 2>&1
  $ R "echo -n "DeepSleep" > /etc/config/tr181-powermanager/deep_standby.txt"
  $ R "/etc/init.d/tr181-powermanager restart"

Check that the expected data model exists and StandbyOccurred is true:

  $ R "ba-cli -lj Device.Hardware.PowerManagement.?" | jq .
  [
    {
      "Device.Hardware.PowerManagement.": {},
      "Device.Hardware.PowerManagement.Standby.": {
        "Capability": "DeepSleep",
        "ScheduleRef": "",
        "NetworkAware": 0,
        "Status": "Disabled",
        "StandbyOccurred": 1,
        "TimerAware": 0
      }
    }
  ]

Cleanup - Delete schedule entries to avoid impacting other tests using the Schedule plugin:

  $ R "ba-cli 'Device.Schedules.Schedule.work-hours.-'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Schedules.Schedule.weekend.-'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Schedules.Schedule.invalid-schedule.-'" > /dev/null 2>&1
