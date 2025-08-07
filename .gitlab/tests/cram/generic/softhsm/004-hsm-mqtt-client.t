Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Setup https server at prplOS.lan/localhost 127.0.0.1:

  $ cat > /tmp/mqtt-client-setup.sh <<EOF
  > ba-cli BulkData.Enable=0
  > ba-cli BulkData.Profile.+{Alias=serial, Protocol=MQTT}
  > ba-cli BulkData.Profile.1.ReportingInterval=30
  > ba-cli BulkData.Profile.1.MQTT.Reference="Device.MQTT.Client.1"
  > ba-cli BulkData.Profile.1.Parameter.+{Reference="Device.DeviceInfo.SerialNumber", Name="MySerial"}
  > ba-cli BulkData.Profile.1.MQTT.PublishTopic="MySerialTopic"
  > ba-cli MQTT.Client.1.Enable=0
  > ba-cli MQTT.Client.1.BrokerAddress="127.0.0.1"
  > ba-cli MQTT.Client.1.BrokerPort=8883
  > ba-cli MQTT.Client.1.CheckServerHostName=false
  > ba-cli MQTT.Client.1.CACertificate="/root/certs/ca.crt"
  > ba-cli MQTT.Client.1.ClientCertificate="/root/certs/server.crt"
  > ba-cli MQTT.Client.1.PrivateKey="Security.Certificate.1.PrivateKeyURI"
  > ba-cli MQTT.Client.1.TransportProtocol="TLS"
  > ba-cli MQTT.Client.1.ProtocolVersion="5.0"
  > ba-cli MQTT.Client.1.EnableSSLEEngine=true
  > ba-cli MQTT.Client.1.SSLEngineId="pkcs11"
  > ba-cli MQTT.Client.1.Enable=1
  > ba-cli BulkData.Enable=1
  > ba-cli BulkData.Profile.1.Enable=1
  > EOF
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/mqtt-client-setup.sh)'" > /dev/null
  $ sleep 5

  $ R "ba-cli 'MQTT.Client.1.Stats.PublishSent?' > /dev/null"
  $ R "ba-cli 'MQTT.Client.1.Stats.PublishErrors?' > /dev/null"

  $ R "ba-cli 'BulkData.Enable=0' > /dev/null"
  $ R "ba-cli 'MQTT.Client.1.Enable=0' > /dev/null"
  $ sleep 1

