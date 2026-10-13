Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ VERIFY_PROCESS_PRIVILEGES="${TESTDIR}/../../scripts/process-privileges/verify.sh"

Verify that processes are running with reduced privileges:

  $ sh "${VERIFY_PROCESS_PRIVILEGES}"
  OK: All process privileges match expected configuration

Verify that the tr181_app user cannot run an arbitrary commands with sudo

  $ R "sudo -n -u tr181_app -g tr181_app id"
  uid=10(tr181_app) gid=10(tr181_app) groups=10(tr181_app)

  $ R "sudo -n -u tr181_app -g tr181_app sudo -n mount"
  sudo: a password is required
  [1]

Verify that the tr181_app user has the expected sudo privileges

  $ R "sudo -n -u tr181_app sudo -l"
  Matching Defaults entries for tr181_app on prplOS:
      secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin
  
  Runas and Command-specific defaults for tr181_app:
      Defaults!/usr/sbin/visudo env_keep+="SUDO_EDITOR EDITOR VISUAL"
  
  User tr181_app may run the following commands on prplOS:
      (root) NOPASSWD: /etc/init.d/* start, /etc/init.d/* stop, /etc/init.d/* restart
      (root) NOPASSWD: /usr/lib/processmonitor/scripts/*
      (root) NOPASSWD: /sbin/reboot
      (root) NOPASSWD: /bin/getDebugInformation
      (root) NOPASSWD: /usr/lib/amx/scripts/tmpfs_download_mount.sh
      (root) NOPASSWD: /usr/lib/amx/scripts/tmpfs_download_unmount.sh
      (root) NOPASSWD: /etc/init.d/* start, /etc/init.d/* stop, /etc/init.d/* restart
      (root) NOPASSWD: /sbin/reboot
      (root) NOPASSWD: /bin/getDebugInformation


Verify that amxrt fails to run with invalid user or group names

  $ R "amxrt -O '%config{name=\"invalid-app\";privileges={user=\"invalid_user\",group=\"tr181_app\"};}'"
  *invalid_user* (glob)
  [241]

  $ R "amxrt -O '%config{name=\"invalid-app\";privileges={user=\"tr181_app\",group=\"invalid_group\"};}'"
  *invalid_group* (glob)
  [241]

Each service keeps its persistent odl under the directory amxrt derives from its
storage-path, "${storage-path}/odl". amxrt creates that directory owned by the
service account so an unprivileged service can still write its configuration:

  $ R "ls -ld /etc/config/tr181-dns/odl" | awk '{print $1, $3, $4}'
  drwxr-xr-x tr181_app tr181_app

  $ R "ls -ld /etc/config/tr181-usermanagement/odl" | awk '{print $1, $3, $4}'
  drwxr-xr-x tr181_app tr181_app

  $ R "ls -ld /etc/config/routing-manager/odl" | awk '{print $1, $3, $4}'
  drwxr-xr-x tr181_app tr181_app

The service account must be able to write there without relying on a capability:

  $ R "sudo -n -u tr181_app -g tr181_app test -w /etc/config/tr181-dns/odl; echo \$?"
  0
