## Setup test configuration
Set-up the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh"
  $ C ${TESTDIR}/script_functions.sh root@${TARGET_LAN_IP}:/tmp/script_functions.sh 2>/dev/null

### PRIVILEGED CONTAINER SECTION ###
Install container with EnvVariables and check its running:

  $ R "${S} && install_ctr --version prplos-v1 --ee --uuid --privileged true --envvar" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v1
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)


Verify that the EnvVariables were properly passed to the container:

  $ R "${S} && execute_in_container --uuid --cmd \"env\" | grep ENVVAR_KEY1"
  ENVVAR_KEY1=ENVVAR_VALUE1
  $ R "${S} && execute_in_container --uuid --cmd \"env\" | grep ENVVAR_KEY2"
  ENVVAR_KEY2=ENVVAR_VALUE2


Update the container without EnvVariables and check its running the previous list is kept:

  $ R "${S} && update_ctr --version prplos-v2 --ee --uuid --privileged true" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v2
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)
  $ R "${S} && execute_in_container --uuid --cmd \"env\" | grep ENVVAR_KEY1"
  ENVVAR_KEY1=ENVVAR_VALUE1
  $ R "${S} && execute_in_container --uuid --cmd \"env\" | grep ENVVAR_KEY2"
  ENVVAR_KEY2=ENVVAR_VALUE2


Update the container with a new list of EnvVariables and check its running and the variables updated:

  $ R "${S} && update_ctr --version prplos-v1 --ee --uuid --privileged true --envvar '[{Key=\"ENVVAR_KEY3\", Value=\"ENVVAR_VALUE3\"}]'" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v1
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)
  $ R "${S} && execute_in_container --uuid --cmd \"env\" | grep ENVVAR_KEY3"
  ENVVAR_KEY3=ENVVAR_VALUE3
  $ R "${S} && execute_in_container --uuid --cmd \"env\" | grep ENVVAR_KEY1"
  [1]
  $ R "${S} && execute_in_container --uuid --cmd \"env\" | grep ENVVAR_KEY2"
  [1]


Uninstall the testing container and check datamodel cleaned:

  $ R "${S} && uninstall_ctr_and_check --uuid --retaindata false"
  [1]


Cleanup test environment:

  $ R "rm -f /tmp/script_functions.sh"
