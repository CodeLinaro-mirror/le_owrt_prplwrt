## Setup test configuration
Setup the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ R logger -t cram Starting $TESTFILE
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh"
  $ C ${TESTDIR}/script_functions.sh root@${TARGET_LAN_IP}:/tmp/script_functions.sh 2>/dev/null
  $ C ${TESTDIR}/../../scripts/target/ubus-events.lua root@${TARGET_LAN_IP}:/tmp/ubus-event.lua 2>/dev/null

  $ UUID="00000000-0000-5000-b000-000000000001"
  $ DUID="917362a3-86e8-5332-bcfd-a4223f0e65e6"

### Interruption & Recovery: Cthulhu crash before container backend creation complete
### 1. Listen for the DeploymentUnit instance-added event with Status = Installing.
### 2. Invoke install_ctr in background.
### 3. Kill cthulhu when the event is received.
### 4. Start Cthulhu and Timingila and verify reconciliation cleans up the unused image in Rlyeh.

Listen to the dm:instance-added event and kill cthulhu when received:

  $ R 'lua /tmp/ubus-event.lua "SoftwareModules.DeploymentUnit." "dm:instance-added" "parameters.DUID == \"'${DUID}'\" and parameters.Status == \"Installing\"" 2>&1 | while IFS= read -r line; do echo "$line" >> /tmp/captured_event; echo "$line" | grep -q "dm:instance-added" && { /etc/init.d/cthulhu stop 2>/dev/null; killall -9 cthulhu 2>/dev/null; sleep 1; for pid in $(pidof cthulhu); do kill -9 $pid; done; }; done &'
  $ sleep 1

Trigger container installation:

  $ R "${S} && install_ctr --version prplos-v1 --ee --uuid ${UUID} --privileged true" > /dev/null 2>&1 &

Wait for event to be captured and cthulhu killed:
  $ sleep 10

Verify Cthulhu process was successfully killed:

  $ R "pidof cthulhu"
  [1]

Check that Rlyeh image associated with the container is not fully installed:

  $ R "ba-cli -l -j 'Rlyeh.Images.[DUID == \"'${DUID}'\"].?' | jsonfilter -e @[*].*.FullyInstalled"
  0

Start cthulhu

  $ R "/etc/init.d/cthulhu start" > /dev/null 2>&1 &
  $ sleep 4

Restart timingila

  $ R "/etc/init.d/timingila restart" > /dev/null 2>&1 &
  $ sleep 4

Verify reconcilation and image cleanup
No image

  $ R "ba-cli -l -j 'Rlyeh.Images.[DUID == \"'${DUID}'\"].?'"
  
  [{}]

No container

  $ R "ba-cli -l -j 'Cthulhu.Container.Instances.[ContainerId == \"'${DUID}'\"].?'"
  
  [{}]

No DeploymentUnit

  $ R "ba-cli -l -j 'SoftwareModules.DeploymentUnit.[DUID == \"'${DUID}'\"].?'"
  
  [{}]

Cleanup test environment:

  $ R "rm -f /tmp/script_functions.sh /tmp/ubus-event.lua /tmp/captured_event"
  $ R logger -t cram Ended $TESTFILE
