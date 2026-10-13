Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Add testing SSH server instance on LAN interface and port 1922:

  $ printf "\
  > ubus-cli SSH.Server.+{Alias='ci-testing',Port=1922,AllowPasswordLogin='False',AllowRootLogin='False',AllowRootPasswordLogin='False'}
  > ubus-cli SSH.Server.ci-testing.Interface=Device.IP.Interface.3.
  > ubus-cli SSH.Server.ci-testing.IPv4AllowedSourcePrefix="192.168.1.0/24"
  > ubus-cli SSH.Server.ci-testing.Enable=1
  > ubus-cli SSH.AuthorizedKey.+{Alias='ci-testing',User='Users.User.1.'}
  > " > /tmp/cram
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/cram)'" > /dev/null; sleep 5

Check that the server is running:

  $ R "pgrep -f '^dropbear.*1922' --count"
  1

Host keys live in the hostkey-path directory, /etc/config/dropbear/. Check the
identity the server actually serves, without restarting ssh-server: the cram
transport itself pins the DUT host key, so a regenerated identity would strand
the rest of the suite.

  $ R "ls /etc/config/dropbear/ | grep -c '_key$'"
  3

  $ R "ls -l /etc/config/dropbear/dropbear_ed25519_host_key" | awk '{print $1}'
  -rw-------

Neither legacy location may still hold a host key. A key left behind means the
migration in the ssh-server start script did not move it, and the next boot
would serve a different identity to every client:

  $ R "ls /etc/dropbear/*_key /etc/config/ssh_server/*_key 2>/dev/null | wc -l"
  0

The key served on the wire is the one on disk, so the migration preserved the
host identity rather than generating a new one:

  $ DUTKEY=$(R "dropbearkey -y -f /etc/config/dropbear/dropbear_ed25519_host_key" | awk '/^ssh-ed25519 /{print $2}')
  $ ssh-keyscan -p 1922 -t ed25519 $TARGET_LAN_IP 2>/dev/null | awk '{print $3}' | grep -cF "$DUTKEY"
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

  $ ssh -o BatchMode=yes -o "UserKnownHostsFile=/dev/null" -o StrictHostKeyChecking=no -p 1922 root@$TARGET_LAN_IP 'exit 0' 2> /dev/null

Disable password login:

  $ R "ubus -S call SSH.Server.3 _set '{\"parameters\":{\"AllowRootPasswordLogin\":False}}'" ; sleep 2
  {"SSH.Server.3.":{"AllowRootPasswordLogin":false}}
  {}
  {"amxd-error-code":0}

Add public key:

  $ R "ubus -S call SSH.AuthorizedKey.1 _set '{\"parameters\":{\"Key\":\"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHiusVUeBdR2CY8vcBY5MjKBs8zfIoyZ4kfrJfSM13PS\"}}'" ; sleep 2
  {"SSH.AuthorizedKey.1.":{"Key":"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHiusVUeBdR2CY8vcBY5MjKBs8zfIoyZ4kfrJfSM13PS"}}
  {}
  {"amxd-error-code":0}

Start two client connections using public key authentication:

  $ ssh -i ${CI_PROJECT_DIR}/.gitlab/certs/ssh-server/ed25519-ci -o "UserKnownHostsFile=/dev/null" -o BatchMode=yes -o StrictHostKeyChecking=no -p 1922 root@$TARGET_LAN_IP 'sleep 5' > /dev/null 2>&1 &
  $ sleep 1

  $ ssh -i ${CI_PROJECT_DIR}/.gitlab/certs/ssh-server/ed25519-ci -o "UserKnownHostsFile=/dev/null" -o BatchMode=yes -o StrictHostKeyChecking=no -p 1922 root@$TARGET_LAN_IP 'sleep 5' > /dev/null 2>&1 &
  $ sleep 1

Every other login in this test disables host key checking, so none of them can
fail when the identity changes. Pin the key read from disk above and log in with
strict checking: this is the assertion an unwanted host key change has to break.

  $ KNOWNHOSTS=$(mktemp)
  $ echo "[$TARGET_LAN_IP]:1922 ssh-ed25519 $DUTKEY" > "$KNOWNHOSTS"
  $ ssh -i ${CI_PROJECT_DIR}/.gitlab/certs/ssh-server/ed25519-ci -o BatchMode=yes -o StrictHostKeyChecking=yes -o "GlobalKnownHostsFile=/dev/null" -o "UserKnownHostsFile=$KNOWNHOSTS" -p 1922 root@$TARGET_LAN_IP 'exit 0'
  $ rm -f "$KNOWNHOSTS"

Remove the testing SSH server:

  $ script --command "ssh -t root@$TARGET_LAN_IP 'ubus-cli SSH.Server.ci-testing-'" > /dev/null 2>&1 ; sleep 3

Check that the testing SSH server is not running:

  $ R "pgrep -f '^dropbear.*1922' --count"
  0
  [1]
