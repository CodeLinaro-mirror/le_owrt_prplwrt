## Setup test configuration
Setup the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ R logger -t cram Starting $TESTFILE
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh"
  $ C ${TESTDIR}/script_functions.sh root@${TARGET_LAN_IP}:/tmp/script_functions.sh 2>/dev/null
## FIXME: `get_arch_name` function returns wrong arch name for freedom board
  $ BOARD_ARCH=$(R "${S} && get_true_arch_name")
  $ READER_SERVICE_URL="docker://registry.gitlab.com/prpl-foundation/prplos/prplos/${BOARD_ARCH}/image-trusted-reader:latest"
  $ PROVIDER_SERVICE_URL="docker://registry.gitlab.com/prpl-foundation/prplos/prplos/${BOARD_ARCH}/image-trusted-provider:1.0.0"


Set-up ExecEnv configuration

  $ R "${S} && set_ee_roles --roles \"Full Access\",\"Untrusted\"" > /dev/null
  $ R "${S} && check_available_roles --ee"
  Device.LocalAgent.ControllerTrust.Role.1.,Device.LocalAgent.ControllerTrust.Role.2.

### RESTRICTIONS CHECK ###

Check that untrusted service cannot read the data from USP bus when RequiredRoles is "Untrusted":

  $ R "${S} && install_ctr --url ${READER_SERVICE_URL} --ee --uuid --privileged true --usprequired \"Untrusted\" --uspregisterpaths \"Device.TrustedReader.\" --uspautomountipc \"USP_UDS_Authenticated\"" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  latest
  prpl-foundation/prplos/prplos/*/image-trusted-reader (glob)
  $ R "usp-cli -lj 'Device.TrustedReader.?' | sed '/^$/d'"
  [{"Device.TrustedReader.":{"ParamPath":"Device.DeviceInfo.SerialNumber","ParamValue":"","ErrorCode":1}}]

Uninstall the reader service:

  $ R "${S} && uninstall_ctr_and_check --uuid"
  [1]

Check that untrusted service cannot register model on USP bus when RegisterTrustPaths is empty:

  $ R "${S} && install_ctr --url ${PROVIDER_SERVICE_URL} --ee --uuid --privileged true --usprequired \"Full Access\" --uspautomountipc \"USP_UDS_Authenticated\"" > /dev/null
  $ R "${S} && get_container_info --uuid"
  1.0.0
  Active
  image-trusted-provider
  $ CTR_ID=$(R "${S} && get_container_parameter --uuid --param EUID")
  $ CTR_ENDPOINTID=$(R "ba-cli -l 'Cthulhu.Container.Instances.[ContainerId==\"${CTR_ID}\"].EndpointID?' | sed '/^$/d'")
  $ R "usp-cli -lj 'Device.USPServices.Trust.[EndpointID==\"${CTR_ENDPOINTID}\"].?' | sed '/^$/d'"
  [{}]
  $ R "usp-cli 'gsdm Device.' | grep TrustedProvider | sed '/^$/d'"

Update the RegisterTrustPaths parameter for service and check that untrusted service can register only allowed paths on USP bus:

  $ R "${S} && update_ctr --url ${PROVIDER_SERVICE_URL} --ee --uuid --privileged true --usprequired \"Full Access\" --uspregisterpaths \"Device.TrustedProvider1.\" --uspautomountipc \"USP_UDS_Authenticated\"" > /dev/null
  $ R "usp-cli -lj 'Device.USPServices.Trust.[EndpointID==\"${CTR_ENDPOINTID}\"].?' | sed '/^$/d'"
  [{"Device.USPServices.Trust.*.":{"TargetPaths":"Device.TrustedProvider1.","EndpointID":"*"}}] (glob)
  $ R "usp-cli 'gsdm Device.' | grep TrustedProvider | sed '/^$/d'"
  ... (Object      ) Device.TrustedProvider1.

Update the RegisterTrustPaths parameter with several paths and check that untrusted service can register only allowed paths on USP bus:

  $ R "${S} && update_ctr --url ${PROVIDER_SERVICE_URL} --ee --uuid --privileged true --usprequired \"Full Access\" --uspregisterpaths \"Device.TrustedProvider1.,Device.TrustedProvider2.\" --uspautomountipc \"USP_UDS_Authenticated\"" > /dev/null
  $ R "usp-cli -lj 'Device.USPServices.Trust.[EndpointID==\"${CTR_ENDPOINTID}\"].?' | sed '/^$/d'"
  [{"Device.USPServices.Trust.*.":{"TargetPaths":"Device.TrustedProvider1.,Device.TrustedProvider2.","EndpointID":"*"}}] (glob)
  $ R "usp-cli 'gsdm Device.' | grep TrustedProvider | sed '/^$/d'"
  ... (Object      ) Device.TrustedProvider1.
  ... (Object      ) Device.TrustedProvider2.

Uninstall the provider service:

  $ R "${S} && uninstall_ctr_and_check --uuid"
  [1]
  $ R logger -t cram Ended $TESTFILE

