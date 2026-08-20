Board-agnostic passthrough DM smoke (generic testbeds with tr181-passthrough).

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/passthrough.sh"

  $ R logger -t cram "passthrough generic: DM smoke"

  $ R "amx_wait_for Device.IP.Passthrough."

  $ init_passthrough_dm_paths
  passthrough-dm-(bbf|legacy) (re)

  $ verify_passthrough_daemon_running
  passthrough-daemon-running

  $ read_passthrough_enable
  Device.IP.(Passthrough|X_PRPLWARE-COM_Passthrough).1.Enable=(0|1) (re)

  $ read_passthrough_status
  Device.IP.(Passthrough|X_PRPLWARE-COM_Passthrough).1.Status="(Disabled|Enabled|InProgress|Error.*)" (re)
