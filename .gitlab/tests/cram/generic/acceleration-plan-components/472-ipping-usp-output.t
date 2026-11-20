Setup the test configuration. DUT_OBUSPA_PROTOCOL_TRACE must describe the
current tracing state (0 or 1); the default is tracing disabled:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-scp}"
  $ trace_before=${DUT_OBUSPA_PROTOCOL_TRACE:-0}
  $ case "$trace_before" in 0|1) ;; *) echo 'DUT_OBUSPA_PROTOCOL_TRACE must be 0 or 1'; exit 1 ;; esac
  $ work=$(R "mktemp -d /tmp/cram-ipping-output.XXXXXX")
  $ subscription=
  $ cleanup() {
  >   R "if [ -f '$work/reader' ]; then kill \$(cat '$work/reader') 2>/dev/null || :; fi; if [ -n '$subscription' ]; then obuspa -c del '$subscription' >/dev/null; fi; obuspa -c prototrace '$trace_before' >/dev/null; rm -rf '$work'"
  > }
  $ trap cleanup EXIT
  $ trap 'exit 1' HUP INT TERM
  $ C "$TESTDIR/../../scripts/target/ipdiagnostics-usp-output.sh" "root@${TARGET_LAN_IP}:$work/check.sh" 2>/dev/null

Subscribe to IPPing OperationComplete without restarting the broker:

  $ R "obuspa -c prototrace 1" >/dev/null
  $ subscription=$(R "obuspa -c add Device.LocalAgent.Subscription." | sed -n 's/^Added \(Device.LocalAgent.Subscription\.[0-9][0-9]*\).*$/\1/p')
  $ test -n "$subscription" || exit 1
  $ R "obuspa -c set '$subscription.NotifType' OperationComplete" >/dev/null
  $ R "obuspa -c set '$subscription.ReferenceList' 'Device.IP.Diagnostics.IPPing()'" >/dev/null
  $ R "obuspa -c set '$subscription.Enable' true" >/dev/null

Capture fresh protocol logs and wait until the reader is ready:

  $ marker="cram-ipping-$(basename "$work")"
  $ R "logread -f > '$work/trace' 2>&1 < /dev/null & echo \$! > '$work/reader'"
  $ R "sh '$work/check.sh' ready '$work' '$marker'"

Run one IPv4 ping against loopback and verify that the RPC starts:

  $ R "obuspa -c operate 'Device.IP.Diagnostics.IPPing(Host=\"127.0.0.1\",ProtocolVersion=\"IPv4\",NumberOfRepetitions=1,Timeout=1000,DataBlockSize=56)'" | grep -F 'Started successfully.'
  Asynchronous Operation (Device.IP.Diagnostics.IPPing()) Started successfully.

Wait for OperationComplete and check the named outputs, numeric timings,
successful loopback result, and absence of extra arguments such as _retval:

  $ R "sh '$work/check.sh' check '$work' '$marker'"
  AverageResponseTime
  AverageResponseTimeDetailed
  FailureCount
  IPAddressUsed
  MaximumResponseTime
  MaximumResponseTimeDetailed
  MinimumResponseTime
  MinimumResponseTimeDetailed
  Status
  SuccessCount

Remove the subscription, stop log capture and restore protocol tracing:

  $ cleanup
  $ trap - EXIT HUP INT TERM
