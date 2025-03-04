## Setup test configuration
Set-up the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh"
  $ C ${TESTDIR}/script_functions.sh root@${TARGET_LAN_IP}:/tmp/script_functions.sh 2>/dev/null


### PRIVILEGED CONTAINER SECTION ###
Install the container and check its status:

  $ R "${S} && install_ctr --version prplos-v1 --ee --uuid --privileged true --network" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v1
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)

Check NetworkConfig correctly applied:

  $ sleep 30
  $ CTR_IP=$(R "${S} && get_ctr_ip --uuid")
  $ R "rm -f /root/.ssh/known_hosts > /dev/null; ssh -y root@${CTR_IP} 'cat /etc/container-version ; ip route show default | grep default' 2> /dev/null"
  1
  default via 192.168.*.1 dev lcm0* (glob)


Update to prplOS container to v2:

  $ R "${S} && update_ctr --version prplos-v2 --ee --uuid --privileged true --network" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v2
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)

Check NetworkConfig correctly applied:

  $ sleep 30
  $ CTR_IP=$(R "${S} && get_ctr_ip --uuid")
  $ R "rm -f /root/.ssh/known_hosts > /dev/null; ssh -y root@${CTR_IP} 'cat /etc/container-version ; ip route show default | grep default' 2> /dev/null"
  2
  default via 192.168.*.1 dev lcm0* (glob)

Uninstall the container and check everything is cleaned:

  $ R "${S} && uninstall_ctr_and_check --uuid"
  [1]


### UNPRIVILEGED CONTAINER SECTION ####
Install the container and check its status:

  $ R "${S} && install_ctr --version prplos-v1 --ee --uuid --privileged false --network" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v1
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)

### Network connectivity test can only be done unpriv container gets the capability in its own net ns to 
### bind to a system port (< 1024) or test container is modified to not use system ports for SSH
### Test only checks the attribution of IP address
Check NetworkConfig correctly applied:

  $ sleep 10
  $ R "${S} && get_ctr_ip --uuid"
  192.168.*.* (glob)
#  $ sleep 30 
#  $ R "rm -f /root/.ssh/known_hosts > /dev/null; ssh -y root@${CTR_IP} 'cat /etc/container-version ; ip route show default | grep default' 2> /dev/null"
#  1
#  default via 192.168.3.1 dev lcm0 

Update to prplOS container to v2:

  $ R "${S} && update_ctr --version prplos-v2 --ee --uuid --privileged false --network" > /dev/null
  $ R "${S} && get_container_info --uuid"
  Active
  prplos-v2
  prpl-foundation/prplos/prplos/prplos/lcm-test-* (glob)

### Network connectivity test can only be done unpriv container gets the capability in its own net ns to 
### bind to a system port (< 1024) or test container is modified to not use system ports for SSH
### Test only checks the attribution of IP address
Check NetworkConfig correctly applied:

  $ R "${S} && get_ctr_ip --uuid"
  192.168.*.* (glob)
#  $ R "rm -f /root/.ssh/known_hosts > /dev/null; ssh -y root@${CTR_IP} 'cat /etc/container-version ; ip route show default | grep default' 2> /dev/null"
#  2
#  default via 192.168.3.1 dev lcm0 

Remove the container and check everything is cleaned:

  $ R "${S} && uninstall_ctr_and_check --uuid"
  [1]


Cleanup test environment:

  $ R "rm -f /tmp/script_functions.sh"
