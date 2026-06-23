Skip on testbed-02 until PCF-2585 is resolved:

  $ if echo "$CI_RUNNER_DESCRIPTION" | grep -q testbed-02; then exit 80; fi

Skip on Freedom until PCF-2663 is resolved (5G modem not enumerated on PCIe):

  $ [ "$DUT_BOARD" = "wnc-freedom" ] && exit 80
  [1]

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t "Starting 110-access-technology.t testcase"

Verify default AccessTechnology:

  $ R "ba-cli -l -j Cellular.Interface.1.PreferredAccessTechnology\? | sed '/^$/d'"
  [{"Cellular.Interface.1.":{"PreferredAccessTechnology":"Auto"}}]

Verify SupportedAccessTechnologies:

  $ R "ba-cli -l -j Cellular.Interface.1.SupportedAccessTechnologies\? | sed '/^$/d'"
  [{"Cellular.Interface.1.":{"SupportedAccessTechnologies":"UMTS,LTE,NR"}}]

Verify bearer session information:

  $ R "ba-cli -j -l Device.SessionManagement.SessionNumberOfEntries\? | sed '/^$/d'"
  [{"Device.SessionManagement.":{"SessionNumberOfEntries":1}}]

Change AccessTechnology to 4G:

  $ R "ba-cli -l -j Cellular.Interface.1.PreferredAccessTechnology=\"LTE\" | sed '/^$/d'"
  [{"Cellular.Interface.1.":{"PreferredAccessTechnology":"LTE"}}]

Verify CurrentAccessTechnology:

  $ R "ba-cli -l -j Cellular.Interface.1.CurrentAccessTechnology\? | sed '/^$/d'"
  [{"Cellular.Interface.1.":{"CurrentAccessTechnology":"LTE"}}]

Verify SupportedAccessTechnologies:

  $ R "ba-cli -l -j Cellular.Interface.1.SupportedAccessTechnologies\? | sed '/^$/d'"
  [{"Cellular.Interface.1.":{"SupportedAccessTechnologies":"UMTS,LTE,NR"}}]

Verify bearer session information:

  $ R "ba-cli -j -l Device.SessionManagement.SessionNumberOfEntries\? | sed '/^$/d'"
  [{"Device.SessionManagement.":{"SessionNumberOfEntries":1}}]

  $ R logger -t "Completed with 110-access-technology.t testcase"
