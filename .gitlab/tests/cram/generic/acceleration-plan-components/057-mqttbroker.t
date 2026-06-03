Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check the root datamodel settings:

  $ R "ba-cli --json MQTTBroker.? | sed -n '2p'" | jq -S '.[0] | del(.. | .Process?)'
  {
    "MQTTBroker.": {
      "BrokerNumberOfEntries": 2
    },
    "MQTTBroker.Broker.1.": {
      "ACLList": "",
      "Alias": "secure",
      "AllowAnonymous": 0,
      "AuthenticationMethod": "UsernamePassword",
      "BridgeNumberOfEntries": 0,
      "BrokerID": 1,
      "CABundle": "",
      "CipherList": "",
      "ConfFile": "",
      "Enable": 1,
      "IPVersion": 4,
      "Interface": "Device.IP.Interface.3.",
      "Name": "secure",
      "Password": "",
      "Port": 8883,
      "Status": "Enabled",
      "TransportProtocol": "TLS",
      "Username": ""
    },
    "MQTTBroker.Broker.2.": {
      "ACLList": "",
      "Alias": "local",
      "AllowAnonymous": 0,
      "AuthenticationMethod": "UsernamePassword",
      "BridgeNumberOfEntries": 0,
      "BrokerID": 1,
      "CABundle": "",
      "CipherList": "",
      "ConfFile": "Device.DeviceInfo.VendorConfigFile.2.",
      "Enable": 1,
      "IPVersion": 4,
      "Interface": "Device.IP.Interface.1.",
      "Name": "local",
      "Password": "",
      "Port": 1883,
      "Status": "Enabled",
      "TransportProtocol": "TLS",
      "Username": ""
    },
    "MQTTBroker.BrokerSecurity.": {
      "ACLNumberOfEntries": 0,
      "ClientNumberOfEntries": 0
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
