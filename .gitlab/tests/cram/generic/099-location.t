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

  $ R "ubus-cli Device.DeviceInfo.Location.1.ExternalProtocol=\"CWMP\"" 2>&1 | grep "is read only"
  ERROR: set Device.DeviceInfo.Location.1.ExternalProtocol failed (15 - is read only)

  $ R "ubus-cli Device.DeviceInfo.Location.1.ExternalSource=\"https://192.168.1.10/acs\"" 2>&1 | grep "is read only"
  ERROR: set Device.DeviceInfo.Location.1.ExternalSource failed (15 - is read only)

  $ R "ubus-cli Device.DeviceInfo.Location.1.Source=\"External\"" 2>&1 | grep "is read only"
  ERROR: set Device.DeviceInfo.Location.1.Source failed (15 - is read only)

  $ R "ubus-cli Device.DeviceInfo.Location.1.AcquiredTime=\"2026-09-17T19:32:17Z\"" 2>&1 | grep "is read only"
  ERROR: set Device.DeviceInfo.Location.1.AcquiredTime failed (15 - is read only)
