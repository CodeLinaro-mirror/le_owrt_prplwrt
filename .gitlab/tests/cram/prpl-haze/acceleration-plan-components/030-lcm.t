Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check Cthulhu.Sandbox datamodel:

  $ R "ubus -S call Cthulhu.Sandbox.Instances.1 _get | jsonfilter -e @[*].Status -e @[*].Enable -e @[*].SandboxId | sort"
  Up
  generic
  true

Check Cthulhu.Config datamodel:

  $ R "ubus -S call Cthulhu.Config _get | jsonfilter -e @[*].UseOverlayFS -e @[*].DefaultBackend -e @[*].ImageLocation | sort"
  /usr/lib/cthulhu-lxc/cthulhu-lxc.so
  /usr/share/rlyeh/images
  true

Install testing prplOS container v1:

  $ cat > /tmp/run-container <<EOF
  > ubus-cli SoftwareModules.InstallDU\( \
  > URL="docker://registry.gitlab.com/prpl-foundation/prplos/prplos/prplos-testing-container-ipq807x-generic:v1", \
  > UUID="prplos-testing", \
  > ExecutionEnvRef="generic", \
  > NetworkConfig = { "AccessInterfaces" = [{"Reference" = "Lan"}] } \
  > \)
  > EOF
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/run-container)'" > /dev/null

Check that prplOS container v1 is running:

  $ sleep 30

  $ R "ubus -S call Cthulhu.Container.Instances.1 _get | jsonfilter -e @[*].Status -e @[*].Bundle -e @[*].BundleVersion -e @[*].ContainerId -e @[*].Alias | sort"
  Running
  cpe-prplos-testing
  prplos-testing
  prplos/prplos/prplos-testing-container-ipq807x-generic
  v1

  $ container_ip=$(R "ubus call DHCPv4Server.Pool.3.Client.1.IPv4Address.1 _get | jsonfilter -e @[*].IPAddress")
  $ R "ssh -y root@$container_ip 'cat /etc/container-version ; ip r' 2> /dev/null"
  1
  default via 192.168.5.1 dev lcm0 
  192.168.5.0/24 dev lcm0 scope link  src 192.168.5.* (re)

Update to prplOS container v2:

  $ cat > /tmp/run-container <<EOF
  > ubus-cli SoftwareModules.DeploymentUnit.cpe-prplos-testing.Update\( \
  > URL="docker://registry.gitlab.com/prpl-foundation/prplos/prplos/prplos-testing-container-ipq807x-generic:v2", \
  > UUID="prplos-testing", \
  > ExecutionEnvRef="generic", \
  > NetworkConfig = { "AccessInterfaces" = [{"Reference" = "Lan"}] } \
  > \)
  > EOF
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/run-container)'" > /dev/null

Check that prplOS container v2 is running:

  $ sleep 30

  $ R "ubus -S call Cthulhu.Container.Instances.2 _get | jsonfilter -e @[*].Status -e @[*].Bundle -e @[*].BundleVersion -e @[*].ContainerId -e @[*].Alias | sort"
  Running
  cpe-prplos-testing
  prplos-testing
  prplos/prplos/prplos-testing-container-ipq807x-generic
  v2

  $ container_ip=$(R "ubus call DHCPv4Server.Pool.3.Client.2.IPv4Address.1 _get | jsonfilter -e @[*].IPAddress")
  $ R "ssh -y root@$container_ip 'cat /etc/container-version ; ip r' 2> /dev/null"
  2
  default via 192.168.5.1 dev lcm0 
  192.168.5.0/24 dev lcm0 scope link  src 192.168.5.* (re)

Uninstall prplOS testing container:

  $ script --command "ssh -t root@$TARGET_LAN_IP 'ubus-cli SoftwareModules.DeploymentUnit.cpe-prplos-testing.Uninstall\(\)'" > /dev/null;  sleep 5

Check that prplOS container is not running:

  $ R "ubus -S call Cthulhu.Container.Instances.2 _get"
  [4]

Check that container image is gone from the filesystem as well:

  $ R "ls -al /usr/share/rlyeh/images/prplos"
  ls: /usr/share/rlyeh/images/prplos: No such file or directory
  [1]
