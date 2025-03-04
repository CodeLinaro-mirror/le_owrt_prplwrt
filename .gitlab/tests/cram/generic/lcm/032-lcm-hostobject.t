## Setup test configuration
Set-up the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh"
  $ C ${TESTDIR}/script_functions.sh root@${TARGET_LAN_IP}:/tmp/script_functions.sh 2>/dev/null
  $ R "${S} && setup_hostobjects"


### PRIVILEGED CONTAINER SECTION ###
Install container with HostObject and check its running and objects shared:

  $ R "${S} && install_ctr --version prplos-v1 --ee --uuid --privileged true --network --hostobject" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v1
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)

Verify share objects are available on container side:

  $ R "${S} && get_hostobjects"
  /testdir/:
  testfile
  test sharing file
  /dev/host_serial

Uninstall the testing container and check datamodel cleaned:

  $ R "${S} && uninstall_ctr_and_check --uuid --retaindata false"
  [1]

### UNPRIVILEGED CONTAINER SECTION ###
Install container with HostObject and check its running and objects shared:

  $ R "${S} && install_ctr --version prplos-v1 --ee --uuid --privileged false --network --hostobject" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v1
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)

Verify share objects are available on container side:

  $ R "${S} && get_hostobjects"
  /testdir/:
  testfile
  test sharing file
  /dev/host_serial

Uninstall the testing container and check datamodel cleaned:

  $ R "${S} && uninstall_ctr_and_check --uuid --retaindata false"
  [1]


Cleanup test environment:

  $ R "${S} && cleanup_hostobjects"
  $ R "rm -f /tmp/script_functions.sh"
