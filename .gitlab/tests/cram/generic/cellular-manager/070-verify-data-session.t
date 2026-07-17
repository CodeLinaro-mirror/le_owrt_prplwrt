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

Get the current IP Interface failover enable value to restore back once cram completed

  $ IPFailoverEnable=$(R "ba-cli -l IP.Interface.failover.Enable? | sed '/^$/d'")

Toggle the IP Interface failover enable to establish Traffic via Bearer Session

  $ R "ba-cli -l IP.Interface.failover.Enable=0 >/dev/null 2>&1"
  $ R "ba-cli -l IP.Interface.failover.Enable=1 >/dev/null 2>&1"

Wait 10 seconds for the bearer session route to turn functional:

  $ sleep 10

  $ CellularInterface=$(R "ba-cli -l Device.SessionManagement.Session.1.Name? | sed '/^$/d'")

check whether the Cellular Bearer Interface status is up

  $ R "ba-cli -j -l Device.SessionManagement.Session.*.Status\? | sed '/^$/d'"
  [{"Device.SessionManagement.Session.1.":{"Status":"Up"}}]

Verify IP4/IP6 address being assigned for Cellular Bearer session and Its Status is Up
  $ R "ip -4 addr show dev ${CellularInterface} scope global | grep -q 'inet ' && echo $?"
  0

  $ R "ip -6 addr show dev ${CellularInterface} scope global | grep -q 'inet6 ' && echo $?"
  0

Check Defalt route established for Cellular Bearer Session connected

  $ R "ip route | grep -qE \"^default.*dev ${CellularInterface}\" && echo $?"
  0

  $ R "ip -6 route | grep -qE \"^default.*dev ${CellularInterface}\" && echo $?"
  0

Clean up, Revert back the IP Failover Enable back to original value

  $ R "ba-cli -l IP.Interface.failover.Enable=${IPFailoverEnable} >/dev/null 2>&1"

  $ R logger -t cram "Completed with 070-verify-data-session.t testcase"
