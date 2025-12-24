Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ alias C="${CRAM_REMOTE_COPY:-}"

Set script parameters and copy the script to device:

  $ S=". /tmp/script_functions_amx.sh"

  $ C ${TESTDIR}/script_functions_amx.sh root@${TARGET_LAN_IP}:/tmp/amx_script_functions.sh
  Warning: Permanently added '*' (*) to the list of known hosts* (glob)

  $ R logger -t cram "Starting amx-processmonitoring process fail test"

Pre-test actions, Restart the process service to clear the respawns and other failures before starting with tests:

  $ R "service tr181-mcastd restart  > /dev/null 2>&1"
  $ R "service tr181-pcp restart  > /dev/null 2>&1"
  $ R "service tr181-qos restart > /dev/null 2>&1"
  $ R "service dhcpv4-manager restart  > /dev/null 2>&1"

Wait 5 seconds for the process to become functional:

  $ sleep 5

Initialize the ProcessMonitor.Test.i Id for required processes:

  $ Tr181McastId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep tr181-mcastd | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")
  $ Tr181PcpId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep tr181-pcp | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")
  $ Tr181QosId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep tr181-qos | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")
  $ Dhcpv4ManagerId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep dhcpv4-manager | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")

Get the initial NumProcessRespawn for all the process:

  $ Tr181McastRespawn=$(R "ba-cli -l ProcessMonitor.Test.$Tr181McastId.NumProcessRespawn? | sed '/^$/d'")
  $ Tr181PcpRespawn=$(R "ba-cli -l ProcessMonitor.Test.$Tr181PcpId.NumProcessRespawn? | sed '/^$/d'")
  $ Tr181QosRespawn=$(R "ba-cli -l ProcessMonitor.Test.$Tr181QosId.NumProcessRespawn? | sed '/^$/d'")
  $ Dhcpv4ManagerRespawn=$(R "ba-cli -l ProcessMonitor.Test.$Dhcpv4ManagerId.NumProcessRespawn? | sed '/^$/d'")

Get the initial NumProcessFail for all the process:

  $ Tr181McastFail=$(R "ba-cli -l ProcessMonitor.Test.$Tr181McastId.NumProcessFail? | sed '/^$/d'")
  $ Tr181PcpFail=$(R "ba-cli -l ProcessMonitor.Test.$Tr181PcpId.NumProcessFail? | sed '/^$/d'")
  $ Tr181QosFail=$(R "ba-cli -l ProcessMonitor.Test.$Tr181QosId.NumProcessFail? | sed '/^$/d'")
  $ Dhcpv4ManagerFail=$(R "ba-cli -l ProcessMonitor.Test.$Dhcpv4ManagerId.NumProcessFail? | sed '/^$/d'")

Get the initial MaxFailNum for all the process:

  $ Tr181McastMaxFail=$(R "ba-cli -l ProcessMonitor.Test.$Tr181McastId.MaxFailNum? | sed '/^$/d'")
  $ Tr181PcpMaxFail=$(R "ba-cli -l ProcessMonitor.Test.$Tr181PcpId.MaxFailNum? | sed '/^$/d'")
  $ Tr181QosMaxFail=$(R "ba-cli -l ProcessMonitor.Test.$Tr181QosId.MaxFailNum? | sed '/^$/d'")
  $ Dhcpv4ManagerMaxFail=$(R "ba-cli -l ProcessMonitor.Test.$Dhcpv4ManagerId.MaxFailNum? | sed '/^$/d'")

Verify process are up and running:

  $ for process_name in "tr181-mcastd" "tr181-pcp"  "tr181-qos" "dhcpv4-manager"; do
  > R "${S} && get_pid \"$process_name\""; done
  tr181-mcastd.* \d+ (re)
  tr181-pcp.* \d+ (re)
  tr181-qos.* \d+ (re)
  dhcpv4-manager.* \d+ (re)

Change MaxFail parameter for the processes to higher value:

  $ R "ba-cli -l  ProcessMonitor.Test.$Tr181McastId.MaxFailNum=30 | sed '/^$/d'"
  30

  $ R "ba-cli -l ProcessMonitor.Test.$Tr181PcpId.MaxFailNum=30 | sed '/^$/d'"
  30

  $ R "ba-cli -l ProcessMonitor.Test.$Tr181QosId.MaxFailNum=30 | sed '/^$/d'"
  30

  $ R "ba-cli -l ProcessMonitor.Test.$Dhcpv4ManagerId.MaxFailNum=30 | sed '/^$/d'"
  30

Get existing values of CurrentTestInterval, Health for processes:

  $ R "${S} && get_health_and_interval \"$Tr181McastId\" \"$Tr181PcpId\""\
  > " \"$Tr181QosId\" \"$Dhcpv4ManagerId\""
  tr181-mcastd \d+ .* (re)
  tr181-pcp \d+ .* (re)
  tr181-qos \d+ .* (re)
  dhcpv4-manager \d+ .* (re)

Kill the processes - first kill attempt:

  $ for process_name in tr181-mcastd tr181-pcp tr181-qos dhcpv4-manager; do
  > R "${S} && kill_process \"$process_name\""; done

  $ sleep 5

Verify process respawn:

  $ for process_name in "tr181-mcastd" "tr181-pcp"  "tr181-qos" "dhcpv4-manager"; do
  > R "${S} && get_pid \"$process_name\""; done
  tr181-mcastd.* \d+ (re)
  tr181-pcp.* \d+ (re)
  tr181-qos.* \d+ (re)
  dhcpv4-manager.* \d+ (re)

Kill the processes - Second kill attempt:

  $ for process_name in "tr181-mcastd" "tr181-pcp"  "tr181-qos" "dhcpv4-manager"; do
  > R "${S} && kill_process \"$process_name\""; done

  $ sleep 5

Verify process respawn:

  $ for process_name in "tr181-mcastd" "tr181-pcp"  "tr181-qos" "dhcpv4-manager"; do
  > R "${S} && get_pid \"$process_name\""; done
  tr181-mcastd.* \d+ (re)
  tr181-pcp.* \d+ (re)
  tr181-qos.* \d+ (re)
  dhcpv4-manager.* \d+ (re)

Kill the processes - third kill attempt:

  $ for process_name in "tr181-mcastd" "tr181-pcp"  "tr181-qos" "dhcpv4-manager"; do
  > R "${S} && kill_process \"$process_name\""; done

  $ sleep 5

Verify process respawn:

  $ for process_name in "tr181-mcastd" "tr181-pcp"  "tr181-qos" "dhcpv4-manager"; do
  > R "${S} && get_pid \"$process_name\""; done
  tr181-mcastd.* \d+ (re)
  tr181-pcp.* \d+ (re)
  tr181-qos.* \d+ (re)
  dhcpv4-manager.* \d+ (re)

Kill the processes - Fourth kill attempt, no more respawns of failed process by procd and NumProcessFail will increment:

  $ for process_name in "tr181-mcastd" "tr181-pcp"  "tr181-qos" "dhcpv4-manager"; do
  > R "${S} && kill_process \"$process_name\""; done

  $ sleep 5

Verify NumProcessFail is incremented for process fail:

  $ R "${S} && verify_num_Process_fail $Tr181McastId $((Tr181McastFail+1))"
  tr181-mcastd NumProcessFail PASS

  $ R "${S} && verify_num_Process_fail $Tr181PcpId $((Tr181PcpFail+1))"
  tr181-pcp NumProcessFail PASS

  $ R "${S} && verify_num_Process_fail $Tr181QosId $((Tr181QosFail+1))"
  tr181-qos NumProcessFail PASS

  $ R "${S} && verify_num_Process_fail $Dhcpv4ManagerId $((Dhcpv4ManagerFail+1))"
  dhcpv4-manager NumProcessFail PASS

Verify amx-process monitor has updated the NumProcessRespawn after process respawn for all kill attempts above:

  $ R "${S} && verify_respawn_value $Tr181McastId $((Tr181McastRespawn+3))"
  tr181-mcastd NumProcessRespawn PASS

  $ R "${S} && verify_respawn_value $Tr181PcpId $((Tr181PcpRespawn+3))"
  tr181-pcp NumProcessRespawn PASS

  $ R "${S} && verify_respawn_value $Tr181QosId $((Tr181QosRespawn+3))"
  tr181-qos NumProcessRespawn PASS

  $ R "${S} && verify_respawn_value $Dhcpv4ManagerId $((Dhcpv4ManagerRespawn+3))"
  dhcpv4-manager NumProcessRespawn PASS

Clean-up Revert MaxFail parameter for the process to initial value:

  $ R "ba-cli -l  ProcessMonitor.Test.$Tr181McastId.MaxFailNum=$Tr181McastMaxFail | sed '/^$/d'"
  \d+ (re)

  $ R "ba-cli -l ProcessMonitor.Test.$Tr181PcpId.MaxFailNum=$Tr181PcpMaxFail | sed '/^$/d'"
  \d+ (re)

  $ R "ba-cli -l ProcessMonitor.Test.$Tr181QosId.MaxFailNum=$Tr181QosMaxFail | sed '/^$/d'"
  \d+ (re)

  $ R "ba-cli -l ProcessMonitor.Test.$Dhcpv4ManagerId.MaxFailNum=$Dhcpv4ManagerMaxFail | sed '/^$/d'"
  \d+ (re)

Restart process service to clear the respawns from above tests:

  $ R "service tr181-mcastd restart  > /dev/null 2>&1"
  $ R "service tr181-pcp restart  > /dev/null 2>&1"
  $ R "service tr181-qos restart > /dev/null 2>&1"
  $ R "service dhcpv4-manager restart  > /dev/null 2>&1"

  $ R logger -t cram "Amx-processmonitoring process fail test finished"
