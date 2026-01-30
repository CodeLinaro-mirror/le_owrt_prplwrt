Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that we have expected datamodel:

  $ R "ba-cli -lj PowerManagement.?" | jq .
  [
    {
      "PowerManagement.Standby.": {
        "Capability": "DeepSleep",
        "ScheduleRef": "",
        "NetworkAware": 0,
        "Status": "Disabled",
        "StandbyOccurred": 0,
        "TimerAware": 0
      },
      "PowerManagement.": {}
    }
  ]

Ensure the Capability parameter is read-only:

  $ R "ba-cli 'PowerManagement.Standby.Capability=\"Test\"'" | tail -n 2
  ERROR: set PowerManagement.Standby.Capability failed (15 - is read only)
  
Ensure the Status parameter is read-only:

  $ R "ba-cli 'PowerManagement.Standby.Status=\"Test\"'" | tail -n 2
  ERROR: set PowerManagement.Standby.Status failed (15 - is read only)
  
Reject a ScheduleRef referencing a non-existent schedule:

  $ R "ba-cli 'PowerManagement.Standby.ScheduleRef=\"Schedules.Schedule.non-existent-schedule.\"'" | tail -n 2
  ERROR: set PowerManagement.Standby.ScheduleRef failed (10 - invalid value)
  
Reject a ScheduleRef with an empty StartTime:

  $ R "ba-cli 'Device.Schedules.Schedule.+{Alias=\"invalid-schedule\", Enable=0, Description=\"Invalid Schedule with an empty StartTime parameter for test purpose\"}'" > /dev/null 2>&1
  $ R "ba-cli 'PowerManagement.Standby.ScheduleRef=\"Schedules.Schedule.invalid-schedule.\"'" | tail -n 2
  ERROR: set PowerManagement.Standby.ScheduleRef failed (10 - invalid value)
  
Reject a ScheduleRef with overlapping schedules:

  $ R "ba-cli 'Schedules.Schedule.weekend.InverseMode=1'" > /dev/null 2>&1
  $ R "ba-cli 'PowerManagement.Standby.ScheduleRef=\"Schedules.Schedule.work-hours.,Schedules.Schedule.weekend.\"'" | tail -n 2
  ERROR: set PowerManagement.Standby.ScheduleRef failed (10 - invalid value)
  
  $ R "ba-cli 'PowerManagement.Standby.ScheduleRef?'" | tail -n 2
  PowerManagement.Standby.ScheduleRef=""
  
Accept a ScheduleRef containing a valid schedule:

  $ R "ba-cli 'PowerManagement.Standby.ScheduleRef=\"Schedules.Schedule.work-hours.\"'" > /dev/null 2>&1
  $ R "ba-cli 'PowerManagement.Standby.ScheduleRef?'" | tail -n 2
  PowerManagement.Standby.ScheduleRef="Schedules.Schedule.work-hours"
  
Accept a valid ScheduleRef list of schedules:

  $ R "ba-cli 'Schedules.Schedule.weekend.InverseMode=0'" > /dev/null 2>&1
  $ R "ba-cli 'Schedules.Schedule.weekend.Duration=500'" > /dev/null 2>&1
  $ R "ba-cli 'Schedules.Schedule.weekend.StartTime=\"08:00\"'" > /dev/null 2>&1
  $ R "ba-cli 'PowerManagement.Standby.ScheduleRef=\"Schedules.Schedule.work-hours.,Schedules.Schedule.weekend.\"'" | tail -n 2
  PowerManagement.Standby.ScheduleRef="Schedules.Schedule.work-hours,Schedules.Schedule.weekend"
  
  $ R "ba-cli 'PowerManagement.Standby.ScheduleRef?'" | tail -n 2
  PowerManagement.Standby.ScheduleRef="Schedules.Schedule.work-hours,Schedules.Schedule.weekend"
  
Remove schedule and check ScheduleRef list is updated:

  $ R "ba-cli 'Schedules.Schedule.weekend.-'" > /dev/null 2>&1
  $ R "ba-cli 'PowerManagement.Standby.ScheduleRef?'" | tail -n 2
  PowerManagement.Standby.ScheduleRef="Schedules.Schedule.work-hours"
  
Simulate DeepStandby:

  $ R "ba-cli 'PowerManagement.Standby.ScheduleRef=\"\"'" > /dev/null 2>&1
  $ R "echo -n "DeepSleep" > /etc/config/tr181-powermanager/deep_standby.txt"
  $ R "/etc/init.d/tr181-powermanager restart"

Check that the expected data model exists and StandbyOccurred is true:

  $ R "ba-cli -lj PowerManagement.?" | jq .
  [
    {
      "PowerManagement.Standby.": {
        "Capability": "DeepSleep",
        "ScheduleRef": "",
        "NetworkAware": 0,
        "Status": "Disabled",
        "StandbyOccurred": 1,
        "TimerAware": 0
      },
      "PowerManagement.": {}
    }
  ]
