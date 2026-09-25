Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting ProcMonWatcher Procd respawn recovery validation"

Verify amx-processmonitor-watcher is running:

  $ R "ps -eaf | grep amx-processmonitor-watcher | grep -v grep >/dev/null && echo PASS || echo FAIL"
  PASS

Capture current watcher PID:

  $ WatcherPID=$(R "pidof amx-processmonitor-watcher")

Verify watcher PID captured successfully:

  $ if [ -n "$WatcherPID" ]; then echo PASS; else echo FAIL; fi
  PASS

Terminate amx-processmonitor-watcher process:

  $ R "kill -9 $WatcherPID"

Wait for procd respawn interval:

  $ sleep 5

Verify that amx-processmonitor-watcher is automatically respawned by procd:

  $ R "ps -eaf | grep amx-processmonitor-watcher | grep -v grep >/dev/null && echo PASS || echo FAIL"
  PASS

Capture the respawned watcher PID:

  $ NewWatcherPID=$(R "pidof amx-processmonitor-watcher")

Terminate the respawned watcher process:

  $ R "kill -9 $NewWatcherPID"

Wait for procd respawn interval:

  $ sleep 5

Verify watcher is respawned successfully by procd after a second process crash :

  $ R "ps -eaf | grep amx-processmonitor-watcher | grep -v grep >/dev/null && echo PASS || echo FAIL"
  PASS

Capture the watcher PID after second recovery:

  $ NewWatcherPID=$(R "pidof amx-processmonitor-watcher")

Terminate the watcher process again :

  $ R "kill -9 $NewWatcherPID"

Wait for procd respawn interval:

  $ sleep 5

Verify watcher is respawned successfully by procd after multiple consecutive process crashes:

  $ R "ps -eaf | grep amx-processmonitor-watcher | grep -v grep >/dev/null && echo PASS || echo FAIL"
  PASS

Verify service registration remains available after multiple respawns:

  $ ServiceInfo=$(R "ubus call service list '{\"name\":\"amx-processmonitor-watcher\"}'")

  $ if [ -n "$ServiceInfo" ]; then echo PASS; else echo FAIL; fi
  PASS


  $ R logger -t cram "ProcMonWatcher Procd respawn and watchdog recovery validation completed"
