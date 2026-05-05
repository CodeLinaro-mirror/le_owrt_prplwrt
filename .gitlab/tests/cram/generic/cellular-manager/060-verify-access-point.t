Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting with 060-verify-access-point.t testcase"

Read and verify AccessPointNumberOfEntries:

  $ R "ba-cli -j -l Cellular.AccessPointNumberOfEntries\? | sed '/^$/d'"
  [{"Cellular.":{"AccessPointNumberOfEntries":2}}]

  $ R "ba-cli -j -l Cellular.AccessPoint.\?" | jq --sort-keys '.[0]'
  {
    "Cellular.AccessPoint.1.": {
      "APN": ".+", (re)
      "Alias": ".+", (re)
      "Enable": 1,
      "IPVersion": -1,
      "Interface": "Device.Cellular.Interface.\d+.", (re)
      "Password": "",
      "Proxy": "",
      "ProxyPort": 0,
      "Type": "default",
      "Username": ""
    },
    "Cellular.AccessPoint.2.": {
      "APN": ".+", (re)
      "Alias": ".+", (re)
      "Enable": 1,
      "IPVersion": -1,
      "Interface": "Device.Cellular.Interface.\d+.", (re)
      "Password": "",
      "Proxy": "",
      "ProxyPort": 0,
      "Type": "ims",
      "Username": ""
    }
  }

Verify AccessPoint IPVersion and Type:

  $ R "ba-cli -j -l Cellular.AccessPoint.1.IPVersion\? | sed '/^$/d'"
  [{"Cellular.AccessPoint.1.":{"IPVersion":-1}}]

  $ R "ba-cli -j -l Cellular.AccessPoint.1.Type\? | sed '/^$/d'"
  [{"Cellular.AccessPoint.1.":{"Type":"default"}}]

  $ R logger -t cram "Completed with 060-verify-access-point.t testcase"
