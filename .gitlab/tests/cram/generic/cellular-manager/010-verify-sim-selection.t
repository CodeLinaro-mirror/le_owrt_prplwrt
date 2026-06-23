Skip on testbed-02 until PCF-2585 is resolved:

  $ if echo "$CI_RUNNER_DESCRIPTION" | grep -q testbed-02; then exit 80; fi

Skip on Freedom until PCF-2663 is resolved (5G modem not enumerated on PCIe):

  $ [ "$DUT_BOARD" = "wnc-freedom" ] && exit 80
  [1]

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting 010-verify-sim-selection.t testcase"

Read and verify SIM Reference list:

  $ R "ba-cli -l -j Cellular.Interface.1.SIMReferenceList\? | sed '/^$/d'"
  [{"Cellular.Interface.1.":{"SIMReferenceList":"Device.TrustedElements.SIM.1."}}]

Read and verify AccessPoint:

  $ R "ba-cli -l -j Cellular.AccessPoint.1.Enable\? | sed '/^$/d'"
  [{"Cellular.AccessPoint.1.":{"Enable":1}}]

  $ R "ba-cli -l -j Cellular.AccessPoint.2.Enable\? | sed '/^$/d'"
  [{"Cellular.AccessPoint.2.":{"Enable":1}}]

Read and verify cellular interface status:

  $ R "ba-cli -l -j Cellular.Interface.1.Status\? | sed '/^$/d'"
  [{"Cellular.Interface.1.":{"Status":"Up"}}]

Read and verify SIM under TrustedElements:

  $ R "ba-cli -l -j TrustedElements.SIM.1.Alias\? | sed '/^$/d'"
  [{"TrustedElements.SIM.1.":{"Alias":"cpe-SIM-1"}}]

Verify NetworkInUse:

  $ R "ba-cli -l -j Cellular.Interface.1.NetworkInUse\? | sed '/^$/d'"
  \[\{"Cellular.Interface.1.":\{"NetworkInUse":".+"\}\}\] (re)

  $ R logger -t cram "Completed with 010-verify-sim-selection.t testcase"
