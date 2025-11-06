Setup the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ S=". /tmp/script_functions.sh"
  $ scp ${TESTDIR}/../lcm/script_functions.sh root@${TARGET_LAN_IP}:/tmp/script_functions.sh
  $ scp ${CI_PROJECT_DIR}/${DUT_ARCH_PACKAGES_PATH}/feed_prplos/data-model-mapper*.ipk "root@${TARGET_LAN_IP}:/tmp/"
  $ R "opkg install -V0 --force-reinstall /tmp/data-model-mapper*.ipk"
  Usage : /etc/init.d/data-model-mapper [start|boot|debuginfo|stop|shutdown|restart]

Compare SoftwareModules and SoftwareModules via data-model-mapper proxy:

  $ R "ba-cli 'SoftwareModules.?'" > /tmp/dmm_test_software_modules_orig.txt
  $ R "ba-cli 'Device.X_PRPLWARE-COM_SoftwareModules.?' | grep -v 'Cmd\.' | sed 's/Device.X_PRPLWARE-COM_//'" > /tmp/dmm_test_software_modules_proxy.txt
  $ diff /tmp/dmm_test_software_modules_orig.txt /tmp/dmm_test_software_modules_proxy.txt

Check command tree is available:

  $ R "ba-cli 'Device.X_PRPLWARE-COM_SoftwareModules.?'" | grep 'Cmd\.'
  Device.X_PRPLWARE-COM_SoftwareModules.AddExecEnvCmd.
  Device.X_PRPLWARE-COM_SoftwareModules.AddExecEnvCmd.ErrorCode=""
  Device.X_PRPLWARE-COM_SoftwareModules.AddExecEnvCmd.ErrorMessage=""
  Device.X_PRPLWARE-COM_SoftwareModules.AddExecEnvCmd.State="None"
  Device.X_PRPLWARE-COM_SoftwareModules.AddExecEnvCmd.Input.
  Device.X_PRPLWARE-COM_SoftwareModules.AddExecEnvCmd.Input.AllocatedCPUPercent=-1
  Device.X_PRPLWARE-COM_SoftwareModules.AddExecEnvCmd.Input.AllocatedDiskSpace=-1
  Device.X_PRPLWARE-COM_SoftwareModules.AddExecEnvCmd.Input.AllocatedMemory=-1
  Device.X_PRPLWARE-COM_SoftwareModules.AddExecEnvCmd.Input.AvailableRoles=""
  Device.X_PRPLWARE-COM_SoftwareModules.AddExecEnvCmd.Input.InitialRunLevel=0
  Device.X_PRPLWARE-COM_SoftwareModules.AddExecEnvCmd.Input.MaxBandwidthDownstream=0
  Device.X_PRPLWARE-COM_SoftwareModules.AddExecEnvCmd.Input.MaxBandwidthUpstream=0
  Device.X_PRPLWARE-COM_SoftwareModules.AddExecEnvCmd.Input.Name=""
  Device.X_PRPLWARE-COM_SoftwareModules.AddExecEnvCmd.Input.ParentExecEnv=""
  Device.X_PRPLWARE-COM_SoftwareModules.AddExecEnvCmd.Input.Vendor=""
  Device.X_PRPLWARE-COM_SoftwareModules.AddExecEnvCmd.Input.Version=""
  Device.X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUninstallCmd.
  Device.X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUninstallCmd.CmdPath="Device.SoftwareModules.DeploymentUnit.\{i\}"
  Device.X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUninstallCmd.ErrorCode=""
  Device.X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUninstallCmd.ErrorMessage=""
  Device.X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUninstallCmd.State="None"
  Device.X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUninstallCmd.Input.
  Device.X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUninstallCmd.Input.RetainData=0
  Device.X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUpdateCmd.
  Device.X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUpdateCmd.CmdPath="Device.SoftwareModules.DeploymentUnit.\{i\}"
  Device.X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUpdateCmd.ErrorCode=""
  Device.X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUpdateCmd.ErrorMessage=""
  Device.X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUpdateCmd.State="None"
  Device.X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUpdateCmd.Input.
  Device.X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUpdateCmd.Input.AllocatedCPUPercent=-1
  Device.X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUpdateCmd.Input.AllocatedDiskSpace=-1
  Device.X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUpdateCmd.Input.AllocatedMemory=-1
  Device.X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUpdateCmd.Input.ModuleVersion=""
  Device.X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUpdateCmd.Input.OptionalRoles=""
  Device.X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUpdateCmd.Input.Password=""
  Device.X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUpdateCmd.Input.RequiredRoles=""
  Device.X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUpdateCmd.Input.RetainData=0
  Device.X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUpdateCmd.Input.URL=""
  Device.X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUpdateCmd.Input.Username=""
  Device.X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUpdateCmd.Input.NetworkConfig.
  Device.X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUpdateCmd.Input.NetworkConfig.AccessInterfaces=""
  Device.X_PRPLWARE-COM_SoftwareModules.ExecEnvDeleteCmd.
  Device.X_PRPLWARE-COM_SoftwareModules.ExecEnvDeleteCmd.CmdPath="Device.SoftwareModules.ExecEnv.\{i\}"
  Device.X_PRPLWARE-COM_SoftwareModules.ExecEnvDeleteCmd.ErrorCode=""
  Device.X_PRPLWARE-COM_SoftwareModules.ExecEnvDeleteCmd.ErrorMessage=""
  Device.X_PRPLWARE-COM_SoftwareModules.ExecEnvDeleteCmd.State="None"
  Device.X_PRPLWARE-COM_SoftwareModules.ExecEnvRestartCmd.
  Device.X_PRPLWARE-COM_SoftwareModules.ExecEnvRestartCmd.CmdPath="Device.SoftwareModules.ExecEnv.\{i\}"
  Device.X_PRPLWARE-COM_SoftwareModules.ExecEnvRestartCmd.ErrorCode=""
  Device.X_PRPLWARE-COM_SoftwareModules.ExecEnvRestartCmd.ErrorMessage=""
  Device.X_PRPLWARE-COM_SoftwareModules.ExecEnvRestartCmd.State="None"
  Device.X_PRPLWARE-COM_SoftwareModules.ExecEnvRestartCmd.Input.
  Device.X_PRPLWARE-COM_SoftwareModules.ExecEnvRestartCmd.Input.RestartReason=""
  Device.X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.
  Device.X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.ErrorCode=""
  Device.X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.ErrorMessage=""
  Device.X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.State="None"
  Device.X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.
  Device.X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.AllocatedCPUPercent=-1
  Device.X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.AllocatedDiskSpace=-1
  Device.X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.AllocatedMemory=-1
  Device.X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.AutoStart=0
  Device.X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.ExecutionEnvRef=""
  Device.X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.ModuleVersion=""
  Device.X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.OptionalRoles=""
  Device.X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.Password=""
  Device.X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.Privileged=1
  Device.X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.RequiredRoles=""
  Device.X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.Signature=""
  Device.X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.URL=""
  Device.X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.UUID=""
  Device.X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.Username=""
  Device.X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.NetworkConfig.
  Device.X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.NetworkConfig.AccessInterfaces=""
  Device.X_PRPLWARE-COM_SoftwareModules.ModifyAvailableRolesCmd.
  Device.X_PRPLWARE-COM_SoftwareModules.ModifyAvailableRolesCmd.CmdPath="Device.SoftwareModules.ExecEnv.\{i\}"
  Device.X_PRPLWARE-COM_SoftwareModules.ModifyAvailableRolesCmd.ErrorCode=""
  Device.X_PRPLWARE-COM_SoftwareModules.ModifyAvailableRolesCmd.ErrorMessage=""
  Device.X_PRPLWARE-COM_SoftwareModules.ModifyAvailableRolesCmd.State="None"
  Device.X_PRPLWARE-COM_SoftwareModules.ModifyAvailableRolesCmd.Input.
  Device.X_PRPLWARE-COM_SoftwareModules.ModifyAvailableRolesCmd.Input.AvailableRoles=""
  Device.X_PRPLWARE-COM_SoftwareModules.ModifyConstraintsCmd.
  Device.X_PRPLWARE-COM_SoftwareModules.ModifyConstraintsCmd.CmdPath="Device.SoftwareModules.ExecEnv.\{i\}"
  Device.X_PRPLWARE-COM_SoftwareModules.ModifyConstraintsCmd.ErrorCode=""
  Device.X_PRPLWARE-COM_SoftwareModules.ModifyConstraintsCmd.ErrorMessage=""
  Device.X_PRPLWARE-COM_SoftwareModules.ModifyConstraintsCmd.State="None"
  Device.X_PRPLWARE-COM_SoftwareModules.ModifyConstraintsCmd.Input.
  Device.X_PRPLWARE-COM_SoftwareModules.ModifyConstraintsCmd.Input.AllocatedCPUPercent=-1
  Device.X_PRPLWARE-COM_SoftwareModules.ModifyConstraintsCmd.Input.AllocatedDiskSpace=-1
  Device.X_PRPLWARE-COM_SoftwareModules.ModifyConstraintsCmd.Input.AllocatedMemory=-1
  Device.X_PRPLWARE-COM_SoftwareModules.ModifyConstraintsCmd.Input.Force=0
  Device.X_PRPLWARE-COM_SoftwareModules.ModifyNetworkConfigCmd.
  Device.X_PRPLWARE-COM_SoftwareModules.ModifyNetworkConfigCmd.CmdPath="Device.SoftwareModules.ExecutionUnit.\{i\}"
  Device.X_PRPLWARE-COM_SoftwareModules.ModifyNetworkConfigCmd.ErrorCode=""
  Device.X_PRPLWARE-COM_SoftwareModules.ModifyNetworkConfigCmd.ErrorMessage=""
  Device.X_PRPLWARE-COM_SoftwareModules.ModifyNetworkConfigCmd.State="None"
  Device.X_PRPLWARE-COM_SoftwareModules.ModifyNetworkConfigCmd.Input.
  Device.X_PRPLWARE-COM_SoftwareModules.ModifyNetworkConfigCmd.Input.NetworkConfig.
  Device.X_PRPLWARE-COM_SoftwareModules.ModifyNetworkConfigCmd.Input.NetworkConfig.AccessInterfaces=""
  Device.X_PRPLWARE-COM_SoftwareModules.SetRequestedStateCmd.
  Device.X_PRPLWARE-COM_SoftwareModules.SetRequestedStateCmd.CmdPath="Device.SoftwareModules.ExecutionUnit.\{i\}"
  Device.X_PRPLWARE-COM_SoftwareModules.SetRequestedStateCmd.ErrorCode=""
  Device.X_PRPLWARE-COM_SoftwareModules.SetRequestedStateCmd.ErrorMessage=""
  Device.X_PRPLWARE-COM_SoftwareModules.SetRequestedStateCmd.State="None"
  Device.X_PRPLWARE-COM_SoftwareModules.SetRequestedStateCmd.Input.
  Device.X_PRPLWARE-COM_SoftwareModules.SetRequestedStateCmd.Input.RequestedState=""
  Device.X_PRPLWARE-COM_SoftwareModules.SetRunLevelCmd.
  Device.X_PRPLWARE-COM_SoftwareModules.SetRunLevelCmd.CmdPath="Device.SoftwareModules.ExecEnv.\{i\}"
  Device.X_PRPLWARE-COM_SoftwareModules.SetRunLevelCmd.ErrorCode=""
  Device.X_PRPLWARE-COM_SoftwareModules.SetRunLevelCmd.ErrorMessage=""
  Device.X_PRPLWARE-COM_SoftwareModules.SetRunLevelCmd.State="None"
  Device.X_PRPLWARE-COM_SoftwareModules.SetRunLevelCmd.Input.
  Device.X_PRPLWARE-COM_SoftwareModules.SetRunLevelCmd.Input.RequestedRunLevel=0

Check that no deployment units exist:

  $ R "ba-cli 'SoftwareModules.DeploymentUnit.?'" | tail -n +2
  No data found
  

Check that registry.gitlab.com is accessible:

  $ R "curl --silent --show-error --connect-timeout 60 https://registry.gitlab.com"

Set Input for InstallDU command:

  $ R "${S} && ba-cli X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.{ \\
  > URL=\"docker://registry.gitlab.com/prpl-foundation/prplos/prplos/prplos/\$(get_container_name):prplos-v1\", \\
  > UUID=\"00000000-0000-5000-b000-000000000001\", \\
  > ExecutionEnvRef=\"generic\", \\
  > AllocatedCPUPercent=\"100\", \\
  > AllocatedDiskSpace=\"-1\", \\
  > AllocatedMemory=\"-1\", \\
  > Privileged=\"1\", \\
  > ModuleVersion=\"v1\" \\
  > }" | tail -n +2
  X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.
  X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.AllocatedCPUPercent=100
  X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.AllocatedDiskSpace=-1
  X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.AllocatedMemory=-1
  X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.ExecutionEnvRef="generic"
  X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.ModuleVersion="v1"
  X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.Privileged=1
  X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.URL="docker://registry.gitlab.com/prpl-foundation/prplos/prplos/prplos/*:prplos-v1" (glob)
  X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.UUID="00000000-0000-5000-b000-000000000001"
  

Run InstallDU command and wait:

  $ R "ba-cli X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.State='Requested'" | tail -n +2; sleep 30
  X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.
  X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.State="Requested"
  

Check new DeploymentUnit:

  $ R "ba-cli 'SoftwareModules.DeploymentUnit.[ UUID == \"00000000-0000-5000-b000-000000000001\" ].?'" | tail -n +2
  SoftwareModules.DeploymentUnit.*. (glob)
  SoftwareModules.DeploymentUnit.*.Alias="*" (glob)
  SoftwareModules.DeploymentUnit.*.DUID="*" (glob)
  SoftwareModules.DeploymentUnit.*.Description="*" (glob)
  SoftwareModules.DeploymentUnit.*.ExecutionEnvRef="Device.SoftwareModules.ExecEnv.1." (glob)
  SoftwareModules.DeploymentUnit.*.ExecutionUnitList="Device.SoftwareModules.ExecutionUnit.*" (glob)
  SoftwareModules.DeploymentUnit.*.Installed="*" (glob)
  SoftwareModules.DeploymentUnit.*.LastUpdate="*" (glob)
  SoftwareModules.DeploymentUnit.*.ModuleVersion="v1" (glob)
  SoftwareModules.DeploymentUnit.*.Name="prpl-foundation/prplos/prplos/prplos/*" (glob)
  SoftwareModules.DeploymentUnit.*.Resolved=1 (glob)
  SoftwareModules.DeploymentUnit.*.Status="Installed" (glob)
  SoftwareModules.DeploymentUnit.*.URL="docker://registry.gitlab.com/prpl-foundation/prplos/prplos/prplos/*:prplos-v1" (glob)
  SoftwareModules.DeploymentUnit.*.UUID="00000000-0000-5000-b000-000000000001" (glob)
  SoftwareModules.DeploymentUnit.*.Vendor="*" (glob)
  SoftwareModules.DeploymentUnit.*.VendorConfigList="" (glob)
  SoftwareModules.DeploymentUnit.*.VendorLogList="" (glob)
  SoftwareModules.DeploymentUnit.*.Version="prplos-v1" (glob)
  

Get index of the new DeploymentUnit:

  $ du_index=$(R "ba-cli 'SoftwareModules.DeploymentUnit.*.UUID?'" | tail -n +2 | awk -F'.' '{print $3}')

Remove new DeploymentUnit and wait:

  $ R "ba-cli X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUninstallCmd.CmdPath='Device.SoftwareModules.DeploymentUnit.${du_index}'" | tail -n +2
  X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUninstallCmd.
  X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUninstallCmd.CmdPath="Device.SoftwareModules.DeploymentUnit.*" (glob)
  

  $ R "ba-cli X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUninstallCmd.State='Requested'" | tail -n +2; sleep 10
  X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUninstallCmd.
  X_PRPLWARE-COM_SoftwareModules.DeploymentUnitUninstallCmd.State="Requested"
  

Check that new DeploymentUnit is deleted:

  $ R "ba-cli 'SoftwareModules.DeploymentUnit.?'" | tail -n +2
  No data found
  

Set Input for InstallDU command with error (AllocatedCPUPercent should <= 100):

  $ R "${S} && ba-cli X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.{ \\
  > URL=\"docker://registry.gitlab.com/prpl-foundation/prplos/prplos/prplos/\$(get_container_name):prplos-v1\", \\
  > UUID=\"00000000-0000-5000-b000-000000000001\", \\
  > ExecutionEnvRef=\"generic\", \\
  > AllocatedCPUPercent=\"500\", \\
  > AllocatedDiskSpace=\"-1\", \\
  > AllocatedMemory=\"-1\", \\
  > Privileged=\"1\", \\
  > ModuleVersion=\"v1\" \\
  > }" | tail -n +2
  X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.
  X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.AllocatedCPUPercent=500
  X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.AllocatedDiskSpace=-1
  X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.AllocatedMemory=-1
  X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.ExecutionEnvRef="generic"
  X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.ModuleVersion="v1"
  X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.Privileged=1
  X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.URL="docker://registry.gitlab.com/prpl-foundation/prplos/prplos/prplos/*:prplos-v1" (glob)
  X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.Input.UUID="00000000-0000-5000-b000-000000000001"
  

Run InstallDU command and wait:

  $ R "ba-cli X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.State='Requested'" | tail -n +2; sleep 30
  X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.
  X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.State="Requested"
  

Check error:

  $ R "ba-cli 'X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.State?'" | tail -n +2
  X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.State="Error"
  
  $ R "ba-cli 'X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.ErrorCode?'" | tail -n +2
  X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.ErrorCode="7004"
  
  $ R "ba-cli 'X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.ErrorMessage?'" | tail -n +2
  X_PRPLWARE-COM_SoftwareModules.InstallDUCmd.ErrorMessage="CPU should be between 0 and 100 [not 500]"
  
  $ R "ba-cli 'SoftwareModules.DeploymentUnit.?'" | tail -n +2
  No data found
  

Check that only generic ExecEnv is present:

  $ R "ba-cli 'SoftwareModules.ExecEnv.*.Name?'" | tail -n +2
  SoftwareModules.ExecEnv.1.Name="generic"
  

Set Input for AddExecEnv command:

  $ R "ba-cli X_PRPLWARE-COM_SoftwareModules.AddExecEnvCmd.Input.{ \\
  > Name='TestEnv01', \\
  > Vendor='test_vendor', \\
  > Version='1', \\
  > ParentExecEnv='SoftwareModules.ExecEnv.1', \\
  > InitialRunLevel='4', \\
  > AllocatedMemory='-1', \\
  > AllocatedDiskSpace='-1', \\
  > AllocatedCPUPercent='100' \\
  > }" | tail -n +2
  X_PRPLWARE-COM_SoftwareModules.AddExecEnvCmd.Input.
  X_PRPLWARE-COM_SoftwareModules.AddExecEnvCmd.Input.AllocatedCPUPercent=100
  X_PRPLWARE-COM_SoftwareModules.AddExecEnvCmd.Input.AllocatedDiskSpace=-1
  X_PRPLWARE-COM_SoftwareModules.AddExecEnvCmd.Input.AllocatedMemory=-1
  X_PRPLWARE-COM_SoftwareModules.AddExecEnvCmd.Input.InitialRunLevel=4
  X_PRPLWARE-COM_SoftwareModules.AddExecEnvCmd.Input.Name="TestEnv01"
  X_PRPLWARE-COM_SoftwareModules.AddExecEnvCmd.Input.ParentExecEnv="SoftwareModules.ExecEnv.1"
  X_PRPLWARE-COM_SoftwareModules.AddExecEnvCmd.Input.Vendor="test_vendor"
  X_PRPLWARE-COM_SoftwareModules.AddExecEnvCmd.Input.Version="1"
  

Run AddExecEnv command:

  $ R "ba-cli X_PRPLWARE-COM_SoftwareModules.AddExecEnvCmd.State='Requested'" | tail -n +2
  X_PRPLWARE-COM_SoftwareModules.AddExecEnvCmd.
  X_PRPLWARE-COM_SoftwareModules.AddExecEnvCmd.State="Requested"
  

Check that new ExecEnv is present:

  $ R "ba-cli 'SoftwareModules.ExecEnv.*.Name?'" | tail -n +2
  SoftwareModules.ExecEnv.1.Name="generic"
  SoftwareModules.ExecEnv.*.Name="TestEnv01" (glob)
  

Get index of the new ExecEnv:

  $ exec_env_index=$(R "ba-cli 'SoftwareModules.ExecEnv.*.Name?'" | tail -n +2 | grep -v 'ExecEnv\.1\.' | awk -F'.' '{print $3}')

Remove new ExecEnv:

  $ R "ba-cli X_PRPLWARE-COM_SoftwareModules.ExecEnvDeleteCmd.CmdPath='Device.SoftwareModules.ExecEnv.${exec_env_index}'" | tail -n +2
  X_PRPLWARE-COM_SoftwareModules.ExecEnvDeleteCmd.
  X_PRPLWARE-COM_SoftwareModules.ExecEnvDeleteCmd.CmdPath="Device.SoftwareModules.ExecEnv.*" (glob)
  

  $ R "ba-cli X_PRPLWARE-COM_SoftwareModules.ExecEnvDeleteCmd.State='Requested'" | tail -n +2
  X_PRPLWARE-COM_SoftwareModules.ExecEnvDeleteCmd.
  X_PRPLWARE-COM_SoftwareModules.ExecEnvDeleteCmd.State="Requested"
  

Check that new ExecEnv is deleted:

  $ R "ba-cli 'SoftwareModules.ExecEnv.*.Name?'" | tail -n +2
  SoftwareModules.ExecEnv.1.Name="generic"
  

Cleanup:

  $ rm /tmp/dmm_test_software_modules_orig.txt /tmp/dmm_test_software_modules_proxy.txt
  $ R "rm /tmp/script_functions.sh"
  $ R "/etc/init.d/data-model-mapper stop" > /dev/null 2>&1
  $ R "opkg remove -V0 data-model-mapper"
  Usage : /etc/init.d/data-model-mapper [start|boot|debuginfo|stop|shutdown|restart]

