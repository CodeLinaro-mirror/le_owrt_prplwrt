Create aliases:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ alias C="${CRAM_REMOTE_COPY:-}"

Set script parameters and copy the script to device:

  $ S=". /tmp/script_functions_amx.sh"

  $ C ${TESTDIR}/script_functions_amx.sh root@${TARGET_LAN_IP}:/tmp/amx_script_functions.sh
  Warning: Permanently added '*' (*) to the list of known hosts* (glob)

  $ R logger -t cram "Starting with amx-processmonitoring reset method cram "\
  > "test"

Pre-test actions, Restart the process service to clear the respawns and other failures before starting with tests:

  $ R "service tr181-mcastd restart  > /dev/null 2>&1"
  $ R "service tr181-pcp restart  > /dev/null 2>&1"
  $ R "service dhcpv4-manager restart  > /dev/null 2>&1"

Wait 5 seconds for the process to turn functional:

  $ sleep 5

Initialize the ProcessMonitor.Test.i Id for required processes:

  $ Tr181McastId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep tr181-mcastd | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")
  $ Tr181PcpId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep tr181-pcp | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")
  $ Dhcpv4ManagerId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep dhcpv4-manager | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")

Get the initial NumProcessRespawn for all the process:

  $ Tr181McastRespawn=$(R "ba-cli -l ProcessMonitor.Test.$Tr181McastId.NumProcessRespawn? | sed '/^$/d'")
  $ Tr181PcpRespawn=$(R "ba-cli -l ProcessMonitor.Test.$Tr181PcpId.NumProcessRespawn? | sed '/^$/d'")
  $ Dhcpv4ManagerRespawn=$(R "ba-cli -l ProcessMonitor.Test.$Dhcpv4ManagerId.NumProcessRespawn? | sed '/^$/d'")

Get the initial MaxFailNum for all the process:

  $ Tr181McastMaxFail=$(R "ba-cli -l ProcessMonitor.Test.$Tr181McastId.MaxFailNum? | sed '/^$/d'")
  $ Tr181PcpMaxFail=$(R "ba-cli -l ProcessMonitor.Test.$Tr181PcpId.MaxFailNum? | sed '/^$/d'")
  $ Dhcpv4ManagerMaxFail=$(R "ba-cli -l ProcessMonitor.Test.$Dhcpv4ManagerId.MaxFailNum? | sed '/^$/d'")

Get the Process ID and verify all expected process are running:

  $ for process_name in "tr181-mcastd" "tr181-pcp" "dhcpv4-manager"; do
  > R "${S} && get_pid \"$process_name\""; done
  tr181-mcastd.* \d+ (re)
  tr181-pcp.* \d+ (re)
  dhcpv4-manager.* \d+ (re)

Get existing values of CurrentTestInterval, Health for processes:

  $ R "${S} && get_health_and_interval \"$Tr181McastId\" \"$Tr181PcpId\""\
  > " \"$Dhcpv4ManagerId\""
  tr181-mcastd \d+ .* (re)
  tr181-pcp \d+ .* (re)
  dhcpv4-manager \d+ .* (re)

Kill the processes - Frist kill attempt:

  $ for process_name in "tr181-mcastd" "tr181-pcp" "dhcpv4-manager"; do
  > R "${S} && kill_process \"$process_name\""; done

  $ sleep 15

Get the Process ID and verify all expected process are running:

  $ for process_name in "tr181-mcastd" "tr181-pcp" "dhcpv4-manager"; do
  > R "${S} && get_pid \"$process_name\""; done
  tr181-mcastd.* \d+ (re)
  tr181-pcp.* \d+ (re)
  dhcpv4-manager.* \d+ (re)

Verify amx-process monitor has updated the NumProcessRespawn after process respawn:

  $ R "${S} && verify_process_fail_update $Tr181McastId $((Tr181McastRespawn+1))"
  tr181-mcastd NumProcessRespawn PASS
  tr181-mcastd MaxNumFailed PASS

  $ R "${S} && verify_process_fail_update $Tr181PcpId $((Tr181PcpRespawn+1))"
  tr181-pcp NumProcessRespawn PASS
  tr181-pcp MaxNumFailed PASS

  $ R "${S} && verify_process_fail_update $Dhcpv4ManagerId $((Dhcpv4ManagerRespawn+1))"
  dhcpv4-manager NumProcessRespawn PASS
  dhcpv4-manager MaxNumFailed PASS

Call reset method of amx-processmonitor and verify process monitoring parameters are reset:

  $ for process_id in $Tr181McastId $Tr181PcpId $Dhcpv4ManagerId; do
  > R "${S} && reset_amx_process_monitoring $process_id"; done
  tr181-mcastd reset OK
  tr181-pcp reset OK
  dhcpv4-manager reset OK

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

  $ R "${S} && verify_value_reset $Dhcpv4ManagerId"
  dhcpv4-manager ProcessMonitoringEnabled PASS
  dhcpv4-manager MaxNumFailed PASS
  dhcpv4-manager NumProcessFail PASS
  dhcpv4-manager NumProcessRespawn PASS

Restart the process service to clear the respawns from above tests:

  $ R "service tr181-mcastd restart  > /dev/null 2>&1"
  $ R "service tr181-pcp restart  > /dev/null 2>&1"
  $ R "service dhcpv4-manager restart  > /dev/null 2>&1"

  $ R logger -t cram "Amx-processmonitoring reset method cram test finished"
