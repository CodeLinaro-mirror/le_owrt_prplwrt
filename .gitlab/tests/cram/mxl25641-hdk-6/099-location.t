Location DeviceInfo Data Model tests

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Verify deviceinfo-manager is running:

  $ R "pgrep -f deviceinfo-manager"
  [0-9]+ (re)

Verify exactly two Location instances exist by default:

  $ R "ubus-cli 'Device.DeviceInfo.Location.?' | grep -E '^Device\\.DeviceInfo\\.Location\\.[0-9]+\\.$' | wc -l"
  2

Verify GPS location source:

  $ R "ubus-cli 'Device.DeviceInfo.Location.1.Source?'" | grep -Ev '^>|^$'
  Device.DeviceInfo.Location.1.Source="GPS"

Verify Barometer location source:

  $ R "ubus-cli 'Device.DeviceInfo.Location.2.Source?'" | grep -Ev '^>|^$'
  Device.DeviceInfo.Location.2.Source="Barometer"

Verify DataObject is empty when no source data is available:

  $ R "ubus-cli 'Device.DeviceInfo.Location.1.DataObject?'" | grep -Ev '^>|^$'
  Device.DeviceInfo.Location.1.DataObject=""

Verify AcquiredTime is unknown when DataObject is empty:

  $ R "ubus-cli 'Device.DeviceInfo.Location.1.AcquiredTime?'" | grep -Ev '^>|^$'
  Device.DeviceInfo.Location.1.AcquiredTime="0001-01-01T00:00:00Z"

Verify Barometer DataObject is empty when no source data is available:

  $ R "ubus-cli 'Device.DeviceInfo.Location.2.DataObject?'" | grep -Ev '^>|^$'
  Device.DeviceInfo.Location.2.DataObject=""

Verify Barometer AcquiredTime is unknown when DataObject is empty:

  $ R "ubus-cli 'Device.DeviceInfo.Location.2.AcquiredTime?'" | grep -Ev '^>|^$'
  Device.DeviceInfo.Location.2.AcquiredTime="0001-01-01T00:00:00Z"
