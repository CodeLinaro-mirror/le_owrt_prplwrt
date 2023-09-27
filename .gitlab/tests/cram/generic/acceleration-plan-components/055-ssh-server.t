Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Add testing SSH server instance on LAN interface and port 1922:

  $ printf "\
  > ubus-cli SSH.Server.+{Alias='ci-testing',Enable=1,Port=1922,AllowPasswordLogin='False',AllowRootLogin='False',AllowRootPasswordLogin='False'}
  > ubus-cli SSH.Server.ci-testing.Interface=Device.IP.Interface.3.
  > ubus-cli SSH.Server.ci-testing.IPv4AllowedSourcePrefix="192.168.1.0/24"
  > " > /tmp/cram
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/cram)'" > /dev/null; sleep 5

Check that the server is running:

  $ R "pgrep -f dropbear.*1922 --count"
  1

Check that root is not able to login with password:

  $ script --quiet --command "ssh -t -o StrictHostKeyChecking=no -p 1922 root@$TARGET_LAN_IP" | grep -c "Permission denied (publickey)"
  1

Enable password login:

  $ printf "\
  > ubus-cli SSH.Server.ci-testing.AllowPasswordLogin='True'
  > ubus-cli SSH.Server.ci-testing.AllowRootPasswordLogin='True'
  > ubus-cli SSH.Server.ci-testing.AllowRootLogin='True'
  > " > /tmp/cram
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/cram)'" > /dev/null; sleep 5

Check datamodel:

  $ R "ubus call SSH.Server.3 _get | jsonfilter -e @[*].Status -e @[*].AllowPasswordLogin -e @[*].AllowRootLogin" | sort
  Enabled
  true
  true

Check that root is able to login with no password:

  $ ssh -o BatchMode=yes -o StrictHostKeyChecking=no -p 1922 root@$TARGET_LAN_IP 'exit 0'

Remove the testing SSH server:

  $ script --command "ssh -t root@$TARGET_LAN_IP 'ubus-cli SSH.Server.ci-testing-'" > /dev/null; sleep 5

Check that the testing SSH server is not running:

  $ R "pgrep -f dropbear.*1922 --count"
  0
  [1]
