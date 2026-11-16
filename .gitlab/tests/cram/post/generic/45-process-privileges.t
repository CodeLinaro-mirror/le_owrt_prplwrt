Skip this test if the CI job name contains CDRouter and VLAN as SSH to DUT is not available (PCF-844):

  $ if echo "$CI_JOB_NAME" | grep -q "^CDRouter.* VLAN "; then exit 80; fi

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ VERIFY_PROCESS_PRIVILEGES="${TESTDIR}/../../scripts/process-privileges/verify.py"

Verify that processes are running with reduced privileges. Services restarted
by an earlier test (e.g. qemu-x86-64/reboot.t) need a few seconds to come back,
and short-lived helpers can show up in a single snapshot, so retry for up to 45 s:

  $ python3 "${VERIFY_PROCESS_PRIVILEGES}" --timeout 45
  OK: All process privileges match expected configuration
