Skip on testbed-02 until PCF-2585 is resolved:

  $ if echo "$CI_RUNNER_DESCRIPTION" | grep -q testbed-02; then exit 80; fi

Skip on Freedom until PCF-2663 is resolved (5G modem not enumerated on PCIe):

  $ [ "$DUT_BOARD" = "wnc-freedom" ] && exit 80
  [1]

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting 020-verify-usim-data-elements.t testcase"

Read and verify TrustedElements:

  $ R "ba-cli -l -j TrustedElements.SIM.1.IMSI\? | sed '/^$/d'"
  \[\{"TrustedElements.SIM.1.":\{"IMSI":"\d{15}"\}\}\] (re)

  $ R "ba-cli -l -j TrustedElements.SIM.1.ICCID\? | sed '/^$/d'"
  \[\{"TrustedElements.SIM.1.":\{"ICCID":"\d*"\}\}\] (re)

  $ R "ba-cli -l -j TrustedElements.SIM.1.Status\? | sed '/^$/d'"
  [{"TrustedElements.SIM.1.":{"Status":"Valid"}}]

  $ R logger -t cram "Completed with 020-verify-usim-data-elements.t testcase"
