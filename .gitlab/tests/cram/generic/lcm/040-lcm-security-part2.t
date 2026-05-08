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


Test container installation fails when the registry is configured with a wrong CA bundle:

  $ R "${S} && configure_datamodel docker_repo_root_ca1"
  [{"Device.SoftwareModules.Config.Repository.*.":{"CABundle":"Device.Security.CABundle.*"}}] (glob)
  $ R "${S} && listen_dustatechange"
  $ R "${S} && install_basic_container_no_wait" > /dev/null 2>&1
  $ R "${S} && filtered_event"
  FaultCode = 7002
  FaultString = "Pull image [*] failed [*]" (glob)
  CurrentState = "Failed"
  OperationPerformed = "Install"

Test container installation succeeds when the registry is configured with the correct CA bundle:

  $ R "${S} && configure_datamodel docker_repo_ca_bundle"
  [{"Device.SoftwareModules.Config.Repository.*.":{"CABundle":"Device.Security.CABundle.*"}}] (glob)
  $ R "${S} && install_basic_container" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v1
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)
  $ R "${S} && uninstall_ctr_and_check --uuid --retaindata false"
  [1]


Test container installation fails when the signature server is configured with a wrong CA bundle:

  $ R "${S} && listen_dustatechange"
  $ R "${S} && install_basic_container_no_wait --signature https://signature.server2.local.com:9443/signature" > /dev/null 2>&1
  $ R "${S} && filtered_event"
  FaultCode = 7036
  FaultString = "Signature check for [*] failed [Authentication failed: * URL [https://signature.server2.local.com:*/signature*]]" (glob)
  CurrentState = "Failed"
  OperationPerformed = "Install"

Test container installation succeeds when the signature server is configured with the correct CA bundle:

  $ R "${S} && install_basic_container --signature https://signature.server1.local.com:5443/signature" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v1
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)
  $ R "${S} && uninstall_ctr_and_check --uuid --retaindata false"
  [1]


Test container installation fails when connecting to an mTLS signature server without providing a client certificate:

  $ R "${S} && configure_datamodel no_client_cert"
  [{"Device.SoftwareModules.Config.Repository.*.":{"Certificate":""}}] (glob)
  $ R "${S} && listen_dustatechange"
  $ R "${S} && install_basic_container_no_wait --signature https://signature.server1.local.com:8443/signature" > /dev/null 2>&1
  $ R "${S} && filtered_event"
  FaultCode = 7036
  FaultString = "Signature check for [*] failed [Authentication failed: * URL [https://signature.server1.local.com:*/signature*]]" (glob)
  CurrentState = "Failed"
  OperationPerformed = "Install"



Test container installation succeeds when connecting to an mTLS signature server with a valid client certificate:

  $ R "${S} && configure_datamodel set_client_cert"
  [{"Device.SoftwareModules.Config.Repository.*.":{"Certificate":"Device.Security.Certificate.*"}}] (glob)
  $ R "${S} && install_basic_container --signature_user --signature_pwd --signature https://signature.server1.local.com:8443/signature" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v1
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)
  $ R "${S} && uninstall_ctr_and_check --uuid --retaindata false"
  [1]


Test container installation suceeds when using valid default CA bundle configuration:

  $ R "${S} && configure_datamodel disable_docker_repo"
  [{"Device.SoftwareModules.Config.Repository.*.":{"Enable":false}}] (glob)
  $ R "${S} && install_basic_container" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v1
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)
  $ R "${S} && uninstall_ctr_and_check --uuid --retaindata false"
  [1]



Test container installation fails when using wrong default CA bundle configuration:

  $ R "${S} && configure_datamodel set_default_ca_wrong"
  [{"Device.SoftwareModules.Config.":{"CABundle":"Device.Security.CABundle.*"}}] (glob)
  $ R "${S} && listen_dustatechange"
  $ R "${S} && install_basic_container_no_wait" > /dev/null 2>&1
  $ R "${S} && filtered_event"
  FaultCode = 7002
  FaultString = "Pull image [*] failed [*]" (glob)
  CurrentState = "Failed"
  OperationPerformed = "Install"


##### GENERAL CLEANUP SECTION
Clear all configuration and environment:

  $ R "${S} && cleanup_security"
  $ kill $SIGNATURE_SERVER_PID 2>/dev/null || true
  $ R logger -t cram Ended $TESTFILE
