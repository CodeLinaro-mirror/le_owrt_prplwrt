Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting with Flashwear monitoring tests"

Enable Flashwear monitoring
  $ R "ba-cli -l Device.X_PRPLWARE-COM_Hardware.FlashDevice.1.Health.Enabled=1" | sed '/^$/d'
  1

Read Flashwear monitoring object
  $ R "ba-cli --less --json Device.X_PRPLWARE-COM_Hardware.FlashDevice.?"


Read the Flashwear monitoring object parameters
  $ R "ba-cli --less --json Device.X_PRPLWARE-COM_Hardware.FlashDevice.?" | jq --sort-keys '.[0]'
  {
    "Device.X_PRPLWARE-COM_Hardware.FlashDevice.1.": {
      "Alias": "cpe.+", (re)
      "FlashType": "eMMC",
      "Name": ".+", (re)
      "Path": ".+", (re)
      "Version": "v\d+\.\d+" (re)
    },
    "Device.X_PRPLWARE-COM_Hardware.FlashDevice.1.Health.": {
      "BadBlocksThreshold": \d+, (re)
      "Enabled": 1,
      "HealthStatus": "Normal",
      "LifeTimeA": ".+", (re)
      "LifeTimeAHex": [a-z0-9]+, (re)
      "LifeTimeAThreshold": \d+,
      "LifeTimeB": ".+", (re)
      "LifeTimeBHex": [a-z0-9]+, (re)
      "LifeTimeBThreshold": \d+,
      "MonitoringStatus": ".+", (re)
      "PreEolThreshold": \d+, (re)
      "TotalBadBlocks": "",
      "TotalGoodBlocks": "",
      "eMMCPreEoLInfo": ".+" (re)
    }
  }

  $ R logger -t cram "Tests finished!"

