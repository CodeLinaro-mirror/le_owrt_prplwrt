Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that Sandbox is not configured properly:

  $ R "ubus -S call Cthulhu.Sandbox.Instances.1.NetworkNS.Interfaces.1 _get"
  [4]

  $ R "ubus -S call Cthulhu.Config _get | jsonfilter -e @[*].DhcpCommand"
  [1]

Install testing prplOS container v1:

  $ cat > /tmp/run-container <<EOF
  > ubus-cli '\''SoftwareModules.InstallDU(URL="docker://registry.gitlab.com/prpl-foundation/prplos/prplos/prplos-testing-container-x86-64:v1", UUID="prplos-testing", ExecutionEnvRef="generic", NetworkConfig = { "AccessInterfaces" = [{"Reference" = "Lan"]}})'\''
  > EOF
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/run-container)'" > /dev/null

Check that prplOS container v1 is running:

  $ sleep 40

  $ R "ubus -S call Cthulhu.Container.Instances.1 _get | jsonfilter -e @[*].Status -e @[*].Bundle -e @[*].BundleVersion -e @[*].ContainerId -e @[*].Alias | sort"
  Running
  cpe-prplos-testing
  prpl-foundation/prplos/prplos/prplos-testing-container-x86-64
  prplos-testing
  v1

  $ container_ip=$(R "ubus call DHCPv4Server.Pool.3.Client.1.IPv4Address.1 _get | jsonfilter -e @[*].IPAddress")
  $ R "ssh -y root@$container_ip 'cat /etc/container-version' 2> /dev/null"
  1

Update to prplOS container v2:

  $ cat > /tmp/run-container <<EOF
  > ubus-cli '\''SoftwareModules.DeploymentUnit.cpe-prplos-testing.Update(URL="docker://registry.gitlab.com/prpl-foundation/prplos/prplos/prplos-testing-container-x86-64:v2", UUID="prplos-testing", ExecutionEnvRef="generic", "NetworkConfig" = { "AccessInterfaces" = [{"Reference" = "Lan"]}})'\''
  > EOF
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/run-container)'" > /dev/null

Check that prplOS container v2 is running:

  $ sleep 40

  $ R "ubus -S call Cthulhu.Container.Instances.2 _get | jsonfilter -e @[*].Status -e @[*].Bundle -e @[*].BundleVersion -e @[*].ContainerId -e @[*].Alias | sort"
  Running
  cpe-prplos-testing
  prpl-foundation/prplos/prplos/prplos-testing-container-x86-64
  prplos-testing
  v2

  $ container_ip=$(R "ubus call DHCPv4Server.Pool.3.Client.2.IPv4Address.1 _get | jsonfilter -e @[*].IPAddress")
  $ R "ssh -y root@$container_ip 'cat /etc/container-version' 2> /dev/null"
  2

Uninstall prplOS testing container:

  $ script --command "ssh -t root@$TARGET_LAN_IP 'ubus-cli SoftwareModules.DeploymentUnit.cpe-prplos-testing.Uninstall\(\)'" > /dev/null;  sleep 5

Check that prplOS container is not running:

  $ R "ubus -S call Cthulhu.Container.Instances.2 _get"
  [4]

Check that Rlyeh has no container images:

  $ R "ubus -S call Rlyeh.Images _get"
  {"Rlyeh.Images.":{}}
  {}
  {"amxd-error-code":0}

Check that container image is gone from the filesystem as well:

  $ R "ls -al /usr/share/rlyeh/images/prplos"
  ls: /usr/share/rlyeh/images/prplos: No such file or directory
  [1]
