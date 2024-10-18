## Unprivileged container tests ##
Setup the test configuration:
  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Install a test container in Unprivileged mode and check it is running in Unprivileged mode:
  $ DM_API="SoftwareModules.InstallDU(${URL_PRPLOS_V1_PARAM}, ${UUID_PARAM}, ${EXEC_ENV_PARAM}, ${UNPRIVILEGED_PARAM}, ${NUM_UIDS_PARAM})"
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

  $ DM_API="SoftwareModules.ExecutionUnit.[${EUID_FILTER}].?0"
  $ UID=$(R "${CLI_JSON} \"${DM_API}\"| jsonfilter -e @[*].*.AllocatedHostUID")
  $ [ "${UID}" -ne 0 ] && echo "Unprivileged container" || echo "Privileged container"
  Unprivileged container

  $ GID=$(R "${CLI_JSON} \"${DM_API}\"| jsonfilter -e @[*].*.AllocatedHostGID")
  $ [ "${GID}" -ne 0 ] && echo "Unprivileged container" || echo "Privileged container"
  Unprivileged container

Update the container to run in privileged mode:
  $ DM_API="SoftwareModules.DeploymentUnit.[${UUID_FILTER}].Update(${URL_PRPLOS_V1_PARAM}, ${PRIVILEGED_PARAM})"
  $ R "${CLI} \"${DM_API}\"" > /dev/null

Check that test container is installed and running in privileged mode:
  $ sleep ${UPDATE_TIMER}
  $ DM_API="SoftwareModules.ExecutionUnit.[${EUID_FILTER}].?0"
  $ R "${CLI_JSON} \"${DM_API}\" | jsonfilter -e @[*].*.Status -e @[*].*.Version -e @[*].*.Name | sort"
  Active
  prpl-foundation/prplos/prplos/prplos/lcm-test-x86-64
  prplos-v1

  $ DM_API="SoftwareModules.ExecutionUnit.[${EUID_FILTER}].?0"
  $ UID=$(R "${CLI_JSON} \"${DM_API}\"| jsonfilter -e @[*].*.AllocatedHostUID")
  $ [ "${UID}" -ne 0 ] && echo "Unprivileged container" || echo "Privileged container"
  Privileged container

  $ GID=$(R "${CLI_JSON} \"${DM_API}\"| jsonfilter -e @[*].*.AllocatedHostGID")
  $ [ "${GID}" -ne 0 ] && echo "Unprivileged container" || echo "Privileged container"
  Privileged container


Uninstall the testing container and check the datamodel is cleaned:
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

