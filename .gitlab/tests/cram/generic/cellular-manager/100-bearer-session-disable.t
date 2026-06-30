Skip on testbed-02 until PCF-2585 is resolved:

  $ if echo "$CI_RUNNER_DESCRIPTION" | grep -q testbed-02; then exit 80; fi

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting 100-bearer-session-disable.t testcase"

Verify current bearer session status:

  $ R "ba-cli -l -j Device.SessionManagement.Session.1.Enable\? | sed '/^$/d'"
  [{"Device.SessionManagement.Session.1.":{"Enable":1}}]

Disable the bearer session:

  $ R "ba-cli -l -j Device.SessionManagement.Session.1.Enable=0 | sed '/^$/d'"
  [{"Device.SessionManagement.Session.1.":{"Enable":0}}]

Enable the bearer session again:

  $ R  "ba-cli -l -j Device.SessionManagement.Session.1.Enable=1 | sed '/^$/d'"
  [{"Device.SessionManagement.Session.1.":{"Enable":1}}]

  $ R logger -t cram "Completed with 100-bearer-session-disable.t testcase"
