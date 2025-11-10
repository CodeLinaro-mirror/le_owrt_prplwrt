Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that we have expected datamodel:

  $ R "ba-cli -lj Schedules.?" | jq .
  [
    {
      "Schedules.": {
        "Enable": 1,
        "ScheduleNumberOfEntries": 0
      }
    }
  ]

Add two schedule objects:

  $ R "ba-cli 'Schedules.Schedule.+{Alias=\"work-hours\",Day=\"Monday,Tuesday,Wednesday,Thursday,Friday\",Duration=32400, Enable=1,StartTime=\"08:00\",Description=\"Schedule active during working hours\"}'" > /dev/null 2>&1
  $ R "ba-cli 'Schedules.Schedule.+{Alias=\"weekend\",Day=\"Saturday,Sunday\",Duration=0, Enable=1,StartTime=\"\",Description=\"Schedule active on saturday and sunday\"}'" > /dev/null 2>&1

Check that we have expected datamodel:

  $ R "ba-cli -lj Schedules.Schedule.?" | jq . | sed -E 's/\.Schedule\.[0-9]+\./.Schedule.X./' 
  [
    {
      "Schedules.Schedule.X.": {
        "Status": .*, (re)
        "TimeLeft": \d+, (re)
        "Description": "Schedule active during working hours",
        "InverseMode": 0,
        "Enable": 1,
        "StartTime": "08:00",
        "Duration": 32400,
        "Day": "Monday,Tuesday,Wednesday,Thursday,Friday",
        "Alias": "work-hours"
      },
      "Schedules.Schedule.X.": {
        "Status": .*, (re)
        "TimeLeft": \d+, (re)
        "Description": "Schedule active on saturday and sunday",
        "InverseMode": 0,
        "Enable": 1,
        "StartTime": "",
        "Duration": 0,
        "Day": "Saturday,Sunday",
        "Alias": "weekend"
      }
    }
  ]

All Schedules.Schedule.*.Status parameters are set to StackDisabled

  $ R "ba-cli Schedules.Enable=0"  > /dev/null 2>&1
  $ R "ba-cli Schedules.Schedule.*.Status?" | tail -n +2 | sed -E 's/\.Schedule\.[0-9]+\./.Schedule.X./' | head -n -1
  Schedules.Schedule.X.Status="StackDisabled"
  Schedules.Schedule.X.Status="StackDisabled"

All Schedules.Schedule.*.Status parameters are set to Disabled

  $ R "ba-cli Schedules.Enable=1"  > /dev/null 2>&1
  $ R "ba-cli Schedules.Schedule.*.Enable=0"  > /dev/null 2>&1
  $ R "ba-cli Schedules.Schedule.*.Status?" | tail -n +2 | sed -E 's/\.Schedule\.[0-9]+\./.Schedule.X./' | head -n -1
  Schedules.Schedule.X.Status="Disabled"
  Schedules.Schedule.X.Status="Disabled"
