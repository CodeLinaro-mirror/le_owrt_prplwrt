Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting with Procd respawn cram tests"

Disable amx-processmonitor to avoid process respawn by it:

  $ R "service amx-processmonitor stop  > /dev/null 2>&1"

Restart tr181-qos process before test:

  $ R "service tr181-qos restart  > /dev/null 2>&1"

Wait 5 seconds for the process to functional:

  $ sleep 5

Read and verify tr181-qos process is running:

  $ R "pgrep -x tr181-qos -P 1"
  \d+ (re)

Kill tr181-qos process and verify process is not running - first kill attempt:

  $ R "pkill -x tr181-qos -P 1"

  $ R "pgrep -x tr181-qos  -P 1 | sed '/^$/d'"

After default retry_timeout of 5 seconds, the process will be respawned:

  $ sleep 6

  $ R "pgrep -x tr181-qos -P 1"
  \d+ (re)

Kill tr181-qos for second time and verify process is not running \
- second kill attempt:

  $ R "pkill -x tr181-qos -P 1"

  $ R "pgrep -x tr181-qos  -P 1 | sed '/^$/d'"

After default retry_timeout of 5 seconds, the process will be respawned:

  $ sleep 6

  $ R "pgrep -x tr181-qos -P 1"
  \d+ (re)

Kill tr181-qos for third time and verify process is not running \
- third kill attempt:

  $ R "pkill -x tr181-qos -P 1"

  $ R "pgrep -x tr181-qos  -P 1 | sed '/^$/d'"

After default retry_timeout of 5 seconds(with few additional dealy to start \
the process), the process will be respawned:

  $ sleep 6

  $ R "pgrep -x tr181-qos -P 1"
  \d+ (re)

Kill tr181-qos for fourth time and verify process is not running \
- fourth kill attempt:

  $ R "pkill -x tr181-qos -P 1"

  $ R "pgrep -x tr181-qos  -P 1 | sed '/^$/d'"

Wait for default retry_timeout of 5 seconds(and more time to ensure), \
now we have exhausted all 3(default value) retry_attempts, \
no more respawns will happen:

  $ sleep 6

  $ R "pgrep -x tr181-qos  -P 1 | sed '/^$/d'"

Cleanup, restart tr181-qos to reset respawn parameters:

  $ R "service tr181-qos restart  > /dev/null 2>&1"

Enable amx-processmonitor disabled at the start of the testcase:

  $ R "service amx-processmonitor start  > /dev/null 2>&1"

  $ R logger -t cram "Procd respawn test finished"