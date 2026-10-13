Skip this test if the CI job name contains CDRouter and VLAN as SSH to DUT is not available (PCF-844):

  $ if echo "$CI_JOB_NAME" | grep -q "^CDRouter.* VLAN "; then exit 80; fi

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ VERIFY_PROCESS_PRIVILEGES="${TESTDIR}/../../scripts/process-privileges/verify.sh"

Verify that processes are running with reduced privileges:

  $ sh "${VERIFY_PROCESS_PRIVILEGES}"
  OK: All process privileges match expected configuration
