## Setup test configuration
Setup the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ R logger -t cram Starting $TESTFILE
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh && . /tmp/security_functions.sh"
  $ TEST_RESOURCES="${TESTDIR}/security_resources"
  $ python3 -u ${TEST_RESOURCES}/https_signature_server.py > signature-server-$LABGRID_TARGET.log 2>&1 &
  $ SIGNATURE_SERVER_PID=$!
  $ sleep 5
  $ C ${TESTDIR}/script_functions.sh root@${TARGET_LAN_IP}:/tmp/script_functions.sh 2>/dev/null
  $ C ${TEST_RESOURCES}/security_functions.sh root@${TARGET_LAN_IP}:/tmp/security_functions.sh 2>/dev/null
  $ R "mkdir -p /tmp/lcm_root_ca /etc/amx/tr181-security/extensions" > /dev/null
  $ C ${TEST_RESOURCES}/01_security_cram_lcm.odl root@${TARGET_LAN_IP}:/etc/amx/tr181-security/extensions/01_cram_lcm.odl 2>/dev/null
  $ C ${TEST_RESOURCES}/timingila.odl root@${TARGET_LAN_IP}:/tmp/softwaremodules_default.odl 2>/dev/null
  $ C ${TEST_RESOURCES}/sign_test_pub.asc root@${TARGET_LAN_IP}:/tmp/sign_test_pub.asc 2>/dev/null
  $ C ${TEST_RESOURCES}/lcm_servers_root_ca1.crt root@${TARGET_LAN_IP}:/usr/share/ca-certificates/lcm_servers_root_ca1.crt 2>/dev/null
  $ C ${TEST_RESOURCES}/ca_bundle.crt root@${TARGET_LAN_IP}:/usr/share/ca-certificates/ca_bundle.crt 2>/dev/null
  $ CSR_NAME="lcm_cert_client.csr"
  $ CA_ROOT_NAME="${TEST_RESOURCES}/lcm_test_root_ca_client"
  $ C ${TESTDIR}/event.lua root@${TARGET_LAN_IP}:/tmp/event.lua 2>/dev/null
  $ C ${TESTDIR}/usp-cli/usp-cli.conf root@${TARGET_LAN_IP}:/etc/amx/cli/usp-test-cli.conf 2>/dev/null
  $ C ${TESTDIR}/usp-cli/usp-cli.init root@${TARGET_LAN_IP}:/etc/amx/cli/usp-test-cli.init 2>/dev/null
  $ R "if [ ! -f /usr/bin/usp-test-cli ] ; then ln -s amx-cli /usr/bin/usp-test-cli; fi"

##### GENERAL SECURITY SETUP SECTION
Configure HSM with necessary slots, keys and generate a CSR:

  $ R "${S} && configure_hsm"
  Token created
  Private key created
  CSR generated

Copy the CSR from the device, sign it with the local CA to produce a client certificate, then provision the certificate back to the device:

  $ C root@${TARGET_LAN_IP}:/tmp/${CSR_NAME} /tmp/${CSR_NAME} 2>/dev/null
  $ openssl x509 -req -in "/tmp/${CSR_NAME}" -CA "${CA_ROOT_NAME}.crt" -CAkey "${CA_ROOT_NAME}.key" -set_serial 0x123456789 -CAcreateserial -out /tmp/lcm_cert_client.crt -days 365 -sha256 >/dev/null 2>&1 && echo "Certificate signed successfully"
  Certificate signed successfully
  $ C /tmp/lcm_cert_client.crt root@${TARGET_LAN_IP}:/etc/config/autocert/  2>/dev/null
  $ R "${S} && configure_security ${TARGET_LAN_TEST_HOST}" > /dev/null


###### TEST SECTION
Subscribe to the DUStateChange event to capture installation results:

  $ R "${S} && configure_datamodel set_subscription" > /dev/null


Test container installation using HTTP for the image signature server:

  $ R "${S} && configure_datamodel set_http"
  [{"Device.SoftwareModules.Config.":{"DUSignatureProtocols":"HTTP"}}]
  $ R "${S} && install_basic_container --signature http://signature.server1.local.com:8888/signature" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v1
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)
  $ R "${S} && uninstall_ctr_and_check --uuid --retaindata false"
  [1]


Test container installation using HTTPS for the image signature server:

  $ R "${S} && configure_datamodel set_https"
  [{"Device.SoftwareModules.Config.":{"DUSignatureProtocols":"HTTPS"}}]
  $ R "${S} && install_basic_container --signature https://signature.server1.local.com:5443/signature" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v1
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)
  $ R "${S} && uninstall_ctr_and_check --uuid --retaindata false"
  [1]


Test that a custom User-Agent header value is sent in HTTP requests to the signature server:

  $ R "${S} && configure_datamodel set_useragent"
  [{"Rlyeh.":{"UserAgent":"my custom User-Agent value"}}]
  $ R "${S} && install_basic_container --signature https://signature.server1.local.com:5443/signature" > /dev/null
  $ cat /tmp/lcm_http_useragent.txt
  my custom User-Agent value
  $ rm -f /tmp/lcm_http_useragent.txt
  $ R "${S} && uninstall_ctr_and_check --uuid --retaindata false"
  [1]


Test container installation with Basic authentication using a wrong password - expect authentication failure:

  $ R "${S} && listen_dustatechange"
  $ R "${S} && install_basic_container_no_wait --signature_user --signature_pwd wrongpass --signature https://signature.server1.local.com:6443/signature" > /dev/null 2>&1
  $ R "${S} && filtered_event"
  FaultCode = 7036
  FaultString = "Signature check for [*] failed [Authentication failed: * URL [*]]" (glob)
  CurrentState = "Failed"
  OperationPerformed = "Install"

Test container installation with Basic authentication using a correct password - expect success:

  $ R "${S} && install_basic_container --signature_user --signature_pwd --signature https://signature.server1.local.com:6443/signature" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v1
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)
  $ R "${S} && uninstall_ctr_and_check --uuid --retaindata false"
  [1]


Test container installation with Token/Bearer authentication using a wrong password - expect authentication failure:

  $ R "${S} && listen_dustatechange"
  $ R "${S} && install_basic_container_no_wait --signature_user --signature_pwd wrongpass --signature https://signature.server1.local.com:7443/signature" > /dev/null 2>&1
  $ R "${S} && filtered_event"
  FaultCode = 7036
  FaultString = "Signature check for [*] failed [Authentication failed: * URL [*]]" (glob)
  CurrentState = "Failed"
  OperationPerformed = "Install"


Test container installation with Token/Bearer authentication using a correct password - expect success:

  $ R "${S} && install_basic_container --signature_user --signature_pwd --signature https://signature.server1.local.com:7443/signature" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v1
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)
  $ R "${S} && uninstall_ctr_and_check --uuid --retaindata false"
  [1]


##### GENERAL CLEANUP SECTION
Clear all configuration and environment:

  $ R "${S} && cleanup_security"
  $ kill $SIGNATURE_SERVER_PID 2>/dev/null || true
  $ R logger -t cram Ended $TESTFILE
