Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting with amx-processmonitoring pre-checks"

Ensure ProcessMonitor.Test.i.FailAction does not have REBOOT action:

  $ R "ba-cli -l ProcessMonitor.Test.*.FailAction\? | "\
  > "grep -vE '(RESTART|NONE)' | sed '/^$/d'"

Verify any process monitoring failures observed before starting with tests:

  $ R "grep \"amx-processmonitor: process - \[!\]Test.*failed too often,"\
  > " executing action\" /var/log/messages* /var/log/messagess.? 2>/dev/null" \
  > "|| true"

  $ R logger -t cram "Pre-checks for amx-processmonitoring tests completed"
