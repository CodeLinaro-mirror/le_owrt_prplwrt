# BulkData MQTT Profile Test Suite
# =================================

# This test suite validates the TR-181 BulkData module with MQTT transport,
# covering the full lifecycle of a BulkData profile: creation, configuration,
# parameter collection, report publishing, and teardown.

# Architecture:
#   - BulkData module collects device parameters at a fixed reporting interval
#   - Reports are encoded as JSON and published via MQTT to the local broker
#   - mosquitto_sub running on the device captures the published report
#   - Test verifies the report contains expected parameters (SerialNumber)

# Prerequisites:
#   - Mosquitto broker running on 127.0.0.1:1883
#   - tr181-bulkdata service available on the device
#   - tr181-mqtt service available on the device

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R "ba-cli 'Device.MQTT.Client.*.-'" > /dev/null
  $ R "ba-cli 'Device.BulkData.Profile.*.-'" > /dev/null

  $ R "ba-cli 'Device.BulkData.set_trace_zone(zone=bulkdata, level=500)'" > /dev/null
  $ R "ba-cli 'Device.BulkData.set_trace_zone(zone=profile, level=500)'" > /dev/null
  $ R "ba-cli 'Device.BulkData.set_trace_zone(zone=parameter, level=500)'" > /dev/null
  $ R "ba-cli 'Device.BulkData.set_trace_zone(zone=mqtt, level=500)'" > /dev/null
  $ R "ba-cli 'Device.BulkData.set_trace_zone(zone=acl, level=500)'" > /dev/null

Get the time synchronization to start BulkData module:

  $ time_sync=$(R "cat /etc/amx/tr181-bulkdata/tr181-bulkdata.odl | grep -i "needs-time-sync" | sed -E 's/.*= ([^;]*);.*/\1/'")

Disable time synchronization and restart tr181-bulkdata to test BulkData module without time dependency if needed:

  $ if [ "$time_sync" = true ]; then
  >  R "sed -i 's/needs-time-sync = true/needs-time-sync = false/' /etc/amx/tr181-bulkdata/tr181-bulkdata.odl"
  >  R "/etc/init.d/tr181-bulkdata restart"
  > fi

Enable BulkData and check object status:

  $ R "ba-cli 'Device.BulkData.Enable=1' | grep -v '>' | grep 'Enable'"
  Device.BulkData.Enable=1

  $ R "ba-cli 'Device.BulkData.Status?' | grep '='"
  Device.BulkData.Status="Enabled"

1- Create MQTT client
  $ R "ba-cli 'Device.MQTT.Client.+{Alias="local_broker", BrokerAddress="127.0.0.1", Enable="true"}' | grep -v '>' | grep 'local_broker'"
  Device.MQTT.Client.[0-9]+.Alias="local_broker" (re)
  $ sleep 1 # Wait for MQTT client to connect and subscribe

2- Create MQTT profile
  $ R "ba-cli 'Device.BulkData.Profile.+{Alias="mqtt_profile", EncodingType="JSON", Protocol="MQTT", Enable="false", ReportingInterval = 5}' | grep -v '>' | grep 'mqtt_profile'"
  Device.BulkData.Profile.[0-9]+.Alias="mqtt_profile" (re)

3- Set the MQTT parameters
  $ R "ba-cli 'Device.BulkData.Profile.mqtt_profile.MQTT.PublishTopic="bulkdata/mqtt_profile"' | grep -v '>' | grep 'PublishTopic'"
  Device.BulkData.Profile.[0-9]+.MQTT.PublishTopic="bulkdata/mqtt_profile" (re)
  $ R "ba-cli 'Device.BulkData.Profile.mqtt_profile.MQTT.Reference="Device.MQTT.Client.local_broker."' | grep -v '>' | grep 'Reference'"
  Device.BulkData.Profile.[0-9]+.MQTT.Reference="Device.MQTT.Client.local_broker." (re)

4- Add new parameters to collect
  $ R "ba-cli 'Device.BulkData.Profile.mqtt_profile.Parameter.+{Name="SN", Reference="DeviceInfo.SerialNumber"}' | grep -v '>' | grep '.'"
  Device.BulkData.Profile.[0-9]+.Parameter.[0-9]+. (re)

5- start mosquitto_sub in the background to listen for published messages
  $ R '# Start a subscriber in background
  > mosquitto_sub -C 1 -t "bulkdata/mqtt_profile" >/tmp/mqtt_subscriber 2>/dev/null &
  > echo $! > /tmp/mosquitto_sub.pid
  > sleep 1'

6- Enable the mqtt profile.
  $ R "ba-cli 'Device.BulkData.Profile.mqtt_profile.Enable="true"' | grep -v '>' | grep '='"
  Device.BulkData.Profile.[0-9]+.Enable=1 (re)

7- Wait for 6 seconds
  $ sleep 6

8- check message are recieved by mosquitto_sub
  $ R 'cat /tmp/mqtt_subscriber' | \
  >   grep -cP '^\{"Report":\[\{"SN":"SN[A-F0-9]+","CollectionTime":"[0-9]{13}"\}\]\}$'
  [1-9][0-9]* (re)
  $ R 'rm /tmp/mqtt_subscriber'

9- Teardown:
9-1 Stop mosquitto_sub
  $ R 'if [ -f /tmp/mosquitto_sub.pid ]; then
  >   PID=$(cat /tmp/mosquitto_sub.pid)
  >   if kill -0 "$PID" 2>/dev/null; then
  >     kill "$PID"
  >   fi
  >   rm -f /tmp/mosquitto_sub.pid
  > fi'

9-2 delete the MQTT client
  $ R "ba-cli 'Device.MQTT.Client.*.-'" > /dev/null

9-3 Delete the MQTT profile
  $ R "ba-cli 'Device.BulkData.Profile.*.-'" > /dev/null

9-4 Restore default settings:
  $ if [ "$time_sync" = true ]; then
  >  R "sed -i 's/needs-time-sync = false/needs-time-sync = true/' /etc/amx/tr181-bulkdata/tr181-bulkdata.odl"
  > fi
  $ R "ba-cli 'Device.BulkData.set_trace_zone(zone=bulkdata, level=200)'" > /dev/null
  $ R "ba-cli 'Device.BulkData.set_trace_zone(zone=profile, level=200)'" > /dev/null
  $ R "ba-cli 'Device.BulkData.set_trace_zone(zone=parameter, level=200)'" > /dev/null
  $ R "ba-cli 'Device.BulkData.set_trace_zone(zone=mqtt, level=200)'" > /dev/null
  $ R "ba-cli 'Device.BulkData.set_trace_zone(zone=acl, level=200)'" > /dev/null
