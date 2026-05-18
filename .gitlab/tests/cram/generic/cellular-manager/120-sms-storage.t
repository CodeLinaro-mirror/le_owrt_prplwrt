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
