## Setup test configuration
Setup the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh"
  $ C ${TESTDIR}/script_functions.sh root@${TARGET_LAN_IP}:/tmp/script_functions.sh 2>/dev/null


### PRIVILEGED CONTAINER SECTION ###
Install a test container with ApplicationData config and check it is running:

  $ R "${S} && install_ctr --version prplos-v1 --ee --uuid --privileged true --network --appdata" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v1
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)


Check that ApplicationData volumes are available inside the container and use them:

  $ R "${S} && execute_in_container --uuid --cmd 'ls -l /'" | grep volume | awk '{print $9}'
  volume1
  volume2
  $ R "${S} && execute_in_container --uuid --cmd 'echo volume1_content > /volume1/file_volume1'"
  $ R "${S} && execute_in_container --uuid --cmd 'cat /volume1/file_volume1'"
  volume1_content
  $ R "${S} && execute_in_container --uuid --cmd 'echo volume2_content > /volume2/file_volume2'"
  $ R "${S} && execute_in_container --uuid --cmd 'cat /volume2/file_volume2'"
  volume2_content

Uninstall the testing container with retaining data and check it is cleaned in the datamodel:

  $ R "${S} && uninstall_ctr_and_check --uuid --retaindata true"
  [1]


Reinstall the container and check the content of the retained ApplicationData volumes:

  $ R "${S} && install_ctr --version prplos-v1 --ee --uuid --privileged true --network --appdata" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v1
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)

  $ R "${S} && execute_in_container --uuid --cmd 'ls -l /'" | grep volume | awk '{print $9}'
  volume1
  volume2

  $ R "${S} && execute_in_container --uuid --cmd 'ls /volume1/file_volume1'" 2> /dev/null
  [1]
  $ R "${S} && execute_in_container --uuid --cmd 'cat /volume2/file_volume2'"
  volume2_content


Test the upgrade persistence of the ApplicationData volumes:

  $ R "${S} && update_ctr --version prplos-v2 --ee --uuid --privileged true --network --appdata --retaindata true" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v2
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)

  $ R "${S} && execute_in_container --uuid --cmd 'ls -l /'" | grep volume | awk '{print $9}'
  volume1
  volume2

  $ R "${S} && execute_in_container --uuid --cmd 'ls /volume1/file_volume1'" 2> /dev/null
  [1]
  $ R "${S} && execute_in_container --uuid --cmd 'cat /volume2/file_volume2'"
  volume2_content


Uninstall the testing container without retaining data and check it is cleaned in the datamodel:

  $ R "${S} && uninstall_ctr_and_check --uuid --retaindata false"
  [1]




### PRIVILEGED CONTAINER SECTION ###
Install a test container with ApplicationData config and check it is running:

  $ R "${S} && install_ctr --version prplos-v1 --ee --uuid --privileged false --network --appdata" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v1
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)


Check that ApplicationData volumes are available inside the container and use them:

  $ R "${S} && execute_in_container --uuid --cmd 'ls -l /'" | grep volume | awk '{print $9}'
  volume1
  volume2
  $ R "${S} && execute_in_container --uuid --cmd 'echo volume1_content > /volume1/file_volume1'"
  $ R "${S} && execute_in_container --uuid --cmd 'cat /volume1/file_volume1'"
  volume1_content
  $ R "${S} && execute_in_container --uuid --cmd 'echo volume2_content > /volume2/file_volume2'"
  $ R "${S} && execute_in_container --uuid --cmd 'cat /volume2/file_volume2'"
  volume2_content

Uninstall the testing container with retaining data and check it is cleaned in the datamodel:

  $ R "${S} && uninstall_ctr_and_check --uuid --retaindata true"
  [1]


Reinstall the container and check the content of the retained ApplicationData volumes:

  $ R "${S} && install_ctr --version prplos-v1 --ee --uuid --privileged false --network --appdata" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v1
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)

  $ R "${S} && execute_in_container --uuid --cmd 'ls -l /'" | grep volume | awk '{print $9}'
  volume1
  volume2

  $ R "${S} && execute_in_container --uuid --cmd 'ls /volume1/file_volume1'" 2> /dev/null
  [1]
  $ R "${S} && execute_in_container --uuid --cmd 'cat /volume2/file_volume2'"
  volume2_content

  $ R "${S} && execute_in_container --uuid --cmd 'ls /volume1/file_volume1'" 2> /dev/null
  [1]
  $ R "${S} && execute_in_container --uuid --cmd 'cat /volume2/file_volume2'"
  volume2_content


Test the upgrade persistence of the ApplicationData volumes:

  $ R "${S} && update_ctr --version prplos-v2 --ee --uuid --privileged false --network --appdata --retaindata true" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v2
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)

  $ R "${S} && execute_in_container --uuid --cmd 'ls -l /'" | grep volume | awk '{print $9}'
  volume1
  volume2

  $ R "${S} && execute_in_container --uuid --cmd 'ls /volume1/file_volume1'" 2> /dev/null
  [1]
  $ R "${S} && execute_in_container --uuid --cmd 'cat /volume2/file_volume2'"
  volume2_content


Uninstall the testing container and check datamodel cleaned:

  $ R "${S} && uninstall_ctr_and_check --uuid --retaindata false"
  [1]


Cleanup test environment:

  $ R "rm -f /tmp/script_functions.sh"
