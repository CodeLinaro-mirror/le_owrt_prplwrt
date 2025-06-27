## Setup test configuration
Setup the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh"
  $ C ${TESTDIR}/script_functions.sh root@${TARGET_LAN_IP}:/tmp/script_functions.sh 2>/dev/null


### CAPABILITIES CONTAINER SECTION ###
Create user roles with capabilities

  $ R "${S} && add_user_role --rolename testrole1 --capabilities \"CAP_NET_RAW,CAP_MKNOD\""
  
  {"Device.Users.Role.*.":{"Alias":"testrole1","RoleName":"testrole1"}} (glob)
  

  $ R "${S} && add_user_role --rolename testrole2 --capabilities \"CAP_KILL\""
  
  {"Device.Users.Role.*.":{"Alias":"testrole2","RoleName":"testrole2"}} (glob)
  

Add two user roles to the ExecutionEnvironment

  $ R "${S} && set_ee_roles --userroles \"testrole1,testrole2\""
  
  SoftwareModules.ExecEnv.1.ModifyAvailableRoles() returned
  ["",{"err_code":0,"err_msg":""}]
  

Two roles will be added
  $ R "${S} && check_available_user_roles"
  Device.Users.Role.[RoleName=="testrole1"],Device.Users.Role.[RoleName=="testrole2"]

Add three user roles to the ExecutionEnvironment, this should fail since one role is faulty

  $ R "${S} && set_ee_roles --userroles \"testrole1,norole,testrole2\""
  
  ERROR: call (null) failed with status 1 - unknown error
  SoftwareModules.ExecEnv.1.ModifyAvailableRoles() returned
  ["",{"err_code":7004,"err_msg":"User role [norole] does not exist in Device.Users.Role."}]
  

Two roles should still be present
  $ R "${S} && check_available_user_roles"
  Device.Users.Role.[RoleName=="testrole1"],Device.Users.Role.[RoleName=="testrole2"]

Install a privileged container without required user

  $ R "${S} && install_ctr --version prplos-v1 --ee --uuid --privileged true"
  
  SoftwareModules.InstallDU() returned
  ["",{"err_code":0,"err_msg":""}]
  

Check that the container has no capabilities
  $ R "${S} && execute_in_container --uuid --cmd 'grep CapEff /proc/1/status'"
  CapEff:\t0000000000000000 (esc)

Uninstall the container

  $ R "${S} && uninstall_ctr_and_check --uuid"
  [1]

Install an unprivileged container without required user

  $ R "${S} && install_ctr --version prplos-v1 --ee --uuid --privileged false"
  
  SoftwareModules.InstallDU() returned
  ["",{"err_code":0,"err_msg":""}]
  

Check that the container has no capabilities
  $ R "${S} && execute_in_container --uuid --cmd 'grep CapEff /proc/1/status'"
  CapEff:\t0000000000000000 (esc)

Uninstall the container

  $ R "${S} && uninstall_ctr_and_check --uuid"
  [1]

Install a container with user role that is not available. this should fail

  $ R "${S} && install_ctr --waittime 0 --version prplos-v1 --ee --uuid --privileged true --userroles norole"
  
  ERROR: call (null) failed with status 1 - unknown error
  SoftwareModules.InstallDU() returned
  ["",{"err_code":7037,"err_msg":"Sandbox [generic] does not have the required role [norole]"}]
  

Install a container with user role that is available. this should succeed

  $ R "${S} && install_ctr --version prplos-v1 --ee --uuid --privileged true --userroles testrole1"
  
  SoftwareModules.InstallDU() returned
  ["",{"err_code":0,"err_msg":""}]
  

Check that the container has the required capabilities

  $ R "${S} && execute_in_container --uuid --cmd 'grep CapEff /proc/1/status'"
  CapEff:\t0000000008002000 (esc)

  $ R "${S} && get_container_parameter --uuid --param RequiredUserRoles"
  Device.Users.Role.[RoleName=="testrole1"]

  $ R "${S} && get_container_parameter --uuid --param AvailableUserRoleCapabilities"
  CAP_NET_RAW,CAP_MKNOD

Update the container to also require testrole2
  $ R "${S} && update_ctr --version prplos-v1 --ee --uuid --privileged true --userroles testrole1,testrole2"
  
  SoftwareModules.DeploymentUnit.*.Update() returned (glob)
  ["",{"err_code":0,"err_msg":""}]
  

Check that the container has the required capabilities

  $ R "${S} && execute_in_container --uuid --cmd 'grep CapEff /proc/1/status'"
  CapEff:\t0000000008002020 (esc)

  $ R "${S} && get_container_parameter --uuid --param RequiredUserRoles"
  Device.Users.Role.[RoleName=="testrole1"],Device.Users.Role.[RoleName=="testrole2"]

  $ R "${S} && get_container_parameter --uuid --param AvailableUserRoleCapabilities"
  CAP_NET_RAW,CAP_MKNOD,CAP_KILL


Try removing active testrole2 from Devices.User.Role
  $ R "${S} && remove_user_role --rolename testrole2"
  
  ERROR: del Device.Users.Role.[Alias=="testrole2"]. failed * (glob)
  

Update the container to use no user roles
  $ R "${S} && update_ctr --version prplos-v1 --ee --uuid --privileged true --userroles"
  
  SoftwareModules.DeploymentUnit.*.Update() returned (glob)
  ["",{"err_code":0,"err_msg":""}]
  

  $ R "${S} && get_container_parameter --uuid --param RequiredUserRoles"
  

AvailableUserRoleCapabilities should be reset
  $ R "${S} && get_container_parameter --uuid --param AvailableUserRoleCapabilities"
  

Update the container to also require testrole2
  $ R "${S} && update_ctr --version prplos-v1 --ee --uuid --privileged true --userroles testrole1"
  
  SoftwareModules.DeploymentUnit.*.Update() returned (glob)
  ["",{"err_code":0,"err_msg":""}]
  

  $ R "${S} && get_container_parameter --uuid --param RequiredUserRoles"
  Device.Users.Role.[RoleName=="testrole1"]

Update the container without required users parameter
  $ R "${S} && update_ctr --version prplos-v1 --ee --uuid --privileged true"
  
  SoftwareModules.DeploymentUnit.*.Update() returned (glob)
  ["",{"err_code":0,"err_msg":""}]
  

Previously configured user role should still be present
  $ R "${S} && get_container_parameter --uuid --param RequiredUserRoles"
  Device.Users.Role.[RoleName=="testrole1"]

Uninstall the container

  $ R "${S} && uninstall_ctr_and_check --uuid"
  [1]

Remove the role again from the ExecutionEnvironment
  $ R "${S} && set_ee_roles --userroles \"\""
  
  SoftwareModules.ExecEnv.1.ModifyAvailableRoles() returned
  ["",{"err_code":0,"err_msg":""}]
  

No user roles should be present
  $ R "${S} && check_available_user_roles"
  
Remove testrole1 from Devices.User.Role
  $ R "${S} && remove_user_role --rolename testrole1"
  
  ["Device.Users.Role.*."] (glob)
  


