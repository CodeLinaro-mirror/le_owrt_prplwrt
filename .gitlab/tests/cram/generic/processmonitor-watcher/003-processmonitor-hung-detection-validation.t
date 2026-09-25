Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting ProcessMonitor hung detection validation"

Set script parameters and copy the script to device:

  $ ChangeAmxDataModel() { curDM=$1; newDM=$2; \
  > $(R "find /etc/amx/amx-processmonitor -name '*.odl' | xargs sed -i -E \"s/\<${curDM}\>/${newDM}\1/g\"") \
  > $(R "rm -rf /etc/config/amx-processmonitor && /etc/init.d/amx-processmonitor restart") \
  > sleep 5;}

Verify amx-processmonitor-watcher is running:

  $ R "ps -eaf | grep amx-processmonitor-watcher | grep -v grep >/dev/null && echo PASS || echo FAIL"
  PASS

Verify amx-processmonitor is running:

  $ R "ps -eaf | grep amx-processmonitor | grep -v grep >/dev/null && echo PASS || echo FAIL"
  PASS

Capture current ProcessMonitor PID:

  $ ProcessMonitorPID=$(R "pidof amx-processmonitor")

Change the amx-processmonitor data model reference from ProcessMonitor.Test to ProcessMonitor1.Test to trigger timeout-based hung detection.

  $ ChangeAmxDataModel "ProcessMonitor" "ProcessMonitor1"

Verify ProcessMonitor1 object available:

  $ ProcessMonitorObject=$(R "ubus list | grep ProcessMonitor1$")

  $ if [ -n "$ProcessMonitorObject" ]; then echo PASS; else echo FAIL; fi
  PASS

Capture current ProcMonWatcher TestInterval:

  $ CurrentTestInterval=$(R "ba-cli Device.X_PRPLWARE-COM_ProcMonWatcher.TestInterval?" | sed 's/.*=//')

Capture current RebootAfterRestartThreshold:

  $ CurrentThreshold=$(R "ba-cli Device.X_PRPLWARE-COM_ProcMonWatcher.RebootAfterRestartThreshold?" | sed 's/.*=//')

Configure RebootAfterRestartThreshold for testing:

  $ R "ba-cli Device.X_PRPLWARE-COM_ProcMonWatcher.RebootAfterRestartThreshold=30" >/dev/null 2>&1

Configure TestInterval for testing:

  $ R "ba-cli Device.X_PRPLWARE-COM_ProcMonWatcher.TestInterval=10" >/dev/null 2>&1

Wait for ProcMonWatcher test interval:

  $ sleep 10

Verify ProcessMonitor restarted by amx-processmonitor-watcher with its DM get failed (as hung detected):

  $ NewProcessMonitorPID=$(R "pidof amx-processmonitor")

  $ if [ -n "$NewProcessMonitorPID" ] &&  [ "$ProcessMonitorPID" != "$NewProcessMonitorPID" ]; then echo PASS; else echo FAIL; fi
  PASS

Verify amx-processmonitor running after recovery:

  $ R "ps -eaf | grep amx-processmonitor | grep -v grep >/dev/null && echo PASS || echo FAIL"
  PASS

Verify amx-processmonitor-watcher still running:

  $ R "ps -eaf | grep amx-processmonitor-watcher | grep -v grep >/dev/null && echo PASS || echo FAIL"
  PASS

Revert the amx-processmonitor data model reference from ProcessMonitor1.Test to ProcessMonitor.Test made for hung detect workaround

  $ ChangeAmxDataModel "ProcessMonitor1" "ProcessMonitor"

Verify ProcessMonitor object available & Capture its PID:

  $ ProcessMonitorObject=$(R "ubus list | grep ProcessMonitor$")

  $ if [ -n "$ProcessMonitorObject" ]; then echo PASS; else echo FAIL; fi
  PASS

  $ NewProcessMonitorPID=$(R "pidof amx-processmonitor")

Wait for ProcMonWatcher test interval:

  $ sleep 10

Verify ProcessMonitor not-restarted as amx-processmonitor-watcher succeeding back with Procmon DM get

  $ CurProcessMonitorPID=$(R "pidof amx-processmonitor")

  $ if [ -n "$NewProcessMonitorPID" ] && [ "$CurProcessMonitorPID" = "$NewProcessMonitorPID" ]; then echo PASS; else echo FAIL; fi
  PASS

Restore original ProcMonWatcher TestInterval:
 
  $ R ba-cli Device.X_PRPLWARE-COM_ProcMonWatcher.TestInterval=$CurrentTestInterval
 
Restore original RebootAfterRestartThreshold:
 
  $ R ba-cli Device.X_PRPLWARE-COM_ProcMonWatcher.RebootAfterRestartThreshold=$CurrentThreshold

  $ R logger -t cram "ProcessMonitor hung detection validation completed"
