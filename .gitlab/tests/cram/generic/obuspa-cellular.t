Create obuspa cellular datamodel helpers:

  $ VERIFY_OBUSPA_DATAMODEL="${TESTDIR}/../scripts/verify-obuspa-datamodel.sh"
  $ EXPECTED_OBUSPA_CELLULAR_DATAMODEL="${TESTDIR}/fixtures/obuspa-cellular.expected"

Skip when the firmware has no cellular support:
  $ [ "${DUT_HAS_CELLULAR:-1}" = "1" ] || exit 80

Check that obuspa keeps the expected cellular datamodel across restart:

  $ sh "${VERIFY_OBUSPA_DATAMODEL}" --mode cellular --expected "${EXPECTED_OBUSPA_CELLULAR_DATAMODEL}" --before-actual "${TESTDIR}/fixtures/obuspa-cellular.before-restart.actual" --before-diff "${TESTDIR}/fixtures/obuspa-cellular.before-restart.diff" --after-actual "${TESTDIR}/fixtures/obuspa-cellular.after-restart.actual" --after-diff "${TESTDIR}/fixtures/obuspa-cellular.after-restart.diff"
