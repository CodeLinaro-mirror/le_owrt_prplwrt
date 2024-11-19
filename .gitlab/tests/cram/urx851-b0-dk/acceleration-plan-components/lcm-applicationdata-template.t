## APPLICATION DATA dedicated tests ##
Setup the test configuration:
  $ alias R="${CRAM_REMOTE_COMMAND:-}"

### PRIVILEGED CONTAINER SECTION ###
Install a test container with a ApplicationData and check it is running:
  $ DM_API="SoftwareModules.InstallDU(${URL_PRPLOS_V1_PARAM}, ${UUID_PARAM}, ${EXEC_ENV_PARAM}, ${APPLICATION_DATA_PARAM}, ${PRIVILEGED_PARAM})"
  $ R "${CLI} \"${DM_API}\"" > /dev/null
  $ sleep ${INSTALL_TIMER}
  $ DM_API="SoftwareModules.DeploymentUnit.[${UUID_FILTER}].DUID?"
  $ CONTAINER_ID=$(R "${CLI_JSON} \"${DM_API}\" | jsonfilter -e @[*].*.DUID")
  $ EUID_FILTER="EUID == \\\"${CONTAINER_ID}\\\""
  $ DM_API="SoftwareModules.ExecutionUnit.[${EUID_FILTER}].?0"
  $ R "${CLI_JSON} \"${DM_API}\" | jsonfilter -e @[*].*.Status -e @[*].*.Version -e @[*].*.Name | sort"
  Active
  prpl-foundation/prplos/prplos/prplos/lcm-test-x86-64
  prplos-v1

Check that ApplicationData volumes are available inside the container and use them
  $ R "lxc-attach -n ${CONTAINER_ID} -- ls -l / | grep volume | awk '{print $9}'"
  volume1
  volume2
  $ R "lxc-attach -n ${CONTAINER_ID} -- sh -c \"echo volume1_content > /volume1/file_volume1\""
  [0]
  $ R "lxc-attach -n ${CONTAINER_ID} -- sh -c \"cat /volume1/file_volume1\""
  volume1_content
  $ R "lxc-attach -n ${CONTAINER_ID} -- sh -c \"echo volume2_content > /volume2/file_volume2\""
  [0]
  $ R "lxc-attach -n ${CONTAINER_ID} -- sh -c \"cat /volume2/file_volume2\""
  volume2_content

Uninstall the testing container and check the it is cleaned in the datamodel:
  $ DM_API="SoftwareModules.DeploymentUnit.[${UUID_FILTER}].Uninstall(RetainData = true)"
  $ R "${CLI} \"${DM_API}\"" > /dev/null
  $ sleep ${UNINSTALL_TIMER}
  $ DM_API="SoftwareModules.DeploymentUnit.?0"
  $ R "${CLI_JSON} \"${DM_API}\" | jsonfilter -e @[*].*.DUID | grep ${CONTAINER_ID}"
  [1]
  $ DM_API="SoftwareModules.ExecutionUnit.?0"
  $ R "${CLI_JSON} \"${DM_API}\" | jsonfilter -e @[*].*.EUID | grep ${CONTAINER_ID}"
  [1]
  $ DM_API="Rlyeh.Images.?0"
  $ R "${CLI_JSON} \"${DM_API}\" | jsonfilter -e @[*].*.DUID | grep ${CONTAINER_ID}"
  [1]

Reinstall the container and check the content of the retained ApplicationData volume:
  $ DM_API="SoftwareModules.InstallDU(${URL_PRPLOS_V1_PARAM}, ${UUID_PARAM}, ${EXEC_ENV_PARAM}, ${APPLICATION_DATA_PARAM}, ${PRIVILEGED_PARAM})"
  $ R "${CLI} \"${DM_API}\"" > /dev/null
  $ sleep ${INSTALL_TIMER}
  $ DM_API="SoftwareModules.DeploymentUnit.[${UUID_FILTER}].DUID?"
  $ CONTAINER_ID=$(R "${CLI_JSON} \"${DM_API}\" | jsonfilter -e @[*].*.DUID")
  $ EUID_FILTER="EUID == \\\"${CONTAINER_ID}\\\""
  $ DM_API="SoftwareModules.ExecutionUnit.[${EUID_FILTER}].?0"
  $ R "${CLI_JSON} \"${DM_API}\" | jsonfilter -e @[*].*.Status -e @[*].*.Version -e @[*].*.Name | sort"
  Active
  prpl-foundation/prplos/prplos/prplos/lcm-test-x86-64
  prplos-v1
  $ R "lxc-attach -n ${CONTAINER_ID} -- ls -l / | grep volume | awk '{print $9}'"
  volume1
  volume2
  $ R "lxc-attach -n ${CONTAINER_ID} -- sh -c \"ls /volume1/file_volume1\""
  ls: /volume1/file_volume1: No such file or directory
  $ R "lxc-attach -n ${CONTAINER_ID} -- sh -c \"cat /volume2/file_volume2\""
  volume2_content


### UNPRIVILEGED CONTAINER SECTION ###
Install a test container with a ApplicationData and check it is running:
  $ DM_API="SoftwareModules.InstallDU(${URL_PRPLOS_V1_PARAM}, ${UUID_PARAM}, ${EXEC_ENV_PARAM}, ${APPLICATION_DATA_PARAM}, ${UNPRIVILEGED_PARAM}, ${NUM_UIDS_PARAM})"
  $ R "${CLI} \"${DM_API}\"" > /dev/null
  $ sleep ${INSTALL_TIMER}
  $ DM_API="SoftwareModules.DeploymentUnit.[${UUID_FILTER}].DUID?"
  $ CONTAINER_ID=$(R "${CLI_JSON} \"${DM_API}\" | jsonfilter -e @[*].*.DUID")
  $ EUID_FILTER="EUID == \\\"${CONTAINER_ID}\\\""
  $ DM_API="SoftwareModules.ExecutionUnit.[${EUID_FILTER}].?0"
  $ R "${CLI_JSON} \"${DM_API}\" | jsonfilter -e @[*].*.Status -e @[*].*.Version -e @[*].*.Name | sort"
  Active
  prpl-foundation/prplos/prplos/prplos/lcm-test-x86-64
  prplos-v1

Check that ApplicationData volumes are available inside the container and use them
  $ R "lxc-attach -n ${CONTAINER_ID} -- ls -l / | grep volume | awk '{print $9}'"
  volume1
  volume2
  $ R "lxc-attach -n ${CONTAINER_ID} -- sh -c \"echo volume1_content > /volume1/file_volume1\""
  [0]
  $ R "lxc-attach -n ${CONTAINER_ID} -- sh -c \"cat /volume1/file_volume1\""
  volume1_content
  $ R "lxc-attach -n ${CONTAINER_ID} -- sh -c \"echo volume2_content > /volume2/file_volume2\""
  [0]
  $ R "lxc-attach -n ${CONTAINER_ID} -- sh -c \"cat /volume2/file_volume2\""
  volume2_content

Uninstall the testing container and check the it is cleaned in the datamodel:
  $ DM_API="SoftwareModules.DeploymentUnit.[${UUID_FILTER}].Uninstall(RetainData = true)"
  $ R "${CLI} \"${DM_API}\"" > /dev/null
  $ sleep ${UNINSTALL_TIMER}
  $ DM_API="SoftwareModules.DeploymentUnit.?0"
  $ R "${CLI_JSON} \"${DM_API}\" | jsonfilter -e @[*].*.DUID | grep ${CONTAINER_ID}"
  [1]
  $ DM_API="SoftwareModules.ExecutionUnit.?0"
  $ R "${CLI_JSON} \"${DM_API}\" | jsonfilter -e @[*].*.EUID | grep ${CONTAINER_ID}"
  [1]
  $ DM_API="Rlyeh.Images.?0"
  $ R "${CLI_JSON} \"${DM_API}\" | jsonfilter -e @[*].*.DUID | grep ${CONTAINER_ID}"
  [1]

Reinstall the container and check the content of the retained ApplicationData volume:
  $ DM_API="SoftwareModules.InstallDU(${URL_PRPLOS_V1_PARAM}, ${UUID_PARAM}, ${EXEC_ENV_PARAM}, ${APPLICATION_DATA_PARAM}, ${UNPRIVILEGED_PARAM}, ${NUM_UIDS_PARAM})"
  $ R "${CLI} \"${DM_API}\"" > /dev/null
  $ sleep ${INSTALL_TIMER}
  $ DM_API="SoftwareModules.DeploymentUnit.[${UUID_FILTER}].DUID?"
  $ CONTAINER_ID=$(R "${CLI_JSON} \"${DM_API}\" | jsonfilter -e @[*].*.DUID")
  $ EUID_FILTER="EUID == \\\"${CONTAINER_ID}\\\""
  $ DM_API="SoftwareModules.ExecutionUnit.[${EUID_FILTER}].?0"
  $ R "${CLI_JSON} \"${DM_API}\" | jsonfilter -e @[*].*.Status -e @[*].*.Version -e @[*].*.Name | sort"
  Active
  prpl-foundation/prplos/prplos/prplos/lcm-test-x86-64
  prplos-v1
  $ R "lxc-attach -n ${CONTAINER_ID} -- ls -l / | grep volume | awk '{print $9}'"
  volume1
  volume2
  $ R "lxc-attach -n ${CONTAINER_ID} -- sh -c \"ls /volume1/file_volume1\""
  ls: /volume1/file_volume1: No such file or directory
  $ R "lxc-attach -n ${CONTAINER_ID} -- sh -c \"cat /volume2/file_volume2\""
  volume2_content

