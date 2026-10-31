Skip this test if the CI job name contains CDRouter and VLAN as SSH to DUT is not available (PCF-844):

  $ if echo "$CI_JOB_NAME" | grep -q "^CDRouter.* VLAN "; then exit 80; fi

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ VERIFY_PROCESS_PRIVILEGES="${TESTDIR}/../../scripts/process-privileges/verify.sh"

Services restarted by an earlier test (e.g. qemu-x86-64/reboot.t) need a few
seconds to come back; wait up to about 45 s (20 tries, 2 s apart):

  $ for i in $(seq 20); do sh "${VERIFY_PROCESS_PRIVILEGES}" >/dev/null 2>&1 && break; sleep 2; done

Verify that processes are running with reduced privileges:

  $ sh "${VERIFY_PROCESS_PRIVILEGES}"
  OK: All process privileges match expected configuration
