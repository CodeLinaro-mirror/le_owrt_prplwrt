Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check the root datamodel settings:

  $ R "ba-cli --json MQTTBroker.? | sed -n '2p'" | jq --sort-keys '.[0]'
  {
    "MQTTBroker.": {
      "BrokerNumberOfEntries": 2
    },
    "MQTTBroker.Broker.1.": {
      "Alias": "secure",
      "BridgeNumberOfEntries": 0,
      "Certificate": "",
      "Enable": 1,
      "Interface": "Device.IP.Interface.3.",
      "Name": "secure",
      "Password": "",
      "Port": 8883,
      "Status": "Enabled",
      "Username": "",
      "X_PRPLWARE-COM_UserNumberOfEntries": 0
    },
    "MQTTBroker.Broker.2.": {
      "Alias": "local",
      "BridgeNumberOfEntries": 0,
      "Certificate": "",
      "Enable": 1,
      "Interface": "Device.IP.Interface.1.",
      "Name": "local",
      "Password": "",
      "Port": 1883,
      "Status": "Enabled",
      "Username": "",
      "X_PRPLWARE-COM_UserNumberOfEntries": 0
    }
  }

Check that firewall is configured properly:

  $ R "iptables -nvL | grep dpt:1883 | grep -v '^Chain'"
      0     0 ACCEPT     6    --  lo     *       0.0.0.0/0            0.0.0.0/0            tcp dpt:1883
  $ R "iptables -nvL | grep dpt:8883 | grep -v '^Chain'"
      0     0 ACCEPT     6    --  br-lan *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8883

Check if local connections work:
Start a subscriber in background and wait up to 5 seconds for a message to be received:

  $ R '# Start a subscriber in background
  > mosquitto_sub -C 1 -t "/prpl/test/#" >/tmp/mqtt_subscriber 2>/dev/null &
  > subscriber_pid="$!"
  > sleep 1
  > # Publish a message
  > mosquitto_pub -t "/prpl/test/t" -m testMessage
  > # Wait up to 5 seconds for a message to be received
  > for _ in `seq 5`; do
  > sleep 1
  > if grep -q testMessage /tmp/mqtt_subscriber; then
  > break
  > fi
  > done
  > # Stop the background subscriber if it has not received anything yet
  > if ps -p "$subscriber_pid" | grep -v grep | grep -q mosquitto_sub; then
  > kill "$subscriber_pid"
  > fi
  > cat /tmp/mqtt_subscriber
  > rm /tmp/mqtt_subscriber'
  testMessage
