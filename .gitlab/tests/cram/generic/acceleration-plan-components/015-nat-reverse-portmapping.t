Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Install LCM Alpine container:

  $ if [ "$DUT_ARCH" = "x86_64" ]; then
  >   (R "ba-cli 'SoftwareModules.InstallDU(URL = \"docker://registry.gitlab.com/prpl-foundation/prplos/prplos/alpine3.16-amd64\", ExecutionEnvRef = generic, UUID = 3952a1c9-e02e-5b06-abd2-e789dd6e0000, Privileged = true, NetworkConfig=[])'") >> /dev/null
  >   else
  >   (R "ba-cli 'SoftwareModules.InstallDU(URL = \"docker://registry.gitlab.com/prpl-foundation/prplos/prplos/alpine3.16-arm32v7\", ExecutionEnvRef = generic, UUID = 3952a1c9-e02e-5b06-abd2-e789dd6e0000, Privileged = true, NetworkConfig=[])'") >> /dev/null
  >   fi

Get container name:

  $ container_name=$(R "ba-cli -j -l \"SoftwareModules.DeploymentUnit.[UUID == '3952a1c9-e02e-5b06-abd2-e789dd6e0000'].?\" | jsonfilter -e @[0]'[*].DUID'")
  $ if [ ! -z "$container_name" ]; then echo "Container name found"; fi
  Container name found

Get container IP:

  $ container_ip=$(R "lxc-info -iH $container_name | head -n 1")
  $ if [ ! -z "$container_ip" ]; then echo "Container IP found"; fi
  Container IP found

Create portmapping:

  $ if [ ! -z "$container_ip" ]; then (R "ba-cli 'NAT.PortMapping.+{Alias=\"testing\", Enable=1, ExternalPort=22222, InternalPort=11111, HairpinNAT=0, Interface=\"Device.IP.Interface.3\", InternalClient=\"${container_ip}\", Protocol=\"TCP\", RemoteHost=\"${TARGET_LAN_TEST_HOST}\"}'") >> /dev/null; fi

Check iptables rule:

  $ (R "iptables -t nat -S PREROUTING_PortForwarding_1 | grep -q -- '-A PREROUTING_PortForwarding_1 -s ${TARGET_LAN_TEST_HOST}/32 -d ${TARGET_LAN_IP}/32 -p tcp -m tcp --dport 22222 -j DNAT --to-destination ${container_ip}:11111'")

Listen for TCP packet inside container on port 11111:

  $ (R "(lxc-attach $container_name -- sh -c 'nc -k -l -w 5 -p 11111 > /tmp/${container_name}_output.txt' &)")

Send TCP packet on port 22222 from LAN host:

  $ sleep 1
  $ (echo 'hello from lan host' | nc -w 1 ${TARGET_LAN_IP} 22222)

Check that packet has been received:

  $ (R "lxc-attach $container_name -- sh -c 'cat /tmp/${container_name}_output.txt'")
  hello from lan host

Remove portmapping:

  $ if [ ! -z "$container_ip" ]; then (R "ba-cli 'NAT.PortMapping.testing.-'") >> /dev/null; fi

Remove container:

  $ (R "ba-cli 'SoftwareModules.DeploymentUnit.cpe-${container_name}.Uninstall()'") >> /dev/null
