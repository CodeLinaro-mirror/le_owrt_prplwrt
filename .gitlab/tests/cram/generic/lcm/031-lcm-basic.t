## Setup test configuration
Setup the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh"
  $ C ${TESTDIR}/script_functions.sh root@${TARGET_LAN_IP}:/tmp/script_functions.sh 2>/dev/null

### BASIC CONTAINER TEST 
### Trying privileged and unprivileged modes and switching between them

Install a the container in privileged mode and check its status and type:

  $ R "${S} && install_ctr --version prplos-v1 --ee --uuid --privileged true" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v1
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)
  $ R "${S} && get_ctr_type --uuid"
  Privileged container
  $ R "${S} && execute_in_container --uuid --cmd 'cat /etc/container-version'"
  1

Update to prplOS container to v2 in unprivileged mode:

  $ R "${S} && update_ctr --version prplos-v2 --ee --uuid --privileged false" > /dev/null
  $ sleep 20
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v2
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)
  $ R "${S} && get_ctr_type --uuid"
  Unprivileged container
  $ R "${S} && execute_in_container --uuid --cmd 'cat /etc/container-version'"
  2

Uninstall the testing container and check datamodel cleaned:

  $ R "${S} && uninstall_ctr_and_check --uuid --retaindata false"
  [1]


Install the container in unprivileged mode and check its status and type:

  $ R "${S} && install_ctr --version prplos-v1 --ee --uuid --privileged false" > /dev/null
  $ sleep 20
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v1
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)
  $ R "${S} && get_ctr_type --uuid"
  Unprivileged container
  $ R "${S} && execute_in_container --uuid --cmd 'cat /etc/container-version'"
  1


Update to prplOS container to v2 in privileged mode:

  $ R "${S} && update_ctr --version prplos-v2 --ee --uuid --privileged true" > /dev/null
  $ sleep 20
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v2
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)
  $ R "${S} && get_ctr_type --uuid"
  Privileged container
  $ R "${S} && execute_in_container --uuid --cmd 'cat /etc/container-version'"
  2


Uninstall the container and check everything is cleaned:

  $ R "${S} && uninstall_ctr_and_check --uuid"
  [1]


Cleanup test environment:

  $ R "rm -f /tmp/script_functions.sh"
