tr181-barometer data path: fake IIO device and verify the Barometer data model

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "$TESTDIR/../lib/dm.sh"
  $ . "$TESTDIR/../lib/sensors.sh"

  $ R logger -t cram "Starting tr181-barometer test ..."

  $ R "pgrep -f tr181-barometer >/dev/null && echo running"
  running

  $ R logger -t cram "Verify Barometer DM exists:"

  $ R "ubus-cli 'Device.X_PRPLWARE-COM_Barometer.?' | grep -q '^Device.X_PRPLWARE-COM_Barometer\.$' && echo Barometer object present"
  Barometer object present

  $ R logger -t cram "Test tr181-barometer with a dummy pressure sensor path"

  $ baro_fixture_start 91.392109375 15000
  barometer fixture started

  $ baro_fixture_path_check
  BAROMETER_IIO_PATH=/tmp/iio
  barometer fixture path exported

  $ sleep 5

  $ R "/etc/init.d/deviceinfo-manager restart >/dev/null 2>&1 && echo restarted deviceinfo-manager"
  restarted deviceinfo-manager

  $ dm_wait Device.X_PRPLWARE-COM_Barometer.Data '91392.1094'
  Device.X_PRPLWARE-COM_Barometer.Data matched /91392.1094/ after * (glob)

  $ dm_get Device.X_PRPLWARE-COM_Barometer.Data | senml_entry pressure
  <senml bt="*" n="pressure" u="Pa" v="91392.1094"></senml> (glob)

  $ dm_get Device.X_PRPLWARE-COM_Barometer.Data | senml_entry barometricHeight
  <senml n="barometricHeight" u="m" v="861.7078"></senml> (glob)

  $ dm_get Device.X_PRPLWARE-COM_Barometer.Data | senml_entry verticalUncertainty
  <senml n="verticalUncertainty" u="m" v="3.5000"></senml> (glob)

  $ dm_get Device.X_PRPLWARE-COM_Barometer.Data | senml_entry heightType
  <senml n="heightType" vs="AMSL"></senml>

  $ sleep 3

  $ R logger -t cram "Check if current Barometric data is updated in DeviceInfo.Location.2."
  $ dm_wait Device.DeviceInfo.Location.2.DataObject '91392.1094'
  Device.DeviceInfo.Location.2.DataObject matched /91392.1094/ after * (glob)

  $ test "$(dm_get Device.X_PRPLWARE-COM_Barometer.Data | senml_value pressure)" = "$(dm_get Device.DeviceInfo.Location.2.DataObject | senml_value pressure)" && echo "Barometer pressure matches DeviceInfo.Location.2"
  Barometer pressure matches DeviceInfo.Location.2

  $ test "$(dm_get Device.X_PRPLWARE-COM_Barometer.Data | senml_value verticalUncertainty)" = "$(dm_get Device.DeviceInfo.Location.2.DataObject | senml_value verticalUncertainty)" && echo "Barometer vertical uncertainty matches DeviceInfo.Location.2"
  Barometer vertical uncertainty matches DeviceInfo.Location.2

  $ baro_fixture_stop
  barometer fixture stopped

