## USP RBAC dedicated tests ##
Setup the test configuration:
  $ alias R="${CRAM_REMOTE_COMMAND:-}"

### PRIVILEGED CONTAINER SECTION ###
Set a USP role in the ExecEnv and verify it is set properly:
  $ DM_API="SoftwareModules.ExecEnv.[${EXEC_ENV_FILTER}].ModifyAvailableRoles(${AVAILABLE_ROLES_PARAM})"
  $ R "${CLI} \"${DM_API}\"" > /dev/null
  $ DM_API="SoftwareModules.ExecEnv.[${EXEC_ENV_FILTER}].AvailableRoles?"
  $ R "${CLI_JSON} \"${DM_API}\" | jsonfilter -e @[*].*.AvailableRoles"
  Device.LocalAgent.ControllerTrust.Role.1.

Install a test container with a RequiredRoles and check it is running:
  $ DM_API="SoftwareModules.InstallDU(${URL_PRPLOS_V1_PARAM}, ${UUID_PARAM}, ${EXEC_ENV_PARAM}, ${REQUIRED_ROLES_PARAM}, ${PRIVILEGED_PARAM})"
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

Check that UDS sockets and the random USP_ENDPOINT_ID are shared with the container:
  $ R "lxc-attach ${CONTAINER_ID}  -- env | grep USP_ENDPOINT_ID | cut -d '=' -f 2 | wc -l"
  1
  $ R "lxc-attach ${CONTAINER_ID}  -- ls /run/usp/"
  broker_agent_path
  broker_controller_path

Uninstall the testing container and check the it is cleaned in the datamodel:
  $ DM_API="SoftwareModules.DeploymentUnit.[${UUID_FILTER}].Uninstall()"
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


### UNPRIVILEGED CONTAINER SECTION ###
Set a USP role in the ExecEnv and verify it is set properly:
  $ DM_API="SoftwareModules.ExecEnv.[${EXEC_ENV_FILTER}].ModifyAvailableRoles(${AVAILABLE_ROLES_PARAM})"
  $ R "${CLI} \"${DM_API}\"" > /dev/null
  $ DM_API="SoftwareModules.ExecEnv.[${EXEC_ENV_FILTER}].AvailableRoles?"
  $ R "${CLI_JSON} \"${DM_API}\" | jsonfilter -e @[*].*.AvailableRoles"
  Device.LocalAgent.ControllerTrust.Role.1.

Install a test container with a RequiredRoles and check it is running:
  $ DM_API="SoftwareModules.InstallDU(${URL_PRPLOS_V1_PARAM}, ${UUID_PARAM}, ${EXEC_ENV_PARAM}, ${REQUIRED_ROLES_PARAM}, ${UNPRIVILEGED_PARAM}, ${NUM_UIDS_PARAM})"
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

Check that UDS sockets and the random USP_ENDPOINT_ID are shared with the container:
  $ R "lxc-attach ${CONTAINER_ID}  -- env | grep USP_ENDPOINT_ID | cut -d '=' -f 2 | wc -l"
  1
  $ R "lxc-attach ${CONTAINER_ID}  -- ls /run/usp/"
  broker_agent_path
  broker_controller_path

Uninstall the testing container and check the it is cleaned in the datamodel:
  $ DM_API="SoftwareModules.DeploymentUnit.[${UUID_FILTER}].Uninstall()"
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
