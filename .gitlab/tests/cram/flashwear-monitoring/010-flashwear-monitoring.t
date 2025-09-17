Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting with Flashwear monitoring tests"

Read the Flashwear monitoring object parameters
  $ R "ba-cli -l -j Device.Hardware.? | jsonfilter -e @[0]'[\"Device.Hardware.\"].NumberOfFlashDeviceEntries' -e @[0]'[\"Device.Hardware.FlashDevice.1.\"].Alias'"
  \d+ (re)
  .+ (re)

  $ R "ba-cli -l -j Device.Hardware.? | jsonfilter -e @[0]'[\"Device.Hardware.FlashDevice.1.\"].FlashType' -e @[0]'[\"Device.Hardware.FlashDevice.1.\"].Name' -e @[0]'[\"Device.Hardware.FlashDevice.1.\"].Path' -e @[0]'[\"Device.Hardware.FlashDevice.1.\"].Version'"
  eMMC
  .+ (re)
  .+ (re)
  .+ (re)

  $ R "ba-cli -l -j Device.Hardware.? | jsonfilter -e @[0]'[\"Device.Hardware.FlashDevice.1.Health.\"].Enabled' -e @[0]'[\"Device.Hardware.FlashDevice.1.Health.\"].HealthStatus' -e @[0]'[\"Device.Hardware.FlashDevice.1.Health.\"].LifeTimeA'"
  1
  Normal
  .+ (re)

  $ R "ba-cli -l -j Device.Hardware.? | jsonfilter -e @[0]'[\"Device.Hardware.FlashDevice.1.Health.\"].LifeTimeAHex' -e @[0]'[\"Device.Hardware.FlashDevice.1.Health.\"].LifeTimeAThreshold' -e @[0]'[\"Device.Hardware.FlashDevice.1.Health.\"].LifeTimeB'"
  .+ (re)
  .+ (re)
  .+ (re)

  $ R "ba-cli -l -j Device.Hardware.? | jsonfilter -e @[0]'[\"Device.Hardware.FlashDevice.1.Health.\"].LifeTimeBHex' -e @[0]'[\"Device.Hardware.FlashDevice.1.Health.\"].LifeTimeBThreshold' -e @[0]'[\"Device.Hardware.FlashDevice.1.Health.\"].MonitoringStatus'"
  .+ (re)
  .+ (re)
  .+ (re)

  $ R "ba-cli -l -j Device.Hardware.? | jsonfilter -e @[0]'[\"Device.Hardware.FlashDevice.1.Health.\"].PreEolThreshold' -e @[0]'[\"Device.Hardware.FlashDevice.1.Health.\"].eMMCPreEoLInfo'"
  .+ (re)
  Normal

  $ R logger -t cram "Tests finished!"

