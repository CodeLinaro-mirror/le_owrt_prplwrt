Skip on testbed-02 until PCF-2585 is resolved:

  $ if echo "$CI_RUNNER_DESCRIPTION" | grep -q testbed-02; then exit 80; fi

Skip on Freedom until PCF-2663 is resolved (5G modem not enumerated on PCIe):

  $ [ "$DUT_BOARD" = "wnc-freedom" ] && exit 80
  [1]

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting 120-sms-storage.t testcase"

Verify SMS storage attributes:

  $ R "ba-cli -j -l Cellular.Interface.1.SMS.Storage.1.\?" | jq --sort-keys '.[0]'
  {
    "Cellular.Interface.1.SMS.Storage.1.": {
      "Alias": ".+", (re)
      "AvailableCapacity": \d+, (re)
      "Capacity": \d+, (re)
      "Location": ".+", (re)
      "StorageAvailable": \d+ (re)
    }
  }

  $ R logger -t cram  "Completed with 120-sms-storage.t testcase"
