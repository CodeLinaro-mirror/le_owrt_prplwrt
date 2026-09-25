Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting Hardware Watchdog enable/disable validation"

Verify Hardware Watchdog enabled in TR-181:

  $ R "ba-cli Device.X_PRPLWARE-COM_ProcMonWatcher.HWWDEnable?" | grep HWWDEnable=
  Device.X_PRPLWARE-COM_ProcMonWatcher.HWWDEnable=1

Verify watchdog status is enabled:

  $ R "ubus call system watchdog '{}' | grep -q 'status.: .running' && echo PASS || echo FAIL"
  PASS

  $ R "ubus call system watchdog '{}' | grep -q 'magicclose.: false' && echo PASS || echo FAIL"
  PASS

Disable Hardware Watchdog:

  $ R "ba-cli Device.X_PRPLWARE-COM_ProcMonWatcher.HWWDEnable=0" >/dev/null 2>&1

Verify watchdog status is disabled:

  $ R "ubus call system watchdog '{}' | grep -q 'status.: .offline' && echo PASS || echo FAIL"
  PASS

  $ R "ubus call system watchdog '{}' | grep -q 'magicclose.: true' && echo PASS || echo FAIL"
  PASS

Enable Hardware Watchdog:

  $ R "ba-cli Device.X_PRPLWARE-COM_ProcMonWatcher.HWWDEnable=1" >/dev/null 2>&1

Verify watchdog status reverted back to enabled:

  $ R "ubus call system watchdog '{}' | grep -q 'status.: .running' && echo PASS || echo FAIL"
  PASS

  $ R "ubus call system watchdog '{}' | grep -q 'magicclose.: false' && echo PASS || echo FAIL"
  PASS

  $ R logger -t cram "Hardware Watchdog enable/disable validation completed"
