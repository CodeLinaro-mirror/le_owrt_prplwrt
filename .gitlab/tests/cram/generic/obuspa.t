Create obuspa datamodel helpers:

  $ VERIFY_OBUSPA_DATAMODEL="${TESTDIR}/../scripts/verify-obuspa-datamodel.sh"
  $ EXPECTED_OBUSPA_DATAMODEL="${TESTDIR}/fixtures/obuspa.expected"

Check that obuspa keeps the expected datamodel across restart (minus the platform specific WiFi Vendor extensions/cellular):

  $ sh "${VERIFY_OBUSPA_DATAMODEL}" --mode generic --expected "${EXPECTED_OBUSPA_DATAMODEL}" --before-actual "${TESTDIR}/fixtures/obuspa.before-restart.actual" --before-diff "${TESTDIR}/fixtures/obuspa.before-restart.diff" --after-actual "${TESTDIR}/fixtures/obuspa.after-restart.actual" --after-diff "${TESTDIR}/fixtures/obuspa.after-restart.diff"
