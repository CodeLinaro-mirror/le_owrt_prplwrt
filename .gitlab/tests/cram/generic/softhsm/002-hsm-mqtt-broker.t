Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"

Setup mqttbroker for pkcs11:

  $ cat > /tmp/mqtt-broker-setup.sh <<EOF
  > ba-cli MQTTBroker.Broker.secure.Enable=0
  > ba-cli MQTTBroker.Broker.secure.Interface="Device.IP.Interface.1."
  > ba-cli MQTTBroker.Broker.secure.TlsEngine=true
  > ba-cli MQTTBroker.Broker.secure.TlsEngineId="pkcs11"
  > ba-cli MQTTBroker.Broker.secure.CertFile=""
  > ba-cli MQTTBroker.Broker.secure.CAFile="/usr/share/ca-certificates/ca.crt"
  > ba-cli MQTTBroker.Broker.secure.Ciphers="DEFAULT"
  > ba-cli MQTTBroker.Broker.secure.RequireCertificate=true
  > ba-cli MQTTBroker.Broker.secure.KeyFile=""
  > ba-cli MQTTBroker.Broker.secure.Certificate="Device.Security.Certificate.2."
  > ba-cli MQTTBroker.Broker.secure.Enable=1
  > EOF
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/mqtt-broker-setup.sh)'" > /dev/null
  $ sleep 1

Check mqtt publish at port 8883:

  $ S="mqtt-publish-sec.sh"
  $ C "${TESTDIR}/${S}" "root@${TARGET_LAN_IP}:/tmp/"
  Warning: Permanently added '*' (*) to the list of known hosts* (glob)
  $ R "source /tmp/${S} | grep -q 'sending PUBLISH'"