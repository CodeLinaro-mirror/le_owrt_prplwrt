Check that a service registers after a delayed broker handshake.

Skip the affected platform due to PCF-2669:

  $ if echo "$CI_JOB_NAME" | grep -q -E "Valyrian"; then exit 80; fi

RouterAdvertisement is part of the common prpl profile and registers its
Enable parameter over USP. Skip images where either process is absent.

  $ R() { timeout "${REMOTE_TIMEOUT:-10}" ${CRAM_REMOTE_COMMAND:-sh -c} "$@"; }
  $ SERVICE=tr181-routeradvertisement
  $ USP_PARAMETER=Device.RouterAdvertisement.Enable
  $ broker=$(R 'pidof obuspa') || exit 80
  $ service_pid=$(R "pidof $SERVICE") || exit 80
  $ case "$broker:$service_pid" in *[!0-9:]*|:*|*:) echo 'expected one process per service'; exit 1;; esac
  $ datamodel_available() {
  >     REMOTE_TIMEOUT=${1:-2} R "obuspa -c get $USP_PARAMETER" 2>/dev/null |
  >         grep -q '^Device\.RouterAdvertisement\.Enable => '
  > }
  $ datamodel_available && echo 'datamodel available on USP' || exit 1
  datamodel available on USP

Always resume obuspa and restore the service on exit. A timer on the DUT
also resumes obuspa if the connection to the DUT is lost.

  $ backstop=
  $ cleanup() {
  >     R "kill -CONT $broker; ${backstop:+kill $backstop 2>/dev/null;} /etc/init.d/$SERVICE restart" >/dev/null 2>&1
  > }
  $ trap 'cleanup' EXIT
  $ trap 'exit 129' HUP
  $ trap 'exit 130' INT
  $ trap 'exit 143' TERM
  $ backstop=$(R "(trap '' HUP; sleep 15; kill -CONT $broker) </dev/null >/dev/null 2>&1 & echo \$!") || exit 1

Pause obuspa while restarting the service, then resume it after five
seconds. This exceeds the two-second handshake wait without editing ODL.

  $ R "kill -STOP $broker && /etc/init.d/$SERVICE restart" || exit 1
  $ sleep 5
  $ R "kill -CONT $broker && kill $backstop" || exit 1
  $ backstop=
  $ R "kill -0 $broker && pidof $SERVICE >/dev/null" && echo 'obuspa and service running' || exit 1
  obuspa and service running
  $ R "ba-cli 'RouterAdvertisement.?'" | grep -q '^RouterAdvertisement.Enable=' && echo 'datamodel available locally' || exit 1
  datamodel available locally

Poll every two seconds for up to 30 seconds. Bound each query as well as
the deadline, so an unresponsive broker cannot extend the wait.

  $ wait_for_datamodel() {
  >     deadline=$(($(date +%s) + 30))
  >     while [ "$(date +%s)" -lt "$deadline" ]; do
  >         remaining=$((deadline - $(date +%s)))
  >         [ "$remaining" -gt 0 ] || break
  >         if [ "$remaining" -gt 2 ]; then remaining=2; fi
  >         if datamodel_available "$remaining"; then
  >             echo 'datamodel available on USP after late handshake'
  >             return 0
  >         fi
  >         remaining=$((deadline - $(date +%s)))
  >         [ "$remaining" -gt 0 ] || break
  >         if [ "$remaining" -gt 2 ]; then remaining=2; fi
  >         sleep "$remaining"
  >     done
  >     echo 'datamodel not available on USP after 30 seconds'
  >     return 1
  > }
  $ wait_for_datamodel || exit 1
  datamodel available on USP after late handshake
