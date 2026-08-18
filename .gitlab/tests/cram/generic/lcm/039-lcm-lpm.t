## Setup test configuration
Set-up the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh"
  $ C ${TESTDIR}/script_functions.sh root@${TARGET_LAN_IP}:/tmp/script_functions.sh 2>/dev/null
  $ R "mkdir -p /etc/amx/cthulhu/onboard"

### INSTALL onboarded containers ###
  $ R "${S} && install_ctr --url_arch 3_16_alpine_copy --ee --uuid --privileged true"
  
  SoftwareModules.InstallDU() returned
  ["",{"err_code":0,"err_msg":""}]
  $ R "${S} && install_ctr --version prplos-v2 --ee --uuid \"00000000-0000-5000-b000-000000000006\" --privileged true"
  
  SoftwareModules.InstallDU() returned
  ["",{"err_code":0,"err_msg":""}]
  $ R "rm -rf /usr/rlyeh_save"
  $ R "cp -R /lcm/rlyeh /usr/rlyeh_save"
  $ R "ba-cli 'SoftwareModules.DeploymentUnit.*.Uninstall()'"
  * SoftwareModules.DeploymentUnit.*.Uninstall() (glob)
  SoftwareModules.DeploymentUnit.*.Uninstall() returned (glob)
  [
      ""
  ]
  SoftwareModules.DeploymentUnit.*.Uninstall() returned (glob)
  [
      ""
  ]
  $ R "/etc/init.d/cthulhu stop"
  $ R "/etc/init.d/rlyeh stop"
  $ R "/etc/init.d/timingila stop"

wait for cthulhu to terminate all containers and itself, before clear its data

  $ R "while [ -n \"$(pidof cthulhu)\" ]; do sleep 1; done"
  $ R "rm -rf /lcm/*"
  $ R "rm -rf /etc/config/cthulhu/*"
  $ R "find /usr/rlyeh_save" | sort
  /usr/rlyeh_save
  /usr/rlyeh_save/blobs
  /usr/rlyeh_save/blobs/sha256
  /usr/rlyeh_save/blobs/sha256/* (glob)
  /usr/rlyeh_save/blobs/sha256/* (glob)
  /usr/rlyeh_save/blobs/sha256/* (glob)
  /usr/rlyeh_save/blobs/sha256/* (glob)
  /usr/rlyeh_save/blobs/sha256/* (glob)
  /usr/rlyeh_save/blobs/sha256/* (glob)
  /usr/rlyeh_save/images
  /usr/rlyeh_save/images/prpl-foundation
  /usr/rlyeh_save/images/prpl-foundation/prplos
  /usr/rlyeh_save/images/prpl-foundation/prplos/prplos
  /usr/rlyeh_save/images/prpl-foundation/prplos/prplos/lcm_tests
  /usr/rlyeh_save/images/prpl-foundation/prplos/prplos/lcm_tests/*_3_16_alpine_copy (glob)
  /usr/rlyeh_save/images/prpl-foundation/prplos/prplos/lcm_tests/*_3_16_alpine_copy/index.json (glob)
  /usr/rlyeh_save/images/prpl-foundation/prplos/prplos/lcm_tests/*_3_16_alpine_copy/oci-layout (glob)
  /usr/rlyeh_save/images/prpl-foundation/prplos/prplos/prplos
  /usr/rlyeh_save/images/prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)
  /usr/rlyeh_save/images/prpl-foundation/prplos/prplos/prplos/lcm-test-*/index.json (glob)
  /usr/rlyeh_save/images/prpl-foundation/prplos/prplos/prplos/lcm-test-*/oci-layout (glob)
  $ R "find /lcm/"
  /lcm/

### restart lcm ###

  $ R "/etc/init.d/rlyeh start"
  $ sleep 1
  $ R "/etc/init.d/cthulhu start"
  $ R "/etc/init.d/timingila start"
  $ R "sleep 1"
  $ R "ba-cli -l 'Device.SoftwareModules.DeploymentUnitNumberOfEntries?'"
  
  0
  $ R "ba-cli -l 'Device.SoftwareModules.ExecEnvNumberOfEntries?'"
  
  1
  $ R "ba-cli -l 'Device.SoftwareModules.ExecutionUnitNumberOfEntries?'"
  
  0
  $ R "ba-cli 'Device.SoftwareModules.ExecEnv.1.Status?'"
  ? Device.SoftwareModules.ExecEnv.1.Status? (glob)
  Device.SoftwareModules.ExecEnv.1.Status="Up"
  $ R "lxc-ls -f"

### INSTALL current containers ###

  $ R "${S} && install_ctr --url_arch 3_16_alpine --ee --uuid --privileged true --moduleversion 3.16.0"
  
  SoftwareModules.InstallDU() returned
  ["",{"err_code":0,"err_msg":""}]
  $ R "${S} && install_ctr --url_arch 3_14_alpine --ee --uuid \"00000000-0000-5000-b000-000000000002\" --privileged true --moduleversion 1.0.0 --envvar '[{Key = \"EnvVar1\", Value = \"VarValue1\"}, {Key = \"EnvVar2\" , Value = \"VarValue2\"}]' "
  
  SoftwareModules.InstallDU() returned
  ["",{"err_code":0,"err_msg":""}]
  $ R "${S} && install_ctr --url_arch 3_16_alpine_libcap_shadow --ee --uuid \"00000000-0000-5000-b000-000000000004\" --privileged true --moduleversion 0.1.0"
  
  SoftwareModules.InstallDU() returned
  ["",{"err_code":0,"err_msg":""}]
  $ R "sleep 3"
  $ R "lxc-ls -f"
  NAME                                 STATE   AUTOSTART GROUPS IPV4 IPV6 UNPRIVILEGED 
  917362a3-86e8-5332-bcfd-a4223f0e65e6 RUNNING 0         -      -    -    false        
  9904df79-0144-514d-8028-98a5eaffc674 RUNNING 0         -      -    -    false        
  e61c304b-b5e4-5fdb-9836-60001e90a127 RUNNING 0         -      -    -    false        
  $ R "ba-cli 'Device.SoftwareModules.DeploymentUnit.*.Status?'"
  * Device.SoftwareModules.DeploymentUnit.*.Status? (glob)
  Device.SoftwareModules.DeploymentUnit.*.Status="Installed" (glob)
  Device.SoftwareModules.DeploymentUnit.*.Status="Installed" (glob)
  Device.SoftwareModules.DeploymentUnit.*.Status="Installed" (glob)
  $ R "ba-cli 'Device.SoftwareModules.ExecutionUnit.*.Status?'"
  * Device.SoftwareModules.ExecutionUnit.*.Status? (glob)
  Device.SoftwareModules.ExecutionUnit.*.Status="Active" (glob)
  Device.SoftwareModules.ExecutionUnit.*.Status="Active" (glob)
  Device.SoftwareModules.ExecutionUnit.*.Status="Active" (glob)

### perform backup ###

  $ R "ba-cli 'Device.X_PRPLWARE-COM_PersistentConfiguration.Service.cthulhu_Cthulhu.ImportStatus=\"None\"'"
  * Device.X_PRPLWARE-COM_PersistentConfiguration.Service.cthulhu_Cthulhu.ImportStatus="None" (glob)
  Device.X_PRPLWARE-COM_PersistentConfiguration.Service.*. (glob)
  Device.X_PRPLWARE-COM_PersistentConfiguration.Service.*.ImportStatus="None" (glob)
  $ R "ba-cli 'Device.X_PRPLWARE-COM_PersistentConfiguration.Service.cthulhu_Cthulhu.ExportStatus=\"None\"'"
  * Device.X_PRPLWARE-COM_PersistentConfiguration.Service.cthulhu_Cthulhu.ExportStatus="None" (glob)
  Device.X_PRPLWARE-COM_PersistentConfiguration.Service.*. (glob)
  Device.X_PRPLWARE-COM_PersistentConfiguration.Service.*.ExportStatus="None" (glob)
  $ R "ba-cli 'Device.X_PRPLWARE-COM_PersistentConfiguration.Backup()'"
  * Device.X_PRPLWARE-COM_PersistentConfiguration.Backup() (glob)
  Device.X_PRPLWARE-COM_PersistentConfiguration.Backup() returned
  [
      ""
  ]
### terminate LCM and remove all boot-persistent data that is not upgrade-persistent. ###
### Stopping Cthulhu by sending a signal to the main process, as the init script kills the process (forcefully) after a timeout. The stopping of the containers is done in parallel, thus depending on the number of containers to stop and the configured graceful shutdown.

  $ R "ls -l /cfg/pcm/cthulhu*"
  -rw-r--r--    1 root * /cfg/pcm/cthulhu_Cthulhu.json (glob)
  $ R "kill \$(cat /var/run/cthulhu.pid)"
  $ R "/etc/init.d/rlyeh stop"
  $ R "/etc/init.d/timingila stop"

wait for cthulhu to terminate all containers and itself, before clear its data

  $ R "while [ -n \"\$(pidof cthulhu)\" ]; do sleep 1; done"
  $ R "rm -rf /etc/config/cthulhu/*"
  $ R "rm -rf /etc/config/lxc/*"
  $ R "rm -rf /etc/config/rlyeh/*"

### install policy and pre-embedded container descriptors ###

  $ R 'cat > /etc/amx/cthulhu/extensions/plugin-lpm/policy.json <<EOF
  > {
  >     "containerpolicy": {
  >         "global": {
  >             "onNew": "INSTALL",
  >             "onExisting": "IGNORE",
  >             "onExistingUpgrade": "UPDATE",
  >             "onExistingDowngrade": "IGNORE",
  >             "onUnknown": "IGNORE"
  >         },
  >         "applications": [
  >             {
  >                 "uuid": "00000000-0000-5000-b000-000000000002",
  >                 "description": "alpine 3.16",
  >                 "onUnknown": "UNINSTALL",
  >                 "onExisting": "UNINSTALL"
  >             }
  >         ]
  >     }
  > }
  > EOF'

  $ R "${S} && add_containers_descriptors"

### put the pre-embedded container images in the right place and verify ###

  $ R "rm -rf /usr/rlyeh"
  $ R "mv /usr/rlyeh_save /usr/rlyeh"
  $ R "ls -l /etc/amx/cthulhu/onboard/"
  -rw-r--r--    1 root * 70a9bf70-9df9-5221-b51b-184c74d022e3.json (glob)
  -rw-r--r--    1 root * 917362a3-86e8-5332-bcfd-a4223f0e65e6.json (glob)
  $ R "ls -l /etc/amx/cthulhu/extensions/plugin-lpm/policy.json"
  -rw-r--r--    1 root * /etc/amx/cthulhu/extensions/plugin-lpm/policy.json (glob)
  $ R "ls -l /usr/rlyeh/"
  drwxr-xr-x    3 root * blobs (glob)
  drwxr-xr-x    3 root * images (glob)

### Simulate reboot after upgrade ###

  $ R "/etc/init.d/rlyeh start"
  $ sleep 1
  $ R "/etc/init.d/cthulhu start"
  $ R "/etc/init.d/timingila start"
  $ while ! R ba-cli 'SoftwareModules.ExecEnv.? | grep "SoftwareModules\.ExecEnv\.1\." | head -n 1 | grep "SoftwareModules\.ExecEnv\.1\."' ; do sleep 1 ; done
  SoftwareModules.ExecEnv.1.
  $ sleep 10

## check state after the simulated reboot

  $ R "ba-cli 'Device.SoftwareModules.DeploymentUnit.[UUID == \"00000000-0000-5000-b000-000000000001\"].ModuleVersion?'"
  ? Device.SoftwareModules.DeploymentUnit.[UUID == "00000000-0000-5000-b000-000000000001"].ModuleVersion? (glob)
  Device.SoftwareModules.DeploymentUnit.*.ModuleVersion="3.16.1" (glob)
  $ R "ba-cli 'Device.SoftwareModules.DeploymentUnit.[UUID == \"00000000-0000-5000-b000-000000000002\"].?'"
  ? Device.SoftwareModules.DeploymentUnit.[UUID == "00000000-0000-5000-b000-000000000002"].? (glob)
  No data found
  $ R "ba-cli 'Device.SoftwareModules.DeploymentUnit.[UUID == \"00000000-0000-5000-b000-000000000004\"].Status?'"
  ? Device.SoftwareModules.DeploymentUnit.[UUID == "00000000-0000-5000-b000-000000000004"].Status? (glob)
  Device.SoftwareModules.DeploymentUnit.*.Status="Installed" (glob)
  $ R "ba-cli 'Device.SoftwareModules.DeploymentUnit.[UUID == \"00000000-0000-5000-b000-000000000006\"].Status?'"
  ? Device.SoftwareModules.DeploymentUnit.[UUID == "00000000-0000-5000-b000-000000000006"].Status? (glob)
  Device.SoftwareModules.DeploymentUnit.*.Status="Installed" (glob)
  $ R "ba-cli 'Device.SoftwareModules.ExecutionUnit.*.Status?'"
  ? Device.SoftwareModules.ExecutionUnit.*.Status? (glob)
  Device.SoftwareModules.ExecutionUnit.*.Status="Active" (glob)
  Device.SoftwareModules.ExecutionUnit.*.Status="Active" (glob)
  Device.SoftwareModules.ExecutionUnit.*.Status="Active" (glob)
  $ R "ba-cli -l 'Device.SoftwareModules.LocalManagement.ActionNumberOfEntries?'"
  
  3
  $ R "ba-cli 'Device.SoftwareModules.LocalManagement.Action.[UUID == \"00000000-0000-5000-b000-000000000006\"].?'"
  * Device.SoftwareModules.LocalManagement.Action.[UUID == "00000000-0000-5000-b000-000000000006"].? (glob)
  Device.SoftwareModules.LocalManagement.Action.*. (glob)
  Device.SoftwareModules.LocalManagement.Action.*.Action="Install" (glob)
  Device.SoftwareModules.LocalManagement.Action.*.Alias="cpe-00000000-0000-5000-b000-000000000006" (glob)
  Device.SoftwareModules.LocalManagement.Action.*.CurrentModuleVersion="2.0.0" (glob)
  Device.SoftwareModules.LocalManagement.Action.*.ExecEnvName="generic" (glob)
  Device.SoftwareModules.LocalManagement.Action.*.FaultMessage="" (glob)
  Device.SoftwareModules.LocalManagement.Action.*.PreviousModuleVersion="<none>" (glob)
  Device.SoftwareModules.LocalManagement.Action.*.Status="Success" (glob)
  Device.SoftwareModules.LocalManagement.Action.*.UUID="00000000-0000-5000-b000-000000000006" (glob)

  $ R "ba-cli 'Device.SoftwareModules.LocalManagement.Action.[UUID == \"00000000-0000-5000-b000-000000000001\"].?'"
  * Device.SoftwareModules.LocalManagement.Action.[UUID == "00000000-0000-5000-b000-000000000001"].? (glob)
  Device.SoftwareModules.LocalManagement.Action.*. (glob)
  Device.SoftwareModules.LocalManagement.Action.*.Action="Update" (glob)
  Device.SoftwareModules.LocalManagement.Action.*.Alias="cpe-00000000-0000-5000-b000-000000000001" (glob)
  Device.SoftwareModules.LocalManagement.Action.*.CurrentModuleVersion="3.16.1" (glob)
  Device.SoftwareModules.LocalManagement.Action.*.ExecEnvName="generic" (glob)
  Device.SoftwareModules.LocalManagement.Action.*.FaultMessage="" (glob)
  Device.SoftwareModules.LocalManagement.Action.*.PreviousModuleVersion="3.16.0" (glob)
  Device.SoftwareModules.LocalManagement.Action.*.Status="Success" (glob)
  Device.SoftwareModules.LocalManagement.Action.*.UUID="00000000-0000-5000-b000-000000000001" (glob)

  $ R "ba-cli 'Device.SoftwareModules.LocalManagement.Action.[UUID == \"00000000-0000-5000-b000-000000000002\"].?'"
  * Device.SoftwareModules.LocalManagement.Action.[UUID == "00000000-0000-5000-b000-000000000002"].? (glob)
  Device.SoftwareModules.LocalManagement.Action.*. (glob)
  Device.SoftwareModules.LocalManagement.Action.*.Action="Uninstall" (glob)
  Device.SoftwareModules.LocalManagement.Action.*.Alias="cpe-00000000-0000-5000-b000-000000000002" (glob)
  Device.SoftwareModules.LocalManagement.Action.*.CurrentModuleVersion="<none>" (glob)
  Device.SoftwareModules.LocalManagement.Action.*.ExecEnvName="<none>" (glob)
  Device.SoftwareModules.LocalManagement.Action.*.FaultMessage="" (glob)
  Device.SoftwareModules.LocalManagement.Action.*.PreviousModuleVersion="1.0.0" (glob)
  Device.SoftwareModules.LocalManagement.Action.*.Status="Success" (glob)
  Device.SoftwareModules.LocalManagement.Action.*.UUID="00000000-0000-5000-b000-000000000002" (glob)
## clean up all containers ##

  $ R "ba-cli 'SoftwareModules.DeploymentUnit.*.Uninstall()'"
  * SoftwareModules.DeploymentUnit.*.Uninstall() (glob)
  SoftwareModules.DeploymentUnit.*.Uninstall() returned (glob)
  [
      ""
  ]
  SoftwareModules.DeploymentUnit.*.Uninstall() returned (glob)
  [
      ""
  ]
  SoftwareModules.DeploymentUnit.*.Uninstall() returned (glob)
  [
      ""
  ]


### Cleanup LPM test env:

  $ R "${S} && cleanup_lpm_test"
  $ R "rm -f /tmp/script_functions.sh"
