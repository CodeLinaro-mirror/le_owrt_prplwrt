Create R alias:

  $ R() { ${CRAM_REMOTE_COMMAND:-} "$@" < /dev/null; }

Prerequisites check:

  $ R "which ba-cli" | head -1
  /usr/bin/ba-cli

  $ R "which openssl" | head -1
  /usr/bin/openssl

  $ R "which mosquitto" | head -1
  /usr/sbin/mosquitto

  $ R "which softhsm2-util" | head -1
  /usr/bin/softhsm2-util

  $ R "which pkcs11-tool" | head -1
  /usr/bin/pkcs11-tool

  $ R "ls /usr/lib/amx/tr181-security/" > /dev/null

  $ R "ls /usr/lib/amx/modules/mod-keystore-pkcs11.so" > /dev/null

  $ R "ls /usr/lib/amx/modules/mod-keystore-file.so" > /dev/null

  $ R "ls /usr/lib/softhsm/libsofthsm2.so" > /dev/null

  $ R "ba-cli 'Security.Storage.*.-'" > /dev/null
  $ R "ba-cli 'Security.Certificate.*.-'" > /dev/null
  $ R "ba-cli 'Security.CSR.*.-'" > /dev/null

  $ R "ba-cli 'Security.set_trace_zone(zone = API_MODULES, level = 500)'" > /dev/null
  $ R "ba-cli 'Security.set_trace_zone(zone = CSR, level = 500)'" > /dev/null
  $ R "ba-cli 'Security.set_trace_zone(zone = events, level = 500)'" > /dev/null
  $ R "ba-cli 'Security.set_trace_zone(zone = mod-keystore-pkcs11, level = 500)'" > /dev/null
  $ R "ba-cli 'Security.set_trace_zone(zone = mod-keystore-file, level = 500)'" > /dev/null
  $ R "ba-cli 'Security.set_trace_zone(zone = security, level = 500)'" > /dev/null
  $ R "ba-cli 'Security.set_trace_zone(zone = security_metadata, level = 500)'" > /dev/null
  $ R "ba-cli 'Security.set_trace_zone(zone = security_storage, level = 500)'" > /dev/null

Initialize PKCS11 token for testing:

  $ R "softhsm2-util --init-token --free --label 'Token_cram_test' --so-pin 5678 --pin 1234" > /dev/null 2>&1

Verify token was created:

  $ R "softhsm2-util --show-slots | grep 'Token_cram_test'"
  *Token_cram_test* (glob)

Create PIN file for PKCS11 authentication:

  $ R "mkdir -p /tmp/cram_test_feat188"
  $ R "printf '%s' '1234' > /tmp/cram_test_feat188/pin.txt"
  $ R "chmod 600 /tmp/cram_test_feat188/pin.txt"
  $ R "chown mosquitto /tmp/cram_test_feat188/pin.txt 2>/dev/null || true"

Create tr181-security Storage for PKCS11:

  $ R "ba-cli 'Security.Storage.+{CertificateStorage=\"/tmp/cram_test_feat188/certs/\", Controller=\"mod-keystore-pkcs11\", KeyStorage=\"/tmp/cram_test_feat188/keys/\", NameExpressions=\".*cram_test.*\", PKCS11Slot=\"\", PKCS11Token=\"Token_cram_test\", PKCS11UserPINSource=\"/tmp/cram_test_feat188/pin.txt\", PKCS11Module=\"/usr/lib/softhsm/libsofthsm2.so\", Transient=\"true\"}'" > /dev/null

Verify Storage configuration:

  $ R "ba-cli 'Security.Storage.[Controller==\"mod-keystore-pkcs11\"].PKCS11Token?'" | grep -o 'Token_cram_test'
  Token_cram_test

Create broker CSR with key stored in PKCS11:

  $ R "ba-cli 'Security.CreateCSR(Name = \"cram_test_broker_csr\", KeyType = \"RSA\", KeyLength = 2048, BasicConstraints = true, PathLengthConstraint = 256, KeyUsageList = \"DigitalSignature, NonRepudiation, KeyEncipherment\", ExtendedKeyUsageList = \"ServerAuth, ClientAuth\", CommonName = \"broker_cram\", OrganizationName = \"CRAM\", OrganizationalUnit = \"test\", Locality = \"Test\", State = \"State\", Country = \"TN\", Email = \"test@example.com\", RenewalMode = \"ReKey\", RenewalInterval = 15)'" > /dev/null 2>&1; sleep 1

Verify broker CSR was created:

  $ R "ba-cli 'Security.CSR.[Name==\"cram_test_broker_csr\"].Name?'" | grep -o 'cram_test_broker_csr' | head -1
  cram_test_broker_csr

Verify key pair exists in PKCS11 token:

  $ R "pkcs11-tool --module /usr/lib/softhsm/libsofthsm2.so --token-label 'Token_cram_test' --login --pin 1234 --list-objects | grep -c 'cram_test_broker_csr'"
  2

Extract broker CSR:

  $ R "ba-cli 'protected; Security.CSR.[Name==\"cram_test_broker_csr\"].EncodedCSR?' | grep 'BEGIN CERTIFICATE REQUEST'" > /dev/null

  $ R "ba-cli 'protected; Security.CSR.[Name==\"cram_test_broker_csr\"].EncodedCSR?' | sed -n '/-----BEGIN CERTIFICATE REQUEST-----/,/-----END CERTIFICATE REQUEST-----/p' | sed 's/^.*EncodedCSR=\"//; s/\"$//' > /tmp/cram_test_feat188/broker.csr"

  $ R "sed 's/\\\\n/\n/g' /tmp/cram_test_feat188/broker.csr > /tmp/cram_test_feat188/broker_fixed.csr"  > /dev/null

  $ R "mv /tmp/cram_test_feat188/broker_fixed.csr /tmp/cram_test_feat188/broker.csr"  > /dev/null

Debug: Check CSR file exists:

  $ R "test -f /tmp/cram_test_feat188/broker.csr && echo 'CSR file exists' || echo 'CSR file missing'"
  CSR file exists

Self-sign broker certificate using PKCS11 key:

  $ R 'cd /tmp/cram_test_feat188 && PKCS11_MODULE_PATH=/usr/lib/softhsm/libsofthsm2.so openssl x509 -req -in broker.csr -engine pkcs11 -keyform engine -signkey "pkcs11:token=Token_cram_test;object=cram_test_broker_csr;type=private;pin-value=1234" -out broker.pem -days 365 2>&1 | grep -v -E "(deprecated|Using configuration)" | head -5' || true
  * (glob)
  * (glob)
  * (glob)

Verify broker certificate was created:

  $ R "test -f /tmp/cram_test_feat188/broker.pem && echo 'Certificate created' || echo 'Certificate creation failed'"
  Certificate created

  $ R "test -f /tmp/cram_test_feat188/broker.pem && openssl x509 -in /tmp/cram_test_feat188/broker.pem -noout -subject 2>&1 | grep -o 'CN.*broker_cram' || echo 'Could not verify certificate'"
  *broker_cram* (glob)

Add broker certificate to tr181-security:

  $ R "CERT=\$(cat /tmp/cram_test_feat188/broker.pem); ba-cli \"Security.AddCertificate(Certificate='\${CERT}', MatchToCSR=true, Alias='broker-cert', RenewalMode='ReKey', RenewalInterval=20)\"" > /dev/null 2>&1

Verify broker certificate exists and CSR was removed:

  $ R "sleep 1"

  $ R "ba-cli 'Security.Certificate.[Name==\"cram_test_broker_csr\"].Name?' | grep -o 'cram_test_broker_csr' | head -1"
  cram_test_broker_csr

  $ R "ba-cli 'Security.CSR.[Name==\"cram_test_broker_csr\"].?' 2>&1 | grep 'No data found' > /dev/null && echo 'CSR removed' || echo 'CSR still exists'"
  CSR removed

Verify broker certificate has PKCS11 private key URI:

  $ R "ba-cli 'protected; Security.Certificate.[Name==\"cram_test_broker_csr\"].PrivateKeyURI?' | grep 'pkcs11:token=Token_cram_test'" > /dev/null

Create client CSR:

  $ R "ba-cli 'Security.CreateCSR(Name = \"cram_test_client_csr\", KeyType = \"RSA\", KeyLength = 2048, BasicConstraints = true, PathLengthConstraint = 256, KeyUsageList = \"DigitalSignature, NonRepudiation, KeyEncipherment\", ExtendedKeyUsageList = \"ClientAuth\", CommonName = \"client_cram\", OrganizationName = \"CRAM\", OrganizationalUnit = \"test\", Locality = \"Test\", State = \"State\", Country = \"TN\", Email = \"client@example.com\", RenewalMode = \"ReKey\", RenewalInterval = 15)'" > /dev/null 2>&1; sleep 1

Verify client CSR was created:

  $ R "ba-cli 'Security.CSR.[Name==\"cram_test_client_csr\"].Name?'" | grep -o 'cram_test_client_csr' | head -1
  cram_test_client_csr

Extract client CSR and sign with broker CA:

  $ R "ba-cli 'protected; Security.CSR.[Name==\"cram_test_client_csr\"].EncodedCSR?' | sed -n '/-----BEGIN CERTIFICATE REQUEST-----/,/-----END CERTIFICATE REQUEST-----/p' | sed 's/^.*EncodedCSR=\"//; s/\"$//' > /tmp/cram_test_feat188/client.csr"

  $ R "sed 's/\\\\n/\n/g' /tmp/cram_test_feat188/client.csr > /tmp/cram_test_feat188/client_fixed.csr"  > /dev/null

  $ R "mv /tmp/cram_test_feat188/client_fixed.csr /tmp/cram_test_feat188/client.csr"  > /dev/null

Debug: Check client CSR and broker cert:

  $ R "test -f /tmp/cram_test_feat188/client.csr && echo 'Client CSR exists' || echo 'Client CSR missing'"
  Client CSR exists

  $ R "cd /tmp/cram_test_feat188 && BROKER_CERT=\$(ba-cli 'protected; Security.Certificate.[Name==\"cram_test_broker_csr\"].CertificateURI?' | grep 'CertificateURI=' | sed 's/.*CertificateURI=\"//; s/\".*//; s|file://||'); test -f \${BROKER_CERT} && echo 'Broker cert found' || echo 'Broker cert not found'"
  Broker cert found

Sign client certificate with broker CA using PKCS11:

  $ R 'cd /tmp/cram_test_feat188 && BROKER_CERT=$(ba-cli "protected; Security.Certificate.[Name==\"cram_test_broker_csr\"].CertificateURI?" | grep "CertificateURI=" | sed "s/.*CertificateURI=\"//; s/\".*//; s|file://||") && PKCS11_MODULE_PATH=/usr/lib/softhsm/libsofthsm2.so openssl x509 -req -in client.csr -CA ${BROKER_CERT} -engine pkcs11 -CAkeyform engine -CAkey "pkcs11:token=Token_cram_test;object=cram_test_broker_csr;type=private?pin-source=file:/tmp/cram_test_feat188/pin.txt" -set_serial 1002 -out client.pem -days 365 -sha256 2>&1 | grep -v -E "(deprecated|Using configuration)" | head -5' || true
  * (glob)
  * (glob)
  * (glob)

Add client certificate:

  $ R "CERT=\$(cat /tmp/cram_test_feat188/client.pem)
  > ba-cli \"Security.AddCertificate(Certificate='\${CERT}', \
  > MatchToCSR=true, Alias='client-cert', \
  > RenewalMode='ReKey', RenewalInterval=20)\"" > /dev/null 2>&1; sleep 1

Verify certificate chain:

  $ R 'cd /tmp/cram_test_feat188 &&
  > BROKER_CERT=$(ba-cli "protected; Security.Certificate.[Name==\"cram_test_broker_csr\"].CertificateURI?" \
  >   | grep CertificateURI= | cut -d\" -f2 | sed s#file://##) &&
  > CLIENT_CERT=$(ba-cli "protected; Security.Certificate.[Name==\"cram_test_client_csr\"].CertificateURI?" \
  >   | grep CertificateURI= | cut -d\" -f2 | sed s#file://##) &&
  > openssl verify -CAfile ${BROKER_CERT} ${CLIENT_CERT} 2>&1 | grep -o OK'
  OK

Configure MQTT Broker with PKCS11:

  $ R "ba-cli 'MQTTBroker.set_trace_zone(zone = imtp, level = 500)'" > /dev/null
  $ R "ba-cli 'MQTTBroker.set_trace_zone(zone = mqttbroker, level = 500)'" > /dev/null

  $ R "ba-cli 'MQTTBroker.Broker.secure.Enable=0'" > /dev/null

  $ R "ba-cli 'MQTTBroker.Broker.secure.Interface=\"Device.IP.Interface.1.\"'" > /dev/null
  $ R "ba-cli 'MQTTBroker.Broker.secure.TlsEngine=true'" > /dev/null
  $ R "ba-cli 'MQTTBroker.Broker.secure.TlsEngineId=\"pkcs11\"'" > /dev/null

Get broker certificate path for MQTTBroker configuration:

  $ CERT_PATH=$(R "ba-cli 'protected; Security.Certificate.[Name==\"cram_test_broker_csr\"].CertificateURI?'" \
  >   | grep CertificateURI= \
  >   | cut -d'"' -f2 \
  >   | sed 's|file://||')
  $ R "ba-cli 'MQTTBroker.Broker.secure.CAFile=\"$CERT_PATH\"'" > /dev/null

  $ R "ba-cli 'MQTTBroker.Broker.secure.Ciphers=\"DEFAULT\"'" > /dev/null
  $ R "ba-cli 'MQTTBroker.Broker.secure.RequireCertificate=true'" > /dev/null

Get broker certificate object for MQTT configuration:

  $ CERT_OBJ=$(R "ba-cli 'Security.Certificate.[Name==\"cram_test_broker_csr\"].?'" \
  >   | grep -o 'Security\.Certificate\.[0-9]*\.' | head -1)
  $ R "ba-cli 'MQTTBroker.Broker.secure.Certificate=\"$CERT_OBJ\"'" > /dev/null

Enable MQTT Broker:

  $ R "ba-cli 'MQTTBroker.Broker.secure.Enable=1'" > /dev/null; sleep 2

Test MQTT communication with PKCS11 certificates:

  $ R '# Get certificate paths
  > BROKER_CERT=$(ba-cli "protected; Security.Certificate.[Name==\"cram_test_broker_csr\"].CertificateURI?" | grep CertificateURI= | cut -d\" -f2 | sed s#file://##)
  > CLIENT_CERT=$(ba-cli "protected; Security.Certificate.[Name==\"cram_test_client_csr\"].CertificateURI?" | grep CertificateURI= | cut -d\" -f2 | sed s#file://##)
  > # Start subscriber in background
  > export PKCS11_MODULE_PATH=/usr/lib/softhsm/libsofthsm2.so
  > mosquitto_sub -C 1 -h 127.0.0.1 -p 8883 -t cram_test_topic --insecure \
  >   --cafile ${BROKER_CERT} \
  >   --cert ${CLIENT_CERT} \
  >   --tls-engine pkcs11 --keyform engine \
  >   --key "pkcs11:token=Token_cram_test;object=cram_test_client_csr;type=private?pin-source=file:/tmp/cram_test_feat188/pin.txt" \
  >   >/tmp/mqtt_pkcs11_subscriber 2>/dev/null &
  > subscriber_pid="$!"
  > sleep 2
  > # Publish test message
  > mosquitto_pub -h 127.0.0.1 -p 8883 -t cram_test_topic --insecure \
  >   --cafile ${BROKER_CERT} \
  >   --cert ${CLIENT_CERT} \
  >   --tls-engine pkcs11 --keyform engine \
  >   --key "pkcs11:token=Token_cram_test;object=cram_test_client_csr;type=private?pin-source=file:/tmp/cram_test_feat188/pin.txt" \
  >   -m "PKCS11 CRAM test message"
  > # Wait up to 5 seconds for message to be received
  > for _ in $(seq 5); do
  > sleep 1
  > if grep -q "PKCS11 CRAM test message" /tmp/mqtt_pkcs11_subscriber; then
  > break
  > fi
  > done
  > # Stop background subscriber if still running
  > if ps -p "$subscriber_pid" 2>/dev/null | grep -v grep | grep -q mosquitto_sub; then
  > kill "$subscriber_pid" 2>/dev/null
  > fi
  > # Display received message
  > cat /tmp/mqtt_pkcs11_subscriber
  > rm /tmp/mqtt_pkcs11_subscriber'
  PKCS11 CRAM test message

Stop MQTT Broker:

  $ R "ba-cli 'MQTTBroker.Broker.secure.Enable=0'" > /dev/null; sleep 1

Test orphan key cleanup - create duplicate key:

  $ R "pkcs11-tool --module /usr/lib/softhsm/libsofthsm2.so --token-label 'Token_cram_test' --login --pin 1234 --keypairgen --key-type RSA:2048 --label 'cram_test_broker_csr'" > /dev/null 2>&1

Verify duplicate key exists (should have 4 objects with label cram_test_broker_csr):

  $ R "pkcs11-tool --module /usr/lib/softhsm/libsofthsm2.so --token-label 'Token_cram_test' --login --pin 1234 --list-objects | grep -c 'cram_test_broker_csr'"
  4

Restart tr181-security to trigger orphan cleanup:

  $ R "/etc/init.d/tr181-security stop" > /dev/null 2>&1
  $ R "for i in \$(seq 10); do pidof tr181-security >/dev/null 2>&1 || break; sleep 1; done; pidof tr181-security >/dev/null 2>&1 && echo 'Still running' || echo 'Stopped'"
  Stopped
  $ R "/etc/init.d/tr181-security start" > /dev/null 2>&1
  $ R "for i in \$(seq 15); do ba-cli 'Security.?' >/dev/null 2>&1 && break; sleep 1; done; ba-cli 'Security.?' >/dev/null 2>&1 && echo 'Ready' || echo 'Not ready'"
  Ready
  $ sleep 2

Verify orphan key was removed (should have 2 objects back, or at least fewer than 4):

  $ R "pkcs11-tool --module /usr/lib/softhsm/libsofthsm2.so --token-label 'Token_cram_test' \
  >   --login --pin 1234 --list-objects 2>/dev/null | grep -c 'label:.*cram_test_broker_csr'"
  2

Cleanup - delete certificates:

  $ R "ba-cli 'protected; Security.Certificate.[Name==\"cram_test_client_csr\"].Delete()'" > /dev/null 2>&1

  $ R "ba-cli 'protected; Security.Certificate.[Name==\"cram_test_broker_csr\"].Delete()'" > /dev/null 2>&1

Verify certificates deleted:

  $ R "ba-cli 'protected; Security.Certificate.[Name==\"cram_test_broker_csr\"].?' 2>&1 | grep 'No data found' > /dev/null && echo 'Cert removed' || echo 'Cert still exists'"
  Cert removed

Delete storage configuration:

  $ R "ba-cli 'Security.Storage.[Controller==\"mod-keystore-pkcs11\"].-'" > /dev/null 2>&1

Verify storage deleted:

  $ R "ba-cli 'Security.Storage.[Controller==\"mod-keystore-pkcs11\"].?' 2>&1 | grep 'No data found' > /dev/null && echo 'Storage deleted' || echo 'Storage still exists'"
  Storage deleted

Delete PKCS11 token:

  $ R "softhsm2-util --delete-token --token 'Token_cram_test'" < /dev/null > /dev/null 2>&1

Remove test directories and files:

  $ R "rm -rf /tmp/cram_test_feat188" < /dev/null > /dev/null 2>&1

Verify token deleted:

  $ R "softhsm2-util --show-slots 2>&1 | grep 'Token_cram_test' > /dev/null && echo 'Token still exists' || echo 'Token deleted'"
  Token deleted

Revert trace level:

  $ R "ba-cli 'Security.set_trace_zone(zone = API_MODULES, level = 200)'" > /dev/null
  $ R "ba-cli 'Security.set_trace_zone(zone = CSR, level = 200)'" > /dev/null
  $ R "ba-cli 'Security.set_trace_zone(zone = events, level = 200)'" > /dev/null
  $ R "ba-cli 'Security.set_trace_zone(zone = mod-keystore-pkcs11, level = 200)'" > /dev/null
  $ R "ba-cli 'Security.set_trace_zone(zone = mod-keystore-file, level = 200)'" > /dev/null
  $ R "ba-cli 'Security.set_trace_zone(zone = security, level = 200)'" > /dev/null
  $ R "ba-cli 'Security.set_trace_zone(zone = security_metadata, level = 200)'" > /dev/null
  $ R "ba-cli 'Security.set_trace_zone(zone = security_storage, level = 200)'" > /dev/null
  $ R "ba-cli 'MQTTBroker.set_trace_zone(zone = imtp, level = 200)'" > /dev/null
  $ R "ba-cli 'MQTTBroker.set_trace_zone(zone = mqttbroker, level = 200)'" > /dev/null