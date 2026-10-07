## Setup test configuration
Setup the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ R logger -t cram Starting $TESTFILE
  $ alias C="${CRAM_REMOTE_COPY:-}"
  $ S=". /tmp/script_functions.sh"
  $ C ${TESTDIR}/script_functions.sh root@${TARGET_LAN_IP}:/tmp/script_functions.sh 2>/dev/null
  $ R "/etc/init.d/timingila stop" > /dev/null 2>&1 &
  $ sleep 1
  $ R "timingila -d" > /dev/null 2>&1 &
  $ sleep 2

  $ UUID="00000000-0000-5000-b000-000000000001"
  $ DUID="917362a3-86e8-5332-bcfd-a4223f0e65e6"

### Interruption & Recovery: Timingila crash before container creation
### 1. Invoke install_ctr in background.
### 2. Kill Timingila
### 3. Restart Timingila and verify reconciliation cleans up the unused image in Rlyeh.

Trigger container installation:
  $ R "${S} && install_ctr --version prplos-v1 --ee --uuid ${UUID} --privileged true" > /dev/null 2>&1 &

  $ sleep 1

kill Timingila

  $ R "killall -9 timingila" > /dev/null 2>&1 &
  $ sleep 2

Verify Timingila process was successfully killed:

  $ R "pidof timingila"
  [1]

Check that Rlyeh image associated with the container is not fully installed:
  $ R "ba-cli -l -j 'Rlyeh.Images.[DUID == \"'${DUID}'\"].?' | jsonfilter -e @[*].*.FullyInstalled"
  0

Verify that Cthulhu has not created any container:

  $ R "ba-cli -l -j 'Cthulhu.Container.Instances.[ContainerId == \"'${DUID}'\"].?'"
  
  [{}]

Restart timingila

  $ R "/etc/init.d/timingila start" > /dev/null 2>&1 &
  $ sleep 2

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

  $ R "rm -f /tmp/script_functions.sh"
  $ R logger -t cram Ended $TESTFILE
