Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting with Flashwear monitoring tests"

Read the Flashwear monitoring object parameters
  $ R "ba-cli --less --json Hardware.FlashDevice.?" | jq --sort-keys '.[0]'
  {
    "Hardware.FlashDevice.1.": {
      "Alias": "cpe.+", (re)
      "FlashType": "eMMC",
      "Name": ".+", (re)
      "Path": ".+", (re)
      "VendorID": ".+", (re)
      "Version": "\d+.\d+.*\d*" (re)
    },
    "Hardware.FlashDevice.1.Health.": {
      "BadBlocksThreshold": \d+, (re)
      "Enabled": 1,
      "HealthStatus": "Normal",
      "LifeTimeA": "Not Defined",
      "LifeTimeAHex": 0,
      "LifeTimeAThreshold": 10,
      "LifeTimeB": "Not Defined",
      "LifeTimeBHex": 0,
      "LifeTimeBThreshold": 10,
      "MonitoringStatus": ".+", (re)
      "PreEolThreshold": 10,
      "TotalBadBlocks": \d+, (re)
      "TotalGoodBlocks": \d+, (re)
      "eMMCPreEoLInfo": ".*" (re)
    }
  }

  $ R logger -t cram "Tests finished!"

