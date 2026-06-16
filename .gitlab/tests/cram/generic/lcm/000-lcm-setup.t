## Setup global env
Setup the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh"
  $ C ${TESTDIR}/script_functions.sh root@${TARGET_LAN_IP}:/tmp/script_functions.sh 2>/dev/null


Setup the test env by overriding some default parameters values and restarting Cthulhu to
take them into account.
Restarting cthulhu would allow to workaround USP functionality after obuspa restart (LCM-835):

  $ C ${TESTDIR}/zzz-ci-defaults.odl root@${TARGET_LAN_IP}:/etc/amx/cthulhu/extensions
  Warning: Permanently added '*' (*) to the list of known hosts* (glob)
  $ C ${TESTDIR}/zzz-ci-timingila-cthulhu-config.odl root@${TARGET_LAN_IP}:/etc/amx/timingila/extensions/
  Warning: Permanently added '*' (*) to the list of known hosts* (glob)

Clean up LCM configuration to allow re-running on the tests under the same conditions:

  $ R "${S} && start_lcm_clean"
