Test LCM NumUSPEIDs parameter: install, update, uninstall and role-propagation scenarios.

  $ R() { ${CRAM_REMOTE_COMMAND:-} "$@" < /dev/null; }
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh"
  $ C ${TESTDIR}/script_functions.sh root@${TARGET_LAN_IP}:/tmp/script_functions.sh 2>/dev/null

  $ BOARD_ARCH=$(R "${S} && get_true_arch_name")
  $ SERVICE_URL="docker://registry.gitlab.com/prpl-foundation/prplos/prplos/${BOARD_ARCH}/image-lcmsampleapp:latest"

Setup: ensure Full Access role is available on the generic EE.

  $ R "${S} && set_ee_roles --roles 'Full Access'" > /dev/null

--- M4: InstallDU with NumUSPEIDs=-1 must be rejected (err_code 7002) ---

  $ R "${S} && install_ctr_no_wait --url ${SERVICE_URL} --uuid --ee --privileged true --usprequired 'Full Access' --network '{ShareParentNetwork=true}' --numusp -1 2>&1 | grep 'err_code\|not found'"
  *"err_code":7002* (glob)

  $ R "${S} && ba-cli -l -j 'SoftwareModules.DeploymentUnit.[ UUID == \"00000000-0000-5000-b000-000000000001\" ].UUID?' | jsonfilter -e '@[*].*.UUID'"
  [1]

--- M5: InstallDU with NumUSPEIDs=0 must be rejected (err_code 7002) ---

  $ R "${S} && install_ctr_no_wait --url ${SERVICE_URL} --uuid --ee --privileged true --usprequired 'Full Access' --network '{ShareParentNetwork=true}' --numusp 0 2>&1 | grep 'err_code'"
  *"err_code":7002* (glob)

  $ R "${S} && ba-cli -l -j 'SoftwareModules.DeploymentUnit.[ UUID == \"00000000-0000-5000-b000-000000000001\" ].UUID?' | jsonfilter -e '@[*].*.UUID'"
  [1]

--- M6: InstallDU with NumUSPEIDs=20 must be rejected (err_code 7002) ---

  $ R "${S} && install_ctr_no_wait --url ${SERVICE_URL} --uuid --ee --privileged true --usprequired 'Full Access' --network '{ShareParentNetwork=true}' --numusp 20 2>&1 | grep 'err_code'"
  *"err_code":7002* (glob)

  $ R "${S} && ba-cli -l -j 'SoftwareModules.DeploymentUnit.[ UUID == \"00000000-0000-5000-b000-000000000001\" ].UUID?' | jsonfilter -e '@[*].*.UUID'"
  [1]

--- M1: InstallDU BC mode (no NumUSPEIDs) → EU active, 1 USP endpoint injected ---

  $ R "${S} && install_ctr --url ${SERVICE_URL} --uuid --ee --privileged true --usprequired 'Full Access' --network '{ShareParentNetwork=true}' --waittime 120" > /dev/null

  $ R "${S} && get_container_parameter --uuid --param Status"
  Active

  $ R "${S} && execute_in_container --uuid --cmd 'env' | grep USP_ENDPOINT_ID"
  USP_ENDPOINT_ID=uuid::* (glob)

--- M16: UpdateDU BC→4 endpoints, EU stays active, NumUSPEIDs=4 ---

  $ R "${S} && update_ctr --url ${SERVICE_URL} --uuid --ee --privileged true --usprequired 'Full Access' --network '{ShareParentNetwork=true}' --numusp 4 --waittime 120" > /dev/null

  $ R "${S} && get_container_parameter --uuid --param NumUSPEIDs"
  4

--- M17: UpdateDU 4→4 (no NumUSPEIDs), No endpoint reduced, All EndpointID retained ---

  $ R "${S} && update_ctr --url ${SERVICE_URL} --uuid --ee --privileged true --usprequired 'Full Access' --network '{ShareParentNetwork=true}' --waittime 120" > /dev/null

  $ R "${S} && get_container_parameter --uuid --param NumUSPEIDs"
  4

  $ R "${S} && execute_in_container --uuid --cmd 'env' | grep USP_ENDPOINT_ID | sort"
  USP_ENDPOINT_ID=uuid::* (glob)
  USP_ENDPOINT_ID_1=uuid::* (glob)
  USP_ENDPOINT_ID_2=uuid::* (glob)
  USP_ENDPOINT_ID_3=uuid::* (glob)

Added to ensure that the Next testcase run smoothly.
  $ R "${S} && update_ctr --url ${SERVICE_URL} --uuid --ee --privileged true --usprequired 'Full Access' --network '{ShareParentNetwork=true}' --numusp 1 --waittime 120" > /dev/null

  $ R "${S} && get_container_parameter --uuid --param NumUSPEIDs"
  1

--- M7: UpdateDU BC→BC (no NumUSPEIDs), EndpointID preserved across update ---

  $ R "${S} && update_ctr --url ${SERVICE_URL} --uuid --ee --privileged true --usprequired 'Full Access' --network '{ShareParentNetwork=true}' --waittime 120" > /dev/null

  $ R "${S} && execute_in_container --uuid --cmd 'env' | grep USP_ENDPOINT_ID"
  USP_ENDPOINT_ID=uuid::* (glob)

--- M13: UninstallDU → DU, EU and image all removed ---

  $ R "${S} && uninstall_ctr_and_check --uuid --retaindata false"
  [1]

--- M2: InstallDU with NumUSPEIDs=16 (max), EU active ---

  $ R "${S} && install_ctr --url ${SERVICE_URL} --uuid --ee --privileged true --usprequired 'Full Access' --network '{ShareParentNetwork=true}' --numusp 16 --waittime 120" > /dev/null

  $ R "${S} && get_container_parameter --uuid --param NumUSPEIDs"
  16

--- M18: UpdateDU 16→16 (same count), endpoints preserved ---

  $ R "${S} && update_ctr --url ${SERVICE_URL} --uuid --ee --privileged true --usprequired 'Full Access' --network '{ShareParentNetwork=true}' --numusp 16 --waittime 120" > /dev/null

  $ R "${S} && get_container_parameter --uuid --param NumUSPEIDs"
  16

--- M19: Query non-existent EU instance returns no data ---

  $ R "ba-cli -l -j 'SoftwareModules.ExecutionUnit.9999.NumUSPEIDs?' 2>&1 | grep -v '^$'"
  ERROR: SoftwareModules.ExecutionUnit.9999.NumUSPEIDs not found.

Cleanup M2/M18/M19 session:

  $ R "${S} && uninstall_ctr_and_check --uuid --retaindata false"
  [1]

--- M3: InstallDU with NumUSPEIDs=1 (min valid), EU active, 1 endpoint ---

  $ R "${S} && install_ctr --url ${SERVICE_URL} --uuid --ee --privileged true --usprequired 'Full Access' --network '{ShareParentNetwork=true}' --numusp 1 --waittime 120" > /dev/null

  $ R "${S} && get_container_parameter --uuid --param NumUSPEIDs"
  1

  $ R "${S} && execute_in_container --uuid --cmd 'env' | grep USP_ENDPOINT_ID"
  USP_ENDPOINT_ID=uuid::* (glob)

--- M8: UpdateDU 1→4, NumUSPEIDs increases to 4 ---

  $ R "${S} && update_ctr --url ${SERVICE_URL} --uuid --ee --privileged true --usprequired 'Full Access' --network '{ShareParentNetwork=true}' --numusp 4 --waittime 120" > /dev/null

  $ R "${S} && get_container_parameter --uuid --param NumUSPEIDs"
  4

--- M9: UpdateDU 4→2, NumUSPEIDs decreases to 2 ---

  $ R "${S} && update_ctr --url ${SERVICE_URL} --uuid --ee --privileged true --usprequired 'Full Access' --network '{ShareParentNetwork=true}' --numusp 2 --waittime 120" > /dev/null

  $ R "${S} && get_container_parameter --uuid --param NumUSPEIDs"
  2

--- M10: UpdateDU with NumUSPEIDs=-1 rejected (count stays at 2) ---

  $ R "${S} && update_ctr --url ${SERVICE_URL} --uuid --ee --privileged true --usprequired 'Full Access' --network '{ShareParentNetwork=true}' --numusp -1 2>&1 | grep 'err_code'"
  *"err_code":7002* (glob)

  $ R "${S} && get_container_parameter --uuid --param NumUSPEIDs"
  2

--- M11: UpdateDU with NumUSPEIDs=0 rejected (count stays at 2) ---

  $ R "${S} && update_ctr_no_wait --url ${SERVICE_URL} --uuid --ee --privileged true --usprequired 'Full Access' --network '{ShareParentNetwork=true}' --numusp 0 2>&1 | grep 'err_code'"
  *"err_code":7002* (glob)

  $ R "${S} && get_container_parameter --uuid --param NumUSPEIDs"
  2

--- M12: UpdateDU with NumUSPEIDs=20 rejected (count stays at 2) ---

  $ R "${S} && update_ctr_no_wait --url ${SERVICE_URL} --uuid --ee --privileged true --usprequired 'Full Access' --network '{ShareParentNetwork=true}' --numusp 20 2>&1 | grep 'err_code'"
  *"err_code":7002* (glob)

  $ R "${S} && get_container_parameter --uuid --param NumUSPEIDs"
  2

--- M14: RequiredUserRoles reflected in EU data model ---

  $ R "${S} && add_user_role --rolename Untrusted --capabilities \"CAP_NET_RAW\"" > /dev/null

  $ R "${S} && set_ee_roles --roles 'Full Access' --userroles 'Untrusted'" > /dev/null

  $ R "${S} && update_ctr --url ${SERVICE_URL} --uuid --ee --privileged true --usprequired 'Full Access' --userroles 'Untrusted' --network '{ShareParentNetwork=true}' --numusp 2 --waittime 120" > /dev/null

  $ R "${S} && get_container_parameter --uuid --param RequiredUserRoles"
  Device.Users.Role.[RoleName=="Untrusted"]

  $ R "${S} && remove_user_role --rolename Untrusted" > /dev/null

--- M15: InstallDU with RequiredRoles='Full Access' succeeds ---

  $ R "${S} && uninstall_ctr_and_check --uuid --retaindata false"
  [1]

  $ R "${S} && set_ee_roles --roles 'Full Access'" > /dev/null

  $ R "${S} && install_ctr --url ${SERVICE_URL} --uuid --ee --privileged true --usprequired 'Full Access' --network '{ShareParentNetwork=true}' --numusp 2 --waittime 120" > /dev/null

  $ R "${S} && get_container_parameter --uuid --param Status"
  Active

Cleanup M3/M8-M15 session:

  $ R "${S} && set_ee_roles --roles 'Full Access'" > /dev/null
  $ R "${S} && uninstall_ctr_and_check --uuid --retaindata false"
  [1]

--- M20: InstallDU obuspa controller with NumUSPEIDs=4, RequiredRoles=Full Access ---

  $ R "${S} && install_ctr --url ${SERVICE_URL} --uuid --ee --privileged true --usprequired 'Full Access' --uspregisterpaths 'Device.LCMSampleApp.' --network '{ShareParentNetwork=true}' --numusp 4 --waittime 120" > /dev/null

  $ R "${S} && get_container_parameter --uuid --param NumUSPEIDs"
  4

Allow USP endpoint/controller registrations to settle before checking role/trust state:

  $ sleep 5

  $ R "${S} && check_endpoint_role --uuid"
  Full Access
  Full Access
  Full Access
  Full Access

  $ R "${S} && check_endpoint_permission --uuid"
  rw-n
  rw-n
  rw-n
  rw-n

--- M21: InstallDU with RequiredRoles=Untrusted, protected USP operation denied from all endpoints ---

  $ R "${S} && uninstall_ctr_and_check --uuid --retaindata false"
  [1]

  $ R "${S} && add_user_role --rolename Untrusted --capabilities \"CAP_NET_RAW\"" > /dev/null

  $ R "${S} && set_ee_roles --roles 'Full Access,Untrusted'" > /dev/null

  $ R "obuspa -c set Device.LocalAgent.ControllerTrust.Role.2.Name Untrusted" > /dev/null

  $ R "${S} && install_ctr --url ${SERVICE_URL} --uuid --ee --privileged true --usprequired 'Untrusted' --uspregisterpaths 'Device.LCMSampleApp.' --network '{ShareParentNetwork=true}' --numusp 4 --waittime 120" > /dev/null

  $ R "${S} && get_container_parameter --uuid --param NumUSPEIDs"
  4

  $ sleep 5

  $ R "${S} && check_endpoint_role --uuid"
  Untrusted
  Untrusted
  Untrusted
  Untrusted

  $ R "${S} && check_endpoint_permission --uuid"
  ----
  ----
  ----
  ----

--- M22: UpdateDU from Untrusted to Full Access, all endpoints gain access ---

  $ R "${S} && update_ctr --url ${SERVICE_URL} --uuid --ee --privileged true --usprequired 'Full Access' --uspregisterpaths 'Device.LCMSampleApp.' --network '{ShareParentNetwork=true}' --numusp 4 --waittime 120" > /dev/null

  $ R "${S} && get_container_parameter --uuid --param NumUSPEIDs"
  4

  $ sleep 5

  $ R "${S} && check_endpoint_role --uuid"
  Full Access
  Full Access
  Full Access
  Full Access

  $ R "${S} && check_endpoint_permission --uuid"
  rw-n
  rw-n
  rw-n
  rw-n

--- M23: UpdateDU from Full Access to Untrusted, all endpoints lose access ---

  $ R "${S} && update_ctr --url ${SERVICE_URL} --uuid --ee --privileged true --usprequired 'Untrusted' --uspregisterpaths 'Device.LCMSampleApp.' --network '{ShareParentNetwork=true}' --numusp 4 --waittime 120" > /dev/null

  $ R "${S} && get_container_parameter --uuid --param NumUSPEIDs"
  4

  $ sleep 5

  $ R "${S} && check_endpoint_role --uuid"
  Untrusted
  Untrusted
  Untrusted
  Untrusted

  $ R "${S} && check_endpoint_permission --uuid"
  ----
  ----
  ----
  ----

--- M24: Scale endpoint count from 4->2 while using Full Access, remaining endpoints inherit Full Access ---

  $ R "${S} && update_ctr --url ${SERVICE_URL} --uuid --ee --privileged true --usprequired 'Full Access' --uspregisterpaths 'Device.LCMSampleApp.' --network '{ShareParentNetwork=true}' --numusp 2 --waittime 120" > /dev/null

  $ R "${S} && get_container_parameter --uuid --param NumUSPEIDs"
  2

  $ sleep 5

  $ R "${S} && check_endpoint_role --uuid"
  Full Access
  Full Access

  $ R "${S} && check_endpoint_permission --uuid"
  rw-n
  rw-n

--- M25: Scale endpoint count from 2->4 while using Untrusted, all endpoints retain denied permissions ---

  $ R "${S} && update_ctr --url ${SERVICE_URL} --uuid --ee --privileged true --usprequired 'Untrusted' --uspregisterpaths 'Device.LCMSampleApp.' --network '{ShareParentNetwork=true}' --numusp 4 --waittime 120" > /dev/null

  $ R "${S} && get_container_parameter --uuid --param NumUSPEIDs"
  4

  $ sleep 5

  $ R "${S} && check_endpoint_role --uuid"
  Untrusted
  Untrusted
  Untrusted
  Untrusted

  $ R "${S} && check_endpoint_permission --uuid"
  ----
  ----
  ----
  ----

  $ R "${S} && uninstall_ctr_and_check --uuid --retaindata false"
  [1]

  $ R "${S} && remove_user_role --rolename Untrusted" > /dev/null

  $ R "${S} && set_ee_roles --roles 'Full Access'" > /dev/null
