Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting ProcessMonitor crash recovery validation"

Verify amx-processmonitor-watcher is running:

  $ R "ps -eaf | grep amx-processmonitor-watcher | grep -v grep >/dev/null && echo PASS || echo FAIL"
  PASS

Enable Monitoring on amx-processmonitor-watcher:

  $ R "ba-cli Device.X_PRPLWARE-COM_ProcMonWatcher.Enable=1 >/dev/null && echo PASS || echo FAIL"
  PASS

Verify amx-processmonitor is running:

  $ R "ps -eaf | grep amx-processmonitor | grep -v grep >/dev/null && echo PASS || echo FAIL"
  PASS

Capture ubus events logs on Verifying amx-processmonitor fail actions

  $ UbusMonitorPID=$(R '/bin/ubus monitor | grep -iE "service|instance" | grep '"amx-processmonitor"' > /tmp/amx-pmon_log.txt & echo $!')

Verify UbusMonitor PID captured:

  $ if [ -n "$UbusMonitorPID" ]; then echo PASS; else echo FAIL; fi
  PASS

Kill amx-processmonitor:

  $ R 'kill -9 $(pidof amx-processmonitor)'

  $ sleep 5

Verify amx-processmonitor is respawned:

  $ R "ps -eaf | grep amx-processmonitor | grep -v grep >/dev/null && echo PASS || echo FAIL"
  PASS

Kill the processes - Second kill attempt:

  $ R 'kill -9 $(pidof amx-processmonitor)'

  $ sleep 5

Verify amx-processmonitor is respawned:

  $ R "ps -eaf | grep amx-processmonitor | grep -v grep >/dev/null && echo PASS || echo FAIL"
  PASS

Kill the processes - third kill attempt:

  $ R 'kill -9 $(pidof amx-processmonitor)'

  $ sleep 5

Verify amx-processmonitor is respawned again:

  $ R "ps -eaf | grep amx-processmonitor | grep -v grep >/dev/null && echo PASS || echo FAIL"
  PASS

Kill the processes - Fourth kill attempt, no more respawns of failed process by procd and NumProcessFail will increment:

  $  R 'kill -9 $(pidof amx-processmonitor)'

  $ sleep 10

kill ubus event logging

  $ R "kill -9 $UbusMonitorPID"

Read service.stop event:

  $ ServiceStop=$(R "grep 'service.stop.*amx-processmonitor' /tmp/amx-pmon_log.txt")

Verify service.stop event detected:

  $ if [ -n "$ServiceStop" ]; then echo PASS; else echo FAIL; fi
  PASS

Read instance.stop event:

  $ InstanceStop=$(R "grep 'instance.stop.*amx-processmonitor' /tmp/amx-pmon_log.txt")

Verify instance.stop event detected:

  $ if [ -n "$InstanceStop" ]; then echo PASS; else echo FAIL; fi
  PASS

Read instance.start event:

  $ InstanceStart=$(R "grep 'instance.start.*amx-processmonitor' /tmp/amx-pmon_log.txt")

Verify instance.start event detected:

  $ if [ -n "$InstanceStart" ]; then echo PASS; else echo FAIL; fi
  PASS

Read service.start event:

  $ ServiceStart=$(R "grep 'service.start.*amx-processmonitor' /tmp/amx-pmon_log.txt")

Verify service.start event detected:

  $ if [ -n "$ServiceStart" ]; then echo PASS; else echo FAIL; fi
  PASS

Verify recovery completed successfully after instance.fail event as expected:

  $ R "ps -eaf | grep amx-processmonitor | grep -v grep >/dev/null && echo PASS || echo FAIL"
  PASS

  $ R "grep procmon /var/log/messages | grep -iE 'Executing fail action' >/dev/null && echo PASS || echo FAIL"
  PASS

  $ R logger -t cram "ProcessMonitor crash recovery validation completed"
