# MQTT TR-181 Test Suite
# ======================
# 
# This test suite validates the TR-181 MQTT client implementation, covering:
# - MQTT.Client object creation and configuration
# - Publish RPC functionality
# - OnMessage! event reception verification
# 
# Prerequisites:
#   - Mosquitto broker running on 127.0.0.1:1883
#   - ba-cli available on the device
#   - ubus available on the device
#   - mosquitto-clients installed on the test host
# 
# Test cases:
#   1. Add MQTT client and subscription
#   2. Publish message and verify OnMessage! event
#   3. Delete MQTT client and subscription

Create R alias:
  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R "ba-cli 'MQTT.Client.*.-'" > /dev/null
  $ R "ba-cli 'MQTT.set_trace_zone(zone=mqtt_client, level=500)'" > /dev/null

  $ R '# Start a subscriber in background
  > mosquitto_sub -C 1 -t "SAH_CRAM_tests" >/tmp/mqtt_subscriber 2>/dev/null &
  > echo $! > /tmp/mosquitto_sub.pid
  > sleep 1'

1- sleep for a moment to ensure subscriber is ready before publishing messages
  $ sleep 1

2- Add MQTT client and subscription
  $ R "ba-cli 'MQTT.Client.+{Alias="local_broker", BrokerAddress="127.0.0.1", Enable="true"}' | grep -v '>' | grep 'local_broker'"
  MQTT.Client.[0-9]+.Alias="local_broker" (re)
  $ R "ba-cli 'MQTT.Client.local_broker.Subscription.+{Topic="SAH_CRAM_tests", Enable="true"}' | grep -v '>' | grep 'Topic'"
  MQTT.Client.[0-9]+.Subscription.1.Topic="SAH_CRAM_tests" (re)
  $ sleep 2 # Wait for MQTT client to connect and subscribe

3- Start a ubus subscriber in background to listen for MQTT messages received by the MQTT client and check for the published message:
  $ R 'ubus -t 5 subscribe "MQTT" ' | \
  >   jq -c 'select(has("OnMessage!")) | {"Topic": .["OnMessage!"].Topic, "Payload": .["OnMessage!"].Payload}' | \
  >   head -1 \
  >   > /tmp/ubus_output 2>&1 &
  $ echo $! > /tmp/ubus_sub.pid
  $ sleep 1

4- Publish message using MQTT Publish RPC and check syslog for publish callback message:
  $ R "ba-cli 'MQTT.Client.local_broker.Publish(Topic="SAH_CRAM_tests", Payload="testMessage", QoS=0, Retain=false)'" > /dev/null

5- Wait for the subscription to take effect and the message to be received by the subscriber, then check the output:
  $ wait $(cat /tmp/ubus_sub.pid)
  $ cat /tmp/ubus_output
  {"Topic":"SAH_CRAM_tests","Payload":"testMessage"}

  $ rm -f /tmp/ubus_output /tmp/ubus_sub.pid  > /dev/null  2>&1

  $ R '# Check message received by subscriber:
  > killall mosquitto_sub > /dev/null 2>&1
  > cat /tmp/mqtt_subscriber
  > rm /tmp/mqtt_subscriber'
  testMessage

5- Teardown:
5-1 Delete MQTT client and subscription
  $ R "ba-cli 'MQTT.Client.*.-'" > /dev/null
5-2 kill mosquitto_sub using PID file
  $ R 'if [ -f /tmp/mosquitto_sub.pid ]; then
  >   PID=$(cat /tmp/mosquitto_sub.pid)
  >   if kill -0 "$PID" 2>/dev/null; then
  >     kill "$PID"
  >   fi
  >   rm -f /tmp/mosquitto_sub.pid
  > fi'
