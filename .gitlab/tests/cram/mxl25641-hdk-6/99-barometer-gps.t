GPS and Barometer Data Model tests

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Verify gpsd is running:

  $ R "pgrep -f gpsd"
  [0-9]+ (re)

Verify tr181-gps is running:

  $ R "pgrep -f tr181-gps"
  [0-9]+ (re)

Verify GPS DM exists:

  $ R "ubus-cli 'Device.X_PRPLWARE-COM_GPS.?' | grep -Ev '^>|^$'"
  Device.X_PRPLWARE-COM_GPS.
  Device.X_PRPLWARE-COM_GPS.AltMSL=""
  Device.X_PRPLWARE-COM_GPS.Data=""

Verify GPS Data parameter exists:

  $ R "ubus-cli 'Device.X_PRPLWARE-COM_GPS.Data?'" | grep -Ev '^>|^$'
  Device.X_PRPLWARE-COM_GPS.Data=""

Verify GPS AltMSL parameter exists:

  $ R "ubus-cli 'Device.X_PRPLWARE-COM_GPS.AltMSL?'" | grep -Ev '^>|^$'
  Device.X_PRPLWARE-COM_GPS.AltMSL=""

Verify tr181-barometer is running:

  $ R "pgrep -f tr181-barometer"
  [0-9]+ (re)

Verify Barometer DM exists:

  $ R "ubus-cli 'Device.X_PRPLWARE-COM_Barometer.?' | grep -Ev '^>|^$'"
  Device.X_PRPLWARE-COM_Barometer.
  Device.X_PRPLWARE-COM_Barometer.Data=""

Verify Barometer Data parameter exists:

  $ R "ubus-cli 'Device.X_PRPLWARE-COM_Barometer.Data?'" | grep -Ev '^>|^$'
  Device.X_PRPLWARE-COM_Barometer.Data=""
