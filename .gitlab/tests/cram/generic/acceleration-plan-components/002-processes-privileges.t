Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ VERIFY_PROCESS_PRIVILEGES="${TESTDIR}/../../scripts/process-privileges/verify.sh"

Verify that processes are running with reduced privileges:

  $ sh "${VERIFY_PROCESS_PRIVILEGES}"
  OK: All process privileges match expected configuration

Verify tr181_app user cannot run an arbitrary commands with sudo

  $ R "sudo -n -u tr181_app -g tr181_app id"
  uid=10(tr181_app) gid=10(tr181_app) groups=10(tr181_app)

  $ R "sudo -n -u tr181_app -g tr181_app sudo -n mount"
  sudo: a password is required
  [1]

Verify that amxrt fails to run with invalid user or group names

  $ R "amxrt -O '%config{name=\"invalid-app\";privileges={user=\"invalid_user\",group=\"tr181_app\"};}'"
  *invalid_user* (glob)
  [241]

  $ R "amxrt -O '%config{name=\"invalid-app\";privileges={user=\"tr181_app\",group=\"invalid_group\"};}'"
  *invalid_group* (glob)
  [241]
