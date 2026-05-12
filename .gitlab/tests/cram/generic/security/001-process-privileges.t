Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ VERIFY_PROCESS_PRIVILEGES="${TESTDIR}/../../scripts/process-privileges/verify.sh"

Verify that processes are running with reduced privileges:

  $ sh "${VERIFY_PROCESS_PRIVILEGES}"
  OK: All process privileges match expected configuration

