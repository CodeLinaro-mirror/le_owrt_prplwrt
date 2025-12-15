## Setup test configuration
Setup the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh"
  $ C ${TESTDIR}/script_functions.sh root@${TARGET_LAN_IP}:/tmp/script_functions.sh 2>/dev/null


Set-up ExecEnv configuration

  $ R "${S} && set_ee_roles --roles \"Full Access\"" > /dev/null
  $ R "${S} && check_available_roles --ee"
  Device.LocalAgent.ControllerTrust.Role.1.

### PRIVILEGED CONTAINER SECTION ###
Install the container and check its status and type:

  $ R "${S} && install_ctr --version prplos-v1 --ee --uuid --privileged true --usprequired \"Full Access\"" > /dev/null
  $ sleep 30
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v1
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)
  $ R "${S} && get_ctr_type --uuid"
  Privileged container
  $ R "${S} && execute_in_container --uuid --cmd 'cat /etc/container-version'"
  1

Check that UDS sockets and the random USP_ENDPOINT_ID are shared with the container:

  $ R "${S} && execute_in_container --uuid --cmd \"env\" | grep USP_ENDPOINT_ID"
  USP_ENDPOINT_ID=uuid::* (glob)
  $ R "${S} && execute_in_container --uuid --cmd \"ls /run/usp/\""
  broker_agent_path
  broker_controller_path

## TODO: 
## add test to check connection to USP broker: This is requiring support of USP in the test container

Uninstall the container and check everything is cleaned:

  $ R "${S} && uninstall_ctr_and_check --uuid"
  [1]


### UNPRIVILEGED CONTAINER SECTION ###
Install the container and check its status and type:

  $ R "${S} && install_ctr --version prplos-v1 --ee --uuid --privileged false  --usprequired \"Full Access\"" > /dev/null
  $ sleep 30
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v1
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)
  $ R "${S} && get_ctr_type --uuid"
  Unprivileged container
  $ R "${S} && execute_in_container --uuid --cmd 'cat /etc/container-version'"
  1

Check that UDS sockets and the random USP_ENDPOINT_ID are shared with the container:

  $ R "${S} && execute_in_container --uuid --cmd \"env\" | grep USP_ENDPOINT_ID"
  USP_ENDPOINT_ID=uuid::* (glob)
  $ R "${S} && execute_in_container --uuid --cmd \"ls /run/usp/\""
  broker_agent_path
  broker_controller_path

## TODO: add test to check connection to USP broker: This is requiring support of USP in the test container

Uninstall the container and check everything is cleaned:

  $ R "${S} && uninstall_ctr_and_check --uuid"
  [1]


Cleanup test environment:

  $ R "${S} && set_ee_roles --roles \"\"" > /dev/null
  $ R "rm -f /tmp/script_functions.sh"
