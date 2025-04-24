## Setup global env
Setup the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"

Setup the test env by overrinding some default parameters values and restarting Cthulhu to
take them into account.
Restating cthulhu would allow to workaround USP functionality after obuspa restart (LCM-835):

  $ C ${TESTDIR}/zzz-ci-defaults.odl root@${TARGET_LAN_IP}:/etc/amx/cthulhu/extensions
  Warning: Permanently added '*' (*) to the list of known hosts* (glob)
  $ R "/etc/init.d/cthulhu restart"; sleep 10
