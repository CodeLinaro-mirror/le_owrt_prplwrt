Set up the transfer policy test:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh && . /tmp/transfer_policy.sh"
  $ C "${TESTDIR}/script_functions.sh" "root@${TARGET_LAN_IP}:/tmp/script_functions.sh" 2>/dev/null
  $ C "${TESTDIR}/transfer_policy.sh" "root@${TARGET_LAN_IP}:/tmp/transfer_policy.sh" 2>/dev/null
  $ R "${S} && { [ -f \"\${POLICY_BACKUP}\" ] || cp \"\${POLICY_CONFIG}\" \"\${POLICY_BACKUP}\"; }"

  $ BOARD_ARCH=$(R "${S} && get_true_arch_name")
  $ SERVICE_URL="docker://registry.gitlab.com/prpl-foundation/prplos/prplos/${BOARD_ARCH}/alpine:3.16"
  $ FAIL_URL="docker://192.0.2.1/lcmtest/alpine:latest"

Restart with the untouched ODL config and check all seven START defaults:

  $ R "${S} && \
  > policy_restart && \
  > grep -Fx 'transfer config: low-speed-limit=30 low-speed-time=30 connect-timeout=10 maximum-retry-count=3 retry-minimum-wait-interval=2 retry-maximum-wait-interval=8 retry-interval-multiplier=2' \"\${POLICY_START}\""
  transfer config: low-speed-limit=30 low-speed-time=30 connect-timeout=10 maximum-retry-count=3 retry-minimum-wait-interval=2 retry-maximum-wait-interval=8 retry-interval-multiplier=2

Force a connect timeout with no retry. Capture the matching UUID's
InstallDU fault and check both the fault code and curl diagnostic:

  $ R "${S} && configure_transfer_without_retries" >/dev/null

Drop packets to 192.0.2.1 so that the connect times out on every testbed:

  $ R "iptables -I OUTPUT -d 192.0.2.1 -j DROP"
  $ R "${S} && run_transfer_failure_scenario '${FAIL_URL}'" > fault.txt 2>&1
  $ sed -n 's/^.* FaultCode=\([0-9]*\) FaultString=.*/FaultCode = \1/p' fault.txt
  FaultCode = 7002

  $ sed -n 's/^.* FaultString=\(.*\)$/FaultString = "\1"/p' fault.txt
  FaultString = "Pull image [*] failed [Curl download content error [Connection timed out after * milliseconds] URL [*]]" (glob)

Repeat with two retries and short wait windows. Use a fresh log marker so
retry messages from earlier tests cannot satisfy these assertions:

  $ R "${S} && configure_transfer_with_two_retries" >/dev/null
  $ RETRY_MARKER="cram-transfer-policy-$(date +%s)-$$"
  $ R "logger -t cram '${RETRY_MARKER}'"
  $ R "${S} && run_transfer_failure_scenario '${FAIL_URL}'" > fault.txt 2>&1
  $ sed -n 's/^.* FaultCode=\([0-9]*\) FaultString=.*/FaultCode = \1/p' fault.txt
  FaultCode = 7002

  $ sed -n 's/^.* FaultString=\(.*\)$/FaultString = "\1"/p' fault.txt
  FaultString = "Pull image [*] failed [Curl download content error [Connection timed out after * milliseconds] URL [*]]" (glob)

  $ R "${S} && policy_retry_lines '${RETRY_MARKER}'"
  transfer retry 1/2
  transfer retry 2/2

Restore the defaults and prove installation succeeds with the real alpine image:

  $ R "${S} && \
  > policy_restore && \
  > grep -Fx 'transfer config: low-speed-limit=30 low-speed-time=30 connect-timeout=10 maximum-retry-count=3 retry-minimum-wait-interval=2 retry-maximum-wait-interval=8 retry-interval-multiplier=2' \"\${POLICY_START}\""
  transfer config: low-speed-limit=30 low-speed-time=30 connect-timeout=10 maximum-retry-count=3 retry-minimum-wait-interval=2 retry-maximum-wait-interval=8 retry-interval-multiplier=2

  $ R "${S} && install_ctr --url '${SERVICE_URL}' --waittime 60 --ee --uuid \"\${POLICY_UUID}\" --privileged false --enablehostcapabilities false" >/dev/null
  $ R "${S} && get_container_info --uuid \"\${POLICY_UUID}\""
  3.16
  Active
  prpl-foundation/prplos/prplos/*/alpine (glob)
  $ R "${S} && uninstall_ctr_and_check --uuid \"\${POLICY_UUID}\" --retaindata false"
  [1]

Cleanup test environment:

  $ R "${S} && policy_cleanup" >/dev/null
  $ R "rm -f /tmp/script_functions.sh /tmp/transfer_policy.sh"
