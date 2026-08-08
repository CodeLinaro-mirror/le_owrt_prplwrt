Create obuspa datamodel helpers:

  $ VERIFY_OBUSPA_DATAMODEL="${TESTDIR}/../scripts/verify-obuspa-datamodel.sh"
  $ EXPECTED_OBUSPA_DATAMODEL="${TESTDIR}/fixtures/obuspa.expected"

  $ if [ "$DUT_BOARD" = "qemu-standard-pc-q35-ich9-2009" ]; then exit 80; fi

If test is running on a Valyrian, skip the test due to PCF-2669:
  $ if echo "$CI_JOB_NAME" | grep -q -E "Valyrian"; then exit 80; fi

Check that obuspa keeps the expected datamodel across restart (minus the platform specific WiFi Vendor extensions/cellular):

  $ sh "${VERIFY_OBUSPA_DATAMODEL}" --mode generic --expected "${EXPECTED_OBUSPA_DATAMODEL}" --before-actual "${TESTDIR}/fixtures/obuspa.before-restart.actual" --before-diff "${TESTDIR}/fixtures/obuspa.before-restart.diff" --after-actual "${TESTDIR}/fixtures/obuspa.after-restart.actual" --after-diff "${TESTDIR}/fixtures/obuspa.after-restart.diff"
