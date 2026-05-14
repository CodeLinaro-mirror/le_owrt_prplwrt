Create obuspa cellular datamodel helpers:

  $ VERIFY_OBUSPA_DATAMODEL="${TESTDIR}/../scripts/verify-obuspa-datamodel.sh"
  $ EXPECTED_OBUSPA_CELLULAR_DATAMODEL="${TESTDIR}/fixtures/obuspa-cellular.expected"

If test is running on a Mozart, Turris, OSPv1 or Haze, lets skip the test as there is no Cellular support:
  $ if echo "$CI_JOB_NAME" | grep -q -E "(Mozart|Turris|Haze|HDK-3)"; then exit 80; fi

Check that obuspa keeps the expected cellular datamodel across restart:

  $ sh "${VERIFY_OBUSPA_DATAMODEL}" --mode cellular --expected "${EXPECTED_OBUSPA_CELLULAR_DATAMODEL}" --before-actual "${TESTDIR}/fixtures/obuspa-cellular.before-restart.actual" --before-diff "${TESTDIR}/fixtures/obuspa-cellular.before-restart.diff" --after-actual "${TESTDIR}/fixtures/obuspa-cellular.after-restart.actual" --after-diff "${TESTDIR}/fixtures/obuspa-cellular.after-restart.diff"
