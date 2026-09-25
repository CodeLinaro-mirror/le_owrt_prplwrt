Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting ProcMonWatcher hung detection validation"

Verify amx-processmonitor-watcher is running:

  $ R "ps -eaf | grep amx-processmonitor-watcher | grep -v grep >/dev/null && echo PASS || echo FAIL"
  PASS

Verify software watchdog Enable:

  $ R "ba-cli Device.X_PRPLWARE-COM_ProcMonWatcher.SWWatchdog.Enable?" | grep Enable=
  Device.X_PRPLWARE-COM_ProcMonWatcher.SWWatchdog.Enable=1

Record the Current Timeout and Frequency to revert after Testing:

  $ CurrentFrequency=$(R "ba-cli Device.X_PRPLWARE-COM_ProcMonWatcher.SWWatchdog.Frequency?" | sed 's/.*=//')
  $ CurrentTimeout=$(R "ba-cli Device.X_PRPLWARE-COM_ProcMonWatcher.SWWatchdog.Timeout?" | sed 's/.*=//')

Configure minimum software watchdog Frequency & Timeout for cram testing:

  $ R "ba-cli Device.X_PRPLWARE-COM_ProcMonWatcher.SWWatchdog.Frequency=15" >/dev/null 2>&1
  $ R "ba-cli Device.X_PRPLWARE-COM_ProcMonWatcher.SWWatchdog.Timeout=30" >/dev/null 2>&1

Verify software watchdog Timeout configured:

  $ R "ba-cli Device.X_PRPLWARE-COM_ProcMonWatcher.SWWatchdog.Frequency?" | grep Frequency=
  Device.X_PRPLWARE-COM_ProcMonWatcher.SWWatchdog.Frequency=15

  $ R "ba-cli Device.X_PRPLWARE-COM_ProcMonWatcher.SWWatchdog.Timeout?" | grep Timeout=
  Device.X_PRPLWARE-COM_ProcMonWatcher.SWWatchdog.Timeout=30

Disable software watchdog ping via set_software_watchdog_keepalive_state() call:

  $ R "ubus call X_PRPLWARE-COM_ProcMonWatcher.SWWatchdog set_software_watchdog_keepalive_state '{\"Enable\":0}'" >/dev/null 2>&1

Wait partial Timeout interval:

  $ sleep 15

Verify service entry available:

  $ ServiceInfo=$(R "ubus call service list '{\"name\":\"amx-processmonitor-watcher\"}'")

  $ if [ -n "$ServiceInfo" ]; then echo PASS; else echo FAIL; fi
  PASS

Wait remaining timeout interval:

  $ sleep 20

Capture watcher PID after timeout:

  $ NewWatcherPID=$(R "pidof amx-processmonitor-watcher")

Verify watcher restarted by watchdog:

  $ if [ "$WatcherPID" != "$NewWatcherPID" ]; then echo PASS; else echo FAIL; fi
  PASS

Verify watcher is running:

  $ R "ps -eaf | grep amx-processmonitor-watcher | grep -v grep >/dev/null && echo PASS || echo FAIL"
  PASS

Enable back software watchdog ping via set_software_watchdog_keepalive_state() call:

  $ R "ubus call X_PRPLWARE-COM_ProcMonWatcher.SWWatchdog set_software_watchdog_keepalive_state '{\"Enable\":1}'" >/dev/null 2>&1

Restore original ProcMonWatcher.Watchdog Frequency and Timeout:

  $ R ba-cli Device.X_PRPLWARE-COM_ProcMonWatcher.Watchdog.Frequency=$CurrentFrequency
  $ R ba-cli Device.X_PRPLWARE-COM_ProcMonWatcher.Watchdog.Timeout=$CurrentTimeout

  $ R logger -t cram "ProcMonWatcher hung detection validation completed"
