Skip on testbed-02 until PCF-2585 is resolved:

  $ if echo "$CI_RUNNER_DESCRIPTION" | grep -q testbed-02; then exit 80; fi

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting 070-verify-data-session.t testcase"

Read and verify SessionNumberOfEntries

  $ R "ba-cli -j -l Device.SessionManagement.SessionNumberOfEntries\? | sed '/^$/d'"
  [{"Device.SessionManagement.":{"SessionNumberOfEntries":1}}]

  $ R "ba-cli -j -l Device.SessionManagement.\?" | jq --sort-keys '.[0]' | grep SessionNumberOfEntries
      "SessionNumberOfEntries": [1-9]+ (re)

  $ R "ba-cli -j -l Device.SessionManagement.Session.*.Enable\? | sed '/^$/d'"
  [{"Device.SessionManagement.Session.1.":{"Enable":1}}]

  $ R logger -t cram "Completed with 070-verify-data-session.t testcase"
