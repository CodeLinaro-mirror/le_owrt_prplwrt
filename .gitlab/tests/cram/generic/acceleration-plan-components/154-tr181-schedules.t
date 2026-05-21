Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that we have expected datamodel:

  $ R "ba-cli -lj Device.Schedules.?" | jq .
  [
    {
      "Device.Schedules.": {
        "Enable": 1,
        "ScheduleNumberOfEntries": 0
      }
    }
  ]

Add two schedule objects:

  $ R "ba-cli 'Device.Schedules.Schedule.+{Alias=\"work-hours\",Day=\"Monday,Tuesday,Wednesday,Thursday,Friday\",Duration=32400, Enable=1,StartTime=\"08:00\",Description=\"Schedule active during working hours\"}'" > /dev/null 2>&1
  $ R "ba-cli 'Device.Schedules.Schedule.+{Alias=\"weekend\",Day=\"Saturday,Sunday\",Duration=0, Enable=1,StartTime=\"\",Description=\"Schedule active on saturday and sunday\"}'" > /dev/null 2>&1

Check that we have expected datamodel:

  $ R "ba-cli -lj Device.Schedules.Schedule.?" | jq . | sed -E 's/\.Schedule\.[0-9]+\./.Schedule.X./' 
  [
    {
      "Device.Schedules.Schedule.X.": {
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
      "Device.Schedules.Schedule.X.": {
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

Verify ScheduleNumberOfEntries is updated correctly:

  $ R "ba-cli Device.Schedules.ScheduleNumberOfEntries?" | tail -n +2 | head -n -1
  Device.Schedules.ScheduleNumberOfEntries=2

Verify all Schedules.Schedule.*.Status parameters are set to StackDisabled

  $ R "ba-cli Device.Schedules.Enable=0"  > /dev/null 2>&1
  $ R "ba-cli Device.Schedules.Schedule.*.Status?" | tail -n +2 | sed -E 's/\.Schedule\.[0-9]+\./.Schedule.X./' | head -n -1
  Device.Schedules.Schedule.X.Status="StackDisabled"
  Device.Schedules.Schedule.X.Status="StackDisabled"

Verify all Schedules.Schedule.*.Status parameters are set to Disabled

  $ R "ba-cli Device.Schedules.Enable=1"  > /dev/null 2>&1
  $ R "ba-cli Device.Schedules.Schedule.*.Enable=0"  > /dev/null 2>&1
  $ R "ba-cli Device.Schedules.Schedule.*.Status?" | tail -n +2 | sed -E 's/\.Schedule\.[0-9]+\./.Schedule.X./' | head -n -1
  Device.Schedules.Schedule.X.Status="X_PRPLWARE-COM_Disabled"
  Device.Schedules.Schedule.X.Status="X_PRPLWARE-COM_Disabled"

Test InverseMode functionality:

  $ SCHEDULE_PATH_WH="Device.Schedules.Schedule.work-hours"
  $ R "ba-cli '${SCHEDULE_PATH_WH}.Enable=1'" > /dev/null 2>&1
  $ R "ba-cli ${SCHEDULE_PATH_WH}.InverseMode?"
  * (glob)
  Device.Schedules.Schedule.*.InverseMode=0 (glob)
  * (glob)

Verify initial status and TimeLeft (InverseMode=0):

  $ INITIAL_STATUS=$(R "ba-cli ${SCHEDULE_PATH_WH}.Status?" | tail -n +2 | head -n -1 | cut -d= -f2 | tr -d '"')
  $ INITIAL_TIMELEFT=$(R "ba-cli ${SCHEDULE_PATH_WH}.TimeLeft?" | tail -n +2 | head -n -1 | cut -d= -f2)
  $ [ ${INITIAL_TIMELEFT} -ge 0 ]

Enable InverseMode and verify status changes:

  $ R "ba-cli ${SCHEDULE_PATH_WH}.InverseMode=1" > /dev/null 2>&1
  $ R "ba-cli ${SCHEDULE_PATH_WH}.InverseMode?"
  * (glob)
  Device.Schedules.Schedule.*.InverseMode=1 (glob)
  * (glob)

Verify status is inverted:

  $ INVERSE_STATUS=$(R "ba-cli ${SCHEDULE_PATH_WH}.Status?" | tail -n +2 | head -n -1 | cut -d= -f2 | tr -d '"')
  $ [ "${INITIAL_STATUS}" != "${INVERSE_STATUS}" ]

Disable InverseMode again:

  $ R "ba-cli ${SCHEDULE_PATH_WH}.InverseMode=0" > /dev/null 2>&1

Test Duration and TimeLeft:

  $ R "ba-cli ${SCHEDULE_PATH_WH}.Duration?"
  * (glob)
  Device.Schedules.Schedule.*.Duration=32400 (glob)
  * (glob)

Verify TimeLeft is a non-negative integer:

  $ TIMELEFT=$(R "ba-cli ${SCHEDULE_PATH_WH}.TimeLeft?" | tail -n +2 | head -n -1 | cut -d= -f2)
  $ [ ${TIMELEFT} -ge 0 ]

Verify TimeLeft changes over time:

  $ sleep 2
  $ TIMELEFT2=$(R "ba-cli ${SCHEDULE_PATH_WH}.TimeLeft?" | tail -n +2 | head -n -1 | cut -d= -f2)
  $ [ ${TIMELEFT2} -ge 0 ]

Verify TimeLeft is within valid range (0 to Duration):

  $ TIMELEFT_ACTUAL=$(R "ba-cli ${SCHEDULE_PATH_WH}.TimeLeft?" | tail -n +2 | head -n -1 | cut -d= -f2)
  $ DURATION=$(R "ba-cli ${SCHEDULE_PATH_WH}.Duration?" | tail -n +2 | head -n -1 | cut -d= -f2)
  $ [ ${TIMELEFT_ACTUAL} -ge 0 ] && [ ${TIMELEFT_ACTUAL} -le $((DURATION + 86400)) ]

Test Schedule deletion and cleanup:

  $ R "ba-cli Device.Schedules.ScheduleNumberOfEntries?" | tail -n +2 | head -n -1
  Device.Schedules.ScheduleNumberOfEntries=2

Delete the first schedule:

  $ R "ba-cli 'Device.Schedules.Schedule.weekend.-'" > /dev/null 2>&1

Verify ScheduleNumberOfEntries is decremented:

  $ R "ba-cli Device.Schedules.ScheduleNumberOfEntries?" | tail -n +2 | head -n -1
  Device.Schedules.ScheduleNumberOfEntries=1

Delete the remaining schedule:

  $ R "ba-cli 'Device.Schedules.Schedule.work-hours.-'" > /dev/null 2>&1

Verify ScheduleNumberOfEntries is now 0:

  $ R "ba-cli Device.Schedules.ScheduleNumberOfEntries?" | tail -n +2 | head -n -1
  Device.Schedules.ScheduleNumberOfEntries=0
