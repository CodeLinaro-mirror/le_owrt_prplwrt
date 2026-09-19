tr181-gps data path: feed canned NMEA to gpsd and verify the GPS data model

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "$TESTDIR/../lib/dm.sh"
  $ . "$TESTDIR/../lib/sensors.sh"

  $ R logger -t cram "Starting tr181-gps test ..."

  $ R "pgrep -f gpsd >/dev/null && pgrep -f tr181-gps >/dev/null && echo running"
  running

  $ R logger -t cram "Verify GPS DM exists:"

  $ R "ubus-cli 'Device.X_PRPLWARE-COM_GPS.?' | grep -q '^Device.X_PRPLWARE-COM_GPS\.$' && echo GPS object present"
  GPS object present
 
  $ R logger -t cram "Start gps feed"

Canned fix: 50.0755 N, 14.4378 E, 200 m MSL, 3D with 8 satellites. RMC gives
date/time, GGA altitude, and GST a 1.5 m by 1.2 m error ellipse at 45 degrees
that tr181-gps puts into PIDF-LO (without GST it falls back to a 50 m circle).
gpsd reads it from a FIFO:

  $ gps_feed_start "$TESTDIR/../lib/fix-prague.nmea"
  gps feed started

  $ gps_fix_check
  mode=3 lat=50.0755 lon=14.4378

  $ svc_restart tr181-gps
  tr181-gps restarted

  $ sleep 5

  $ R "/etc/init.d/deviceinfo-manager restart >/dev/null 2>&1 && echo restarted deviceinfo-manager"
  restarted deviceinfo-manager

  $ sleep 5

  $ dm_get Device.X_PRPLWARE-COM_GPS.Data | pidf_pos
  <gml:pos>50.07550000 14.43780000</gml:pos>

  $ dm_get Device.X_PRPLWARE-COM_GPS.Data | pidf_method
  <gp:method>gpsd</gp:method>

GST carries deterministic ellipse axes and orientation into GPS.Data:

  $ dm_get Device.X_PRPLWARE-COM_GPS.Data | tr '\n' ' ' | xml_entry '<gs:semiMajorAxis [^>]*> *1.500 *</gs:semiMajorAxis>'
  <gs:semiMajorAxis uom="urn:ogc:def:uom:EPSG::9001"> 1.500 </gs:semiMajorAxis>

  $ dm_get Device.X_PRPLWARE-COM_GPS.Data | tr '\n' ' ' | xml_entry '<gs:semiMinorAxis [^>]*> *1.200 *</gs:semiMinorAxis>'
  <gs:semiMinorAxis uom="urn:ogc:def:uom:EPSG::9001"> 1.200 </gs:semiMinorAxis>

  $ dm_get Device.X_PRPLWARE-COM_GPS.Data | tr '\n' ' ' | xml_entry '<gs:orientation [^>]*> *45.00 *</gs:orientation>'
  <gs:orientation uom="urn:ogc:def:uom:EPSG::9102"> 45.00 </gs:orientation>

  $ dm_get Device.X_PRPLWARE-COM_GPS.AltMSL
  200.0000

  $ R logger -t cram "Check if current GNSS data is updated in DeviceInfo.Location.1."

  $ dm_get Device.DeviceInfo.Location.1.DataObject | pidf_pos
  <gml:pos>50.07550000 14.43780000</gml:pos>

  $ test "$(dm_get Device.X_PRPLWARE-COM_GPS.Data)" = "$(dm_get Device.DeviceInfo.Location.1.DataObject)" && echo "GPS data matches DeviceInfo.Location.1"
  GPS data matches DeviceInfo.Location.1

  $ gps_feed_stop
  gps feed stopped
