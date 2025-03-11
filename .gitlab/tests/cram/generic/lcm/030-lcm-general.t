## Setup test configuration
Setup the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh"
  $ C ${TESTDIR}/script_functions.sh root@${TARGET_LAN_IP}:/tmp/script_functions.sh
  Warning: Permanently added '*' (*) to the list of known hosts* (glob)


Check Global Execution Environment and configuration:

  $ R "${S} && check_ee_status --ee"
  1
  Up


Check internal Cthulhu.Config datamodel:

  $ R "${S} && check_cthulhu_config"
  /lcm/rlyeh/images
  /usr/*/cthulhu-lxc/cthulhu-lxc.so (glob)
  1


Cleanup test environment:

  $ R "rm -f /tmp/script_functions.sh"
