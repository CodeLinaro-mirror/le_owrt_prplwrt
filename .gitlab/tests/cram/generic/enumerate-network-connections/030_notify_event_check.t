Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ logger -t cram "Starting with 030-notify-event.t testcase"

Create a enumerate notify flow query for tracking ssh connection:

  $ NotifyInstanceId=$(R "ba-cli -l -j ConnectionTrackingQuery.NotifyFlow.+{Name=SSH_Query,"\
  > " DestIP=$TARGET_LAN_IP} | sed '/^$/d' | sed -n 's/.*NotifyFlow\.\([0-9]\+\)\..*/\1/p'")

Subscribe to the events for the NotifyFlow query created:

  $ R "ubus -t 8 subscribe ConnectionTrackingQuery.NotifyFlow.$NotifyInstanceId > /tmp/conntrack_events.log &"

Initiate connections not matching NotifyFlow query:

  $ R "nslookup -query=AAAA prplfoundation.org  > /dev/null || true"

Wait for ubus event subscription to complete:

  $ sleep 6

Verify only expected ssh events are captured in ubus:

  $ R "grep 'ConntrackNotifyEvent' /tmp/conntrack_events.log | "\
  > "grep -v '\"DestIP\":\"$TARGET_LAN_IP\".*22' || true"

Print the contents of /tmp/conntrack_events.log:
  $ cat /tmp/conntrack_events.log

Delete the NotifyFlow entries created:

  $ R "ba-cli -l -j ConnectionTrackingQuery.NotifyFlow.*.- | sed '/^$/d'"
  \["ConnectionTrackingQuery.NotifyFlow.\d+."\] (re)

  $ R logger -t cram "Completed with 030-notify-event.t testcase"
