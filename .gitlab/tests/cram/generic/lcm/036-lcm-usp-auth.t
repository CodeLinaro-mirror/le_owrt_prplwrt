## Setup test configuration
Setup the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ R logger -t cram Starting $TESTFILE
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh"
  $ C ${TESTDIR}/script_functions.sh root@${TARGET_LAN_IP}:/tmp/script_functions.sh 2>/dev/null
## FIXME: `get_arch_name` function returns wrong arch name for freedom board
  $ BOARD_ARCH=$(R "${S} && get_true_arch_name")
  $ SERVICE_URL="docker://registry.gitlab.com/prpl-foundation/prplos/prplos/${BOARD_ARCH}/image-lcmsampleapp-auth-supported:latest"


Set-up ExecEnv configuration

  $ R "${S} && set_ee_roles --roles \"Full Access\"" > /dev/null
  $ R "${S} && check_available_roles --ee"
  Device.LocalAgent.ControllerTrust.Role.1.

### TRUSTED SERVICE SECTION ###
Install the container and check its status and type:

  $ R "${S} && install_ctr --url ${SERVICE_URL} --ee --uuid --privileged true --usprequired \"Full Access\"" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  latest
  prpl-foundation/prplos/prplos/*/image-lcmsampleapp* (glob)
  $ R "${S} && get_ctr_type --uuid"
  Privileged container

Check that the container has the expected EndpointID, AutoMountIPC value:

  $ CTR_ID=$(R "${S} && get_container_parameter --uuid --param EUID")
  $ R "ba-cli -l 'Cthulhu.Container.Instances.[ContainerId==\"$CTR_ID\"].AutoMountIPC?' | sed '/^$/d'"
  USP_UDS_Unauthenticated
  $ R "ba-cli -l 'Cthulhu.Container.Instances.[ContainerId==\"$CTR_ID\"].EndpointID?' | sed '/^$/d'"
  uuid::* (glob)
  $ R "ba-cli -l 'Device.SoftwareModules.ExecutionUnit.[EUID==\"$CTR_ID\"].X_PRPLWARE-COM_AutoMountIPC?' | sed '/^$/d'"
  USP_UDS_Unauthenticated
  $ R "ba-cli -l 'Device.SoftwareModules.ExecutionUnit.[EUID==\"$CTR_ID\"].RegisterTrustPaths?' | sed '/^$/d'"

Check that trusted UDS sockets are mounted in the container:

  $ R "${S} && execute_in_container --uuid --cmd 'mount | grep usp'"
  tmpfs on /run/usp type tmpfs* (glob)

Check that service model is accessible on USP bus:

  $ R "usp-cli -lj Device.LCMSampleApp.? | sed '/^$/d'"
  [{"Device.LCMSampleApp.":{"NumberOfDummyMultiInstances":0,"DummyGlobalString":"","DummyGlobalInt":0}}]

Stop the container and check its status:

  $ R "${S} && stop_ctr --uuid" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Idle
  latest
  prpl-foundation/prplos/prplos/*/image-lcmsampleapp* (glob)

Uninstall the container and check everything is cleaned:

  $ R "${S} && uninstall_ctr_and_check --uuid"
  [1]


### UNTRUSTED SERVICE SECTION ###
Install the container as untrusted and check its status and type:

  $ R "${S} && install_ctr --url ${SERVICE_URL} --ee --uuid --privileged true --usprequired \"Full Access\" --uspregisterpaths \"Device.LCMSampleApp.\" --uspautomountipc \"USP_UDS_Authenticated\"" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  latest
  prpl-foundation/prplos/prplos/*/image-lcmsampleapp* (glob)
  $ R "${S} && get_ctr_type --uuid"
  Privileged container

Check that the container has the expected EndpointID, AutoMountIPC and RegisterTrustPaths values:

  $ CTR_ID=$(R "${S} && get_container_parameter --uuid --param EUID")
  $ CTR_ENDPOINTID=$(R "ba-cli -l 'Cthulhu.Container.Instances.[ContainerId==\"${CTR_ID}\"].EndpointID?' | sed '/^$/d'")
  $ R "ba-cli -l 'Cthulhu.Container.Instances.[ContainerId==\"${CTR_ID}\"].EndpointID?' | sed '/^$/d'"
  uuid::* (glob)
  $ R "ba-cli -l 'Cthulhu.Container.Instances.[ContainerId==\"${CTR_ID}\"].AutoMountIPC?' | sed '/^$/d'"
  USP_UDS_Authenticated
  $ R "ba-cli -l 'Cthulhu.Container.Instances.[ContainerId==\"${CTR_ID}\"].RegisterTrustPaths?' | sed '/^$/d'"
  Device.LCMSampleApp.
  $ R "ba-cli -l 'Device.SoftwareModules.ExecutionUnit.[EUID==\"$CTR_ID\"].X_PRPLWARE-COM_AutoMountIPC?' | sed '/^$/d'"
  USP_UDS_Authenticated
  $ R "ba-cli -l 'Device.SoftwareModules.ExecutionUnit.[EUID==\"$CTR_ID\"].RegisterTrustPaths?' | sed '/^$/d'"
  Device.LCMSampleApp.

Check that untrusted UDS sockets are mounted in the container:

  $ R "${S} && execute_in_container --uuid --cmd 'mount | grep usp'"
  tmpfs on /run/usp/sockets/authenticated/broker_controller* (glob)
  tmpfs on /run/usp/sockets/authenticated/broker_agent* (glob)

Check that Device.USPServices.Trust model is filled on USP bus:

  $ R "usp-cli -lj 'Device.USPServices.Trust.[EndpointID==\"${CTR_ENDPOINTID}\"].?' | sed '/^$/d'"
  [{"Device.USPServices.Trust.*.":{"TargetPaths":"Device.LCMSampleApp.","EndpointID":"*"}}] (glob)

Check that Device.UnixDomainSockets.Authentication model is filled on USP bus:

  $ R "usp-cli -lj 'Device.UnixDomainSockets.Authentication.[EndpointID==\"${CTR_ENDPOINTID}\"].?' | sed '/^$/d'"
  [{"Device.UnixDomainSockets.Authentication.*.":{"Enable":true,"Password":"*","EndpointID":"*"}}] (glob)

Check that service model is accessible on USP bus:

  $ R "usp-cli -lj Device.LCMSampleApp.? | sed '/^$/d'"
  [{"Device.LCMSampleApp.":{"NumberOfDummyMultiInstances":0,"DummyGlobalString":"","DummyGlobalInt":0}}]

Stop the container and check its status:

  $ R "${S} && stop_ctr --uuid" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Idle
  latest
  prpl-foundation/prplos/prplos/*/image-lcmsampleapp* (glob)

Check that Device.USPServices.Trust instance still exists on USP bus:

  $ R "usp-cli -lj 'Device.USPServices.Trust.[EndpointID==\"${CTR_ENDPOINTID}\"].?' | sed '/^$/d'"
  [{"Device.USPServices.Trust.*.":{"TargetPaths":"Device.LCMSampleApp.","EndpointID":"*"}}] (glob)

Check that Device.UnixDomainSockets.Authentication instance is removed from USP bus:

  $ R "usp-cli -lj 'Device.UnixDomainSockets.Authentication.[EndpointID==\"${CTR_ENDPOINTID}\"].?' | sed '/^$/d'"
  [{}]


Uninstall the container and check everything is cleaned:

  $ R "${S} && uninstall_ctr_and_check --uuid"
  [1]
  $ R "usp-cli -lj 'Device.USPServices.Trust.[EndpointID==\"${CTR_ENDPOINTID}\"].?' | sed '/^$/d'"
  [{}]

Check that trusted service can be updated to untrusted:

  $ R "${S} && install_ctr --url ${SERVICE_URL} --ee --uuid --privileged true --usprequired \"Full Access\"" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  latest
  prpl-foundation/prplos/prplos/*/image-lcmsampleapp* (glob)
  $ CTR_ID=$(R "${S} && get_container_parameter --uuid --param EUID")
  $ CTR_ENDPOINTID=$(R "ba-cli -l 'Cthulhu.Container.Instances.[ContainerId==\"${CTR_ID}\"].EndpointID?' | sed '/^$/d'")
  $ R "ba-cli -l 'Cthulhu.Container.Instances.[ContainerId==\"${CTR_ID}\"].EndpointID?' | sed '/^$/d'"
  uuid::* (glob)
  $ R "ba-cli -l 'Cthulhu.Container.Instances.[ContainerId==\"${CTR_ID}\"].AutoMountIPC?' | sed '/^$/d'"
  USP_UDS_Unauthenticated
  $ R "${S} && update_ctr --url ${SERVICE_URL} --ee --uuid --privileged true --usprequired \"Full Access\" --uspregisterpaths \"Device.LCMSampleApp.\" --uspautomountipc \"USP_UDS_Authenticated\"" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  latest
  prpl-foundation/prplos/prplos/*/image-lcmsampleapp* (glob)
  $ R "ba-cli -l 'Cthulhu.Container.Instances.[ContainerId==\"${CTR_ID}\"].EndpointID?' | sed '/^$/d'"
  uuid::* (glob)
  $ R "ba-cli -l 'Cthulhu.Container.Instances.[ContainerId==\"${CTR_ID}\"].AutoMountIPC?' | sed '/^$/d'"
  USP_UDS_Authenticated
  $ R "ba-cli -l 'Cthulhu.Container.Instances.[ContainerId==\"${CTR_ID}\"].RegisterTrustPaths?' | sed '/^$/d'"
  Device.LCMSampleApp.
  $ R "ba-cli -l 'Device.SoftwareModules.ExecutionUnit.[EUID==\"$CTR_ID\"].X_PRPLWARE-COM_AutoMountIPC?' | sed '/^$/d'"
  USP_UDS_Authenticated
  $ R "ba-cli -l 'Device.SoftwareModules.ExecutionUnit.[EUID==\"$CTR_ID\"].RegisterTrustPaths?' | sed '/^$/d'"
  Device.LCMSampleApp.

Check that EndpointID remains the same after update:

  $ CTR_ENDPOINTID_UPDATED=$(R "ba-cli -l 'Cthulhu.Container.Instances.[ContainerId==\"${CTR_ID}\"].EndpointID?' | sed '/^$/d'")
  $ [ ${CTR_ENDPOINTID} = ${CTR_ENDPOINTID_UPDATED} ] && echo 'OK' || echo 'FAIL'
  OK

Check that untrusted UDS sockets are mounted in the container after update:

  $ R "${S} && execute_in_container --uuid --cmd 'mount | grep usp'"
  tmpfs on /run/usp/sockets/authenticated/broker_controller* (glob)
  tmpfs on /run/usp/sockets/authenticated/broker_agent* (glob)

Check that Device.USPServices.Trust model is filled on USP bus after update:

  $ R "usp-cli -lj 'Device.USPServices.Trust.[EndpointID==\"${CTR_ENDPOINTID}\"].?' | sed '/^$/d'"
  [{"Device.USPServices.Trust.*.":{"TargetPaths":"Device.LCMSampleApp.","EndpointID":"*"}}] (glob)

Check that Device.UnixDomainSockets.Authentication model is filled on USP bus after update:

  $ R "usp-cli -lj 'Device.UnixDomainSockets.Authentication.[EndpointID==\"${CTR_ENDPOINTID}\"].?' | sed '/^$/d'"
  [{"Device.UnixDomainSockets.Authentication.*.":{"Enable":true,"Password":"*","EndpointID":"*"}}] (glob)

Check that service model is accessible on USP bus after update:

  $ R "usp-cli -lj Device.LCMSampleApp.? | sed '/^$/d'"
  [{"Device.LCMSampleApp.":{"NumberOfDummyMultiInstances":0,"DummyGlobalString":"","DummyGlobalInt":0}}]

Uninstall the container and check everything is cleaned:

  $ R "${S} && uninstall_ctr_and_check --uuid"
  [1]
  $ R "usp-cli -lj 'Device.USPServices.Trust.[EndpointID==\"${CTR_ENDPOINTID}\"].?' | sed '/^$/d'"
  [{}]
  $ R logger -t cram Ended $TESTFILE

