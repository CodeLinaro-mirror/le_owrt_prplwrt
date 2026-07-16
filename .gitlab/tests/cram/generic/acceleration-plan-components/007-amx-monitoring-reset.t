Create aliases:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ alias C="${CRAM_REMOTE_COPY:-}"

Set script parameters and copy the script to device:

  $ S=". /tmp/script_functions_amx.sh"

  $ C ${TESTDIR}/script_functions_amx.sh root@${TARGET_LAN_IP}:/tmp/amx_script_functions.sh
  Warning: Permanently added '*' (*) to the list of known hosts* (glob)

  $ R logger -t cram "Starting with amx-processmonitoring reset method cram "\
  > "test"

Pre-test actions, call Reset() on the processes to clear the respawns and other
failures before starting with tests

  $ R "ba-cli 'ProcessMonitor.Test.tr181-mcastd.reset()' >/dev/null 2>&1"
  $ R "ba-cli 'ProcessMonitor.Test.tr181-pcp.reset()' >/dev/null 2>&1"
  $ R "ba-cli 'ProcessMonitor.Test.tr181-qos.reset()' >/dev/null 2>&1"
  $ R "ba-cli 'ProcessMonitor.Test.cellular-manager.reset()'  >/dev/null 2>&1"

Wait 5 seconds for the process to turn functional:

  $ sleep 5

Initialize the ProcessMonitor.Test.i Id for required processes:

  $ Tr181McastId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep tr181-mcastd | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")
  $ Tr181PcpId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep tr181-pcp | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")
  $ Tr181CellularManagerId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep cellular-manager | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")

Get the initial NumProcessRespawn for all the process:

  $ Tr181McastRespawn=$(R "ba-cli -l ProcessMonitor.Test.$Tr181McastId.NumProcessRespawn? | sed '/^$/d'")
  $ Tr181PcpRespawn=$(R "ba-cli -l ProcessMonitor.Test.$Tr181PcpId.NumProcessRespawn? | sed '/^$/d'")
  $ Tr181CellularManagerRespawn=$(R "ba-cli -l ProcessMonitor.Test.$Tr181CellularManagerId.NumProcessRespawn? | sed '/^$/d'")

Get the initial MaxFailNum for all the process:

  $ Tr181McastMaxFail=$(R "ba-cli -l ProcessMonitor.Test.$Tr181McastId.MaxFailNum? | sed '/^$/d'")
  $ Tr181PcpMaxFail=$(R "ba-cli -l ProcessMonitor.Test.$Tr181PcpId.MaxFailNum? | sed '/^$/d'")
  $ Tr181CellularManagerMaxFail=$(R "ba-cli -l ProcessMonitor.Test.$Tr181CellularManagerId.MaxFailNum? | sed '/^$/d'")

# MaxFailNum bumped from prod default of 2 to 5, above the worst-case
# NumFailed (1-3) from a single kill + 10s TestInterval phase alignment
# Lower value would flake and higher would mask bugs

Set MaxFailNum=5 to avoid flaky tests and do not mask possible bugs:

  $ R "ba-cli -l  ProcessMonitor.Test.$Tr181McastId.MaxFailNum=5 | sed '/^$/d'"
  5

  $ R "ba-cli -l ProcessMonitor.Test.$Tr181PcpId.MaxFailNum=5 | sed '/^$/d'"
  5

  $ R "ba-cli -l ProcessMonitor.Test.$Tr181CellularManagerId.MaxFailNum=5 | sed '/^$/d'"
  5

Get initial ProcessMonitor.Test.i.TestInterval:

  $ Tr181McastTestInterval=$(R "${S} && get_test_interval $Tr181McastId")
  $ Tr181PcpTestInterval=$(R "${S} && get_test_interval $Tr181PcpId")
  $ Tr181CellularManagerTestInterval=$(R "${S} && get_test_interval $Tr181CellularManagerId")

Update Monitoring interval to shorter duration for all process, because when\
monitoring of a process is performed and expected process is still performing\
some pre-handling tasks before becoming fully functional. This similar issue\
may be seen in other processes also:

  $ R "${S} && set_test_interval \"10\" \"$Tr181McastId\" \"$Tr181PcpId\" \"$Tr181CellularManagerId\""


Get the Process ID and verify all expected process are running:

  $ for process_name in "tr181-mcastd" "tr181-pcp" "cellular-manager"; do
  > R "${S} && get_pid \"$process_name\""; done
  tr181-mcastd.* \d+ (re)
  tr181-pcp.* \d+ (re)
  cellular-manager.* \d+ (re)

Get existing values of CurrentTestInterval, Health for processes:

  $ R "${S} && get_health_and_interval \"$Tr181McastId\" \"$Tr181PcpId\""\
  > " \"$Tr181CellularManagerId\""
  tr181-mcastd \d+ .* (re)
  tr181-pcp \d+ .* (re)
  cellular-manager \d+ .* (re)

Kill the processes - Frist kill attempt:

  $ for process_name in "tr181-mcastd" "tr181-pcp" "cellular-manager"; do
  > R "${S} && kill_process \"$process_name\""; done

  $ sleep 15

Get the Process ID and verify all expected process are running:

  $ for process_name in "tr181-mcastd" "tr181-pcp" "cellular-manager"; do
  > R "${S} && get_pid \"$process_name\""; done
  tr181-mcastd.* \d+ (re)
  tr181-pcp.* \d+ (re)
  cellular-manager.* \d+ (re)

Verify amx-process monitor has updated the NumProcessRespawn after process respawn:

  $ R "${S} && verify_process_fail_update $Tr181McastId $((Tr181McastRespawn+1))"
  tr181-mcastd NumProcessRespawn PASS
  tr181-mcastd MaxNumFailed PASS

  $ R "${S} && verify_process_fail_update $Tr181PcpId $((Tr181PcpRespawn+1))"
  tr181-pcp NumProcessRespawn PASS
  tr181-pcp MaxNumFailed PASS

  $ R "${S} && verify_process_fail_update $Tr181CellularManagerId $((Tr181CellularManagerRespawn+1))"
  cellular-manager NumProcessRespawn PASS
  cellular-manager MaxNumFailed PASS

Call reset method of amx-processmonitor and verify process monitoring parameters are reset:

  $ for process_id in $Tr181McastId $Tr181PcpId $Tr181CellularManagerId; do
  > R "${S} && reset_amx_process_monitoring $process_id"; done
  tr181-mcastd reset OK
  tr181-pcp reset OK
  cellular-manager reset OK

Verify ProcessMonitoring parameter reset after calling reset method:

  $ R "${S} && verify_value_reset $Tr181McastId"
  tr181-mcastd ProcessMonitoringEnabled PASS
  tr181-mcastd MaxNumFailed PASS
  tr181-mcastd NumProcessFail PASS
  tr181-mcastd NumProcessRespawn PASS

  $ R "${S} && verify_value_reset $Tr181PcpId"
  tr181-pcp ProcessMonitoringEnabled PASS
  tr181-pcp MaxNumFailed PASS
  tr181-pcp NumProcessFail PASS
  tr181-pcp NumProcessRespawn PASS

  $ R "${S} && verify_value_reset $Tr181CellularManagerId"
  cellular-manager ProcessMonitoringEnabled PASS
  cellular-manager MaxNumFailed PASS
  cellular-manager NumProcessFail PASS
  cellular-manager NumProcessRespawn PASS

Revert MaxFail parameter for the process to initial value:

  $ R "ba-cli -l  ProcessMonitor.Test.$Tr181McastId.MaxFailNum=$Tr181McastMaxFail | sed '/^$/d'"
  \d+ (re)

  $ R "ba-cli -l ProcessMonitor.Test.$Tr181PcpId.MaxFailNum=$Tr181PcpMaxFail | sed '/^$/d'"
  \d+ (re)

  $ R "ba-cli -l ProcessMonitor.Test.$Tr181CellularManagerId.MaxFailNum=$Tr181CellularManagerMaxFail | sed '/^$/d'"
  \d+ (re)

Revert ProcessMonitor.Test.i TestInterval:

  $ R "${S} && set_test_interval \"$Tr181McastTestInterval\" \"$Tr181McastId\""
  $ R "${S} && set_test_interval \"$Tr181PcpTestInterval\" \"$Tr181PcpId\""
  $ R "${S} && set_test_interval \"$Tr181CellularManagerTestInterval\" \"$Tr181CellularManagerId\""

  $ R logger -t cram "Amx-processmonitoring reset method cram test finished"
