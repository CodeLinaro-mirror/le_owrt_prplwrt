## NetworkConfig verification ##
Setup the test configuration:
  $ alias R="${CRAM_REMOTE_COMMAND:-}"

### PRIVILEGED CONTAINER SECTION ###
Install testing prplOS container v1:
  $ DM_API="SoftwareModules.InstallDU(${URL_PRPLOS_V1_PARAM}, ${UUID_PARAM}, ${EXEC_ENV_PARAM}, ${NETWORKCONFIG_PARAM}, ${PRIVILEGED_PARAM})"
  $ R "${CLI} \"${DM_API}\"" >> /dev/null
  $ sleep ${INSTALL_TIMER}
  $ DM_API="SoftwareModules.DeploymentUnit.[${UUID_FILTER}].DUID?"
  $ CONTAINER_ID=$(R "${CLI_JSON} \"${DM_API}\" | jsonfilter -e @[*].*.DUID")
  $ EUID_FILTER="EUID == \\\"${CONTAINER_ID}\\\""
  $ DM_API="SoftwareModules.ExecutionUnit.[${EUID_FILTER}].?0"
  $ R "${CLI_JSON} \"${DM_API}\" | jsonfilter -e @[*].*.Status -e @[*].*.Version -e @[*].*.Name | sort"
  Active
  prpl-foundation/prplos/prplos/prplos/lcm-test-x86-64
  prplos-v1

Check NetworkConfig correctly applied:
  $ DM_API="Cthulhu.Container.Instances.[${LINKEDUUID_FILTER}].Interfaces.[${NETWORK_INTERFACE_FILTER}].Addresses.1.?"
  $ CTR_IP=$(R "${CLI_JSON} \"${DM_API}\" | jsonfilter -e @[*].*.Address")
  $ R "ssh -y root@${CTR_IP} 'cat /etc/container-version ; ip route show default | grep default' 2> /dev/null"
  1
  default via 192.168.3.1 dev lcm0 


Update to prplOS container to v2:
  $ DM_API="SoftwareModules.DeploymentUnit.[${UUID_FILTER}].Update(${URL_PRPLOS_V2_PARAM}, ${NETWORKCONFIG_PARAM}, ${PRIVILEGED_PARAM})"
  $ R "${CLI} \"${DM_API}\"" > /dev/null

Check that prplOS container v2 is running:
  $ sleep ${UPDATE_TIMER}
  $ DM_API="SoftwareModules.ExecutionUnit.[${EUID_FILTER}].?0"
  $ R "${CLI_JSON} \"${DM_API}\" | jsonfilter -e @[*].*.Status -e @[*].*.Version -e @[*].*.Name | sort"
  Active
  prpl-foundation/prplos/prplos/prplos/lcm-test-x86-64
  prplos-v2

Check NetworkConfig correctly applied and verify the container version:
  $ DM_API="Cthulhu.Container.Instances.[${LINKEDUUID_FILTER}].Interfaces.[${NETWORK_INTERFACE_FILTER}].Addresses.1.?"
  $ CTR_IP=$(R "${CLI_JSON} \"${DM_API}\" | jsonfilter -e @[*].*.Address")
  $ R "ssh -y root@${CTR_IP} 'cat /etc/container-version ; ip route show default | grep default' 2> /dev/null"
  2
  default via 192.168.3.1 dev lcm0 

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

### UNPRIVILEGED CONTAINER SECTION ###
Install testing prplOS container v1:
  $ DM_API="SoftwareModules.InstallDU(${URL_PRPLOS_V1_PARAM}, ${UUID_PARAM}, ${EXEC_ENV_PARAM}, ${NETWORKCONFIG_PARAM}, ${UNPRIVILEGED_PARAM}, ${NUM_UIDS_PARAM})"
  $ R "${CLI} \"${DM_API}\"" >> /dev/null
  $ sleep ${INSTALL_TIMER}
  $ DM_API="SoftwareModules.DeploymentUnit.[${UUID_FILTER}].DUID?"
  $ CONTAINER_ID=$(R "${CLI_JSON} \"${DM_API}\" | jsonfilter -e @[*].*.DUID")
  $ EUID_FILTER="EUID == \\\"${CONTAINER_ID}\\\""
  $ DM_API="SoftwareModules.ExecutionUnit.[${EUID_FILTER}].?0"
  $ R "${CLI_JSON} \"${DM_API}\" | jsonfilter -e @[*].*.Status -e @[*].*.Version -e @[*].*.Name | sort"
  Active
  prpl-foundation/prplos/prplos/prplos/lcm-test-x86-64
  prplos-v1

Check NetworkConfig correctly applied:
  $ DM_API="Cthulhu.Container.Instances.[${LINKEDUUID_FILTER}].Interfaces.[${NETWORK_INTERFACE_FILTER}].Addresses.1.?"
  $ CTR_IP=$(R "${CLI_JSON} \"${DM_API}\" | jsonfilter -e @[*].*.Address")
  $ R "ssh -y root@${CTR_IP} 'cat /etc/container-version ; ip route show default | grep default' 2> /dev/null"
  1
  default via 192.168.3.1 dev lcm0 


Update to prplOS container to v2:
  $ DM_API="SoftwareModules.DeploymentUnit.[${UUID_FILTER}].Update(${URL_PRPLOS_V2_PARAM}, ${NETWORKCONFIG_PARAM}, ${PRIVILEGED_PARAM})"
  $ R "${CLI} \"${DM_API}\"" > /dev/null

Check that prplOS container v2 is running:
  $ sleep ${UPDATE_TIMER}
  $ DM_API="SoftwareModules.ExecutionUnit.[${EUID_FILTER}].?0"
  $ R "${CLI_JSON} \"${DM_API}\" | jsonfilter -e @[*].*.Status -e @[*].*.Version -e @[*].*.Name | sort"
  Active
  prpl-foundation/prplos/prplos/prplos/lcm-test-x86-64
  prplos-v2

Check NetworkConfig correctly applied and verify the container version:
  $ DM_API="Cthulhu.Container.Instances.[${LINKEDUUID_FILTER}].Interfaces.[${NETWORK_INTERFACE_FILTER}].Addresses.1.?"
  $ CTR_IP=$(R "${CLI_JSON} \"${DM_API}\" | jsonfilter -e @[*].*.Address")
  $ R "ssh -y root@${CTR_IP} 'cat /etc/container-version ; ip route show default | grep default' 2> /dev/null"
  2
  default via 192.168.3.1 dev lcm0 

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
