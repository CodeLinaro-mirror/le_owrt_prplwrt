Skip on testbed-02 until PCF-2585 is resolved:

  $ if echo "$CI_RUNNER_DESCRIPTION" | grep -q testbed-02; then exit 80; fi

Create R Alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting 130-sms-message-attributes.t testcase"

Verify SMS message attributes:

  $ R "ba-cli -l -j Cellular.Interface.1.SMS.Message.1.\?" | jq --sort-keys '.[0]'
  {
    "Cellular.Interface.1.SMS.Message.1.": {
      "Alias": "cpe-Message-1",
      "Receiver": "\d+", (re)
      "Sender": ".+", (re)
      "Status": "Received",
      "StorageRef": "Device.Cellular.Interface.1.SMS.Storage.\d+", (re)
      "Text": "<text>",
      "TimeStamp": "\d+-\d+-\d+T\d+:\d+:\d+Z", (re)
      "Type": "PointToPoint"
    }
  }

  $ R logger -t cram "Completed with 130-sms-message-attributes.t testcase"
