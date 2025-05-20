## Setup test configuration
Set-up the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions_thread.sh"
  $ C ${TESTDIR}/script_functions_thread.sh root@192.168.1.1:/tmp/script_functions_thread.sh 2>/dev/null

Run the tests only on Freedom or OSPv2 boards:

  $ [ "$DUT_BOARD" != "wnc-freedom" ] || exit 80
  $ [ "$DUT_BOARD" != "urx851-b0-dk" ] || exit 80


Install Thread container check its running:

  $ R "${S} && install_thread_ctr"
  $ R "${S} && get_container_info"
  Active
  latest
  image-thread-cpc-tr181

Configure Thread dataset and enable it:

  $ R "${S} && configure_and_check_thread"
  Up
  SL-OPENTHREAD/* (glob)

Uninstall the testing container and check datamodel cleaned:

  $ R "${S} && uninstall_ctr_and_check"
  [1]


Cleanup test environment:

  $ R "rm -f /tmp/script_functions_thread.sh"
