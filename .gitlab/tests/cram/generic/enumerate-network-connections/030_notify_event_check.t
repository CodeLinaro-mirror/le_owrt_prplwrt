Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting with 030-notify-event.t testcase"

Pre-clean any leftover monitor processes:

  $ R "pkill -f '/tmp/conn_config.lua' >/dev/null 2>&1 || true"
  [255]

  $ R "rm -f /tmp/conntrack_events.log /tmp/conn_config.lua"

Create and fetch NotifyFlow instance:

  $ NotifyInstanceId=$(R "ba-cli -l -j 'ConnectionTrackingQuery.NotifyFlow.+{Name=SSH_Query,DestIP=$TARGET_LAN_IP}' | sed '/^$/d' | sed -n 's/.*NotifyFlow\.\([0-9]\+\)\..*/\1/p' | head -1")

  $ echo "NotifyInstanceId=$NotifyInstanceId"
  NotifyInstanceId=[0-9]+ (re)

  $ test -n "$NotifyInstanceId" || echo "ERROR: Instance not created"

Create amx_monitor_dm config dynamically:

  $ R "cat << 'EOF' > /tmp/conn_config.lua
  > return {
  >     log_file = \"/tmp/conntrack_events.log\",
  >     objects = {{
  >         path = \"ConnectionTrackingQuery.NotifyFlow.$NotifyInstanceId\",
  >         filter = 'notification == \"ConntrackNotifyEvent\"'
  >     }}
  > }
  > EOF"

Start amx_monitor_dm:

  $ R "amx_monitor_dm /tmp/conn_config.lua &"

  $ sleep 5

Trigger unrelated traffic:

  $ R "nslookup -query=AAAA prplfoundation.org > /dev/null || true"

Wait for monitoring output:

  $ sleep 6

Verify log file has content:

  $ R "test -s /tmp/conntrack_events.log && echo 'Log file has content' || echo 'Log file is empty'"
  Log file has content

Verify output format:

  $ R "head -1 /tmp/conntrack_events.log"
  .*ConnectionTrackingQuery.NotifyFlow.* (re)

Optional: verify expected keyword:

  $ R "grep -q 'NotifyFlow' /tmp/conntrack_events.log && echo 'event_found'"
  event_found

Kill ONLY this test’s monitor processes:

  $ R "pkill -9 -f '/tmp/conn_config.lua' >/dev/null 2>&1 || true"
  [255]

Wait until processes are fully cleaned:

  $ R "for i in 1 2 3 4 5 6 7 8 9 10; do pgrep -f '/tmp/conn_config.lua' >/dev/null || break; sleep 1; done"

Cleanup files:

  $ R "rm -f /tmp/conntrack_events.log /tmp/conn_config.lua"

Delete NotifyFlow entries:

  $ R "ba-cli -l -j ConnectionTrackingQuery.NotifyFlow.*.- | sed '/^$/d'"
  \["ConnectionTrackingQuery.NotifyFlow.\d+."\] (re)

  $ R "logger -t cram \"Completed with 030-notify-event.t testcase\""

