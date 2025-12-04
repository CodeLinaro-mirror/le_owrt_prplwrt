Create R alias and restart datacollect-agent:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting datacollect tests ..."

  $ R "/etc/init.d/datacollect-agent restart"

Check initial data model:

  $ R "ba-cli -j -l 'DataCollect.?' | sed '/^$/d'"
  [{"DataCollect.":{"AhDSourceNumberOfEntries":0,"Enable":1,"Status":"Enabled"}}]

  $ R "ba-cli 'DataCollect.?' | sed '/^$/d'" | sed '/^$/d' | tail -n +2
  DataCollect.
  DataCollect.AhDSourceNumberOfEntries=0
  DataCollect.Enable=1
  DataCollect.Status="Enabled"

Add new AhDSource instance in data model:

  $ R "ba-cli 'DataCollect.AhDSource.+{Name=ahdsource,Alias=ahdsource}'" | sed '/^$/d' | tail -n +2
  DataCollect.AhDSource.1.
  DataCollect.AhDSource.1.Alias="ahdsource"

Send a message:

  $ R "ba-cli 'DataCollect.logEvent(source=ahdsource,message=hello,message_len=6,data_id=id,cp_type=0)'" | sed '/^$/d' | tail -n +2
  DataCollect.logEvent() returned
  [
      ""
  ]

Cleanup data model instances:

  $ R "ba-cli 'DataCollect.AhDSource.ahdsource.-'" > /dev/null

  $ R logger -t cram "Finished datacollect tests ..."
