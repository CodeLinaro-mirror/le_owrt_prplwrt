Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting with Flashwear monitoring tests"

Enable Flashwear monitoring:

  $ R "ba-cli -l Device.Hardware.X_PRPLWARE-COM_FlashDevice.1.Health.Enabled=1" | sed '/^$/d'
  1

Read Flashwear monitoring object:

  $ FlashDevice=$(R "ba-cli --less --json Device.Hardware.X_PRPLWARE-COM_FlashDevice.?")

  $ logger -t cram "Device.Hardware.X_PRPLWARE-COM_FlashDevice. contents read "$FlashDevice

Wait for some 10 seconds to obtain the flashwear monitoring update:

  $ sleep 10

Read and verify Flashwear monitoring object parameters:

  $ R "ba-cli --less --json Device.Hardware.X_PRPLWARE-COM_FlashDevice.?" | jq --sort-keys '.[0]'
  {
    "Device.Hardware.X_PRPLWARE-COM_FlashDevice.": {},
    "Device.Hardware.X_PRPLWARE-COM_FlashDevice.1.": {
      "Alias": "cpe.+", (re)
      "FlashType": "eMMC",
      "Name": ".+", (re)
      "Path": ".+", (re)
      "Version": "v\d+\.\d+" (re)
    },
    "Device.Hardware.X_PRPLWARE-COM_FlashDevice.1.Health.": {
      "BadBlocksThreshold": \d+, (re)
      "Enabled": 1,
      "HealthStatus": "Normal",
      "LifeTimeA": ".+", (re)
      "LifeTimeAHex": [a-z0-9]+, (re)
      "LifeTimeAThreshold": \d+, (re)
      "LifeTimeB": ".+", (re)
      "LifeTimeBHex": [a-z0-9]+, (re)
      "LifeTimeBThreshold": \d+, (re)
      "MonitoringStatus": ".+", (re)
      "PreEolThreshold": \d+, (re)
      "TotalBadBlocks": 0,
      "TotalGoodBlocks": 0,
      "eMMCPreEoLInfo": ".+" (re)
    }
  }

Disable Flashwear monitoring:

  $ R "ba-cli -l Device.Hardware.X_PRPLWARE-COM_FlashDevice.1.Health.Enabled=0" | sed '/^$/d'
  0

  $ R logger -t cram "Flashwear monitoring test finished"
