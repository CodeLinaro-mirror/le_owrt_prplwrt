Skip on testbed-02 until PCF-2585 is resolved:

  $ if echo "$CI_RUNNER_DESCRIPTION" | grep -q testbed-02; then exit 80; fi

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting 045-verify-roaming-upstream-status.t testcase"

Read and verify Cellular RoamingStatus:

  $ R "ba-cli -l -j Cellular.RoamingStatus\? | sed '/^$/d'"
  [{"Cellular.":{"RoamingStatus":"Home"}}]

Read and verify Cellular.InterfaceNumberOfEntries:

  $ R "ba-cli -l -j Cellular.InterfaceNumberOfEntries\? | sed '/^$/d'"
  [{"Cellular.":{"InterfaceNumberOfEntries":1}}]

  $ R "ba-cli -l -j Cellular.Interface.1.Upstream\? | sed '/^$/d'"
  [{"Cellular.Interface.1.":{"Upstream":1}}]

  $ R logger -t cram "Completed with 045-verify-roaming-upstream-status.t test"
