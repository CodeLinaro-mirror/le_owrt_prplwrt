Create obuspa cellular datamodel helpers:

  $ VERIFY_OBUSPA_DATAMODEL="${TESTDIR}/../scripts/verify-obuspa-datamodel.sh"
  $ EXPECTED_OBUSPA_CELLULAR_DATAMODEL="${TESTDIR}/fixtures/obuspa-cellular.expected"

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Skip the schema comparison when the target has no cellular capability:
  $ if ! R "ubus list | grep -qx Cellular"; then exit 80; fi

Check that obuspa keeps the expected cellular datamodel across restart:

  $ sh "${VERIFY_OBUSPA_DATAMODEL}" --mode cellular --expected "${EXPECTED_OBUSPA_CELLULAR_DATAMODEL}" --before-actual "${TESTDIR}/fixtures/obuspa-cellular.before-restart.actual" --before-diff "${TESTDIR}/fixtures/obuspa-cellular.before-restart.diff" --after-actual "${TESTDIR}/fixtures/obuspa-cellular.after-restart.actual" --after-diff "${TESTDIR}/fixtures/obuspa-cellular.after-restart.diff"
