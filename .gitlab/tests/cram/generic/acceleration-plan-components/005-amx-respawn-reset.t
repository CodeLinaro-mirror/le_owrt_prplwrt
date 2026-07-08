Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ alias C="${CRAM_REMOTE_COPY:-}"

Set script parameters and copy the script to device:

  $ S=". /tmp/script_functions_amx.sh"

  $ C ${TESTDIR}/script_functions_amx.sh root@${TARGET_LAN_IP}:/tmp/script_functions_amx.sh
  Warning: Permanently added '*' (*) to the list of known hosts* (glob)

  $ R logger -t cram "Starting with amx-processmonitoring respawn cram test"

Pre-test actions, call Reset() on the processes to clear the respawns and other
failures before starting with tests

  $ R "ba-cli 'ProcessMonitor.Test.tr181-mcastd.reset()' >/dev/null 2>&1"
  $ R "ba-cli 'ProcessMonitor.Test.tr181-pcp.reset()' >/dev/null 2>&1"
  $ R "ba-cli 'ProcessMonitor.Test.tr181-qos.reset()' >/dev/null 2>&1"
  $ R "ba-cli 'ProcessMonitor.Test.cellular-manager.reset()'  >/dev/null 2>&1"

Wait 5 seconds for the process to turn functional:

  $ sleep 5

Initialize the ProcessMonitor.Test.i Id for required processes:

  $ Tr181McastdId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep tr181-mcastd | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")
  $ Tr181PcpId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep tr181-pcp | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")
  $ Tr181QosId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep tr181-qos | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")
  $ Tr181CellularManagerId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep cellular-manager | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")

Get the initial NumProcessRespawn for all the process:

  $ Tr181McastdMaxRespawn=$(R "ba-cli -l ProcessMonitor.Test.$Tr181McastdId.NumProcessRespawn? | sed '/^$/d'")
  $ Tr181PcpRespawn=$(R "ba-cli -l ProcessMonitor.Test.$Tr181PcpId.NumProcessRespawn? | sed '/^$/d'")
  $ Tr181QosRespawn=$(R "ba-cli -l ProcessMonitor.Test.$Tr181QosId.NumProcessRespawn? | sed '/^$/d'")
  $ Tr181CellularManagerRespawn=$(R "ba-cli -l ProcessMonitor.Test.$Tr181CellularManagerId.NumProcessRespawn? | sed '/^$/d'")

Get the initial MaxFailNum for all the process:

  $ Tr181McastdMaxFail=$(R "ba-cli -l ProcessMonitor.Test.$Tr181McastdId.MaxFailNum? | sed '/^$/d'")
  $ Tr181PcpMaxFail=$(R "ba-cli -l ProcessMonitor.Test.$Tr181PcpId.MaxFailNum? | sed '/^$/d'")
  $ Tr181QosMaxFail=$(R "ba-cli -l ProcessMonitor.Test.$Tr181QosId.MaxFailNum? | sed '/^$/d'")
  $ Tr181CellularManagerMaxFail=$(R "ba-cli -l ProcessMonitor.Test.$Tr181CellularManagerId.MaxFailNum? | sed '/^$/d'")

Get initial ProcessMonitor.Test.i.TestInterval:

  $ Tr181McastdTestInterval=$(R "${S} && get_test_interval $Tr181McastdId")
  $ Tr181PcpTestInterval=$(R "${S} && get_test_interval $Tr181PcpId")
  $ Tr181QosTestInterval=$(R "${S} && get_test_interval $Tr181QosId")
  $ Tr181CellularManagerTestInterval=$(R "${S} && get_test_interval $Tr181CellularManagerId")

Update Monitoring interval to shorter duration for all process, because When\
monitoring of a process is performed and expected process is still performing\
some pre-handling tasks before becoming fully functional. This similar issue\
may be seen in other processes also:

  $ R "${S} && set_test_interval 10 $Tr181McastdId"
  $ R "${S} && set_test_interval 10 $Tr181PcpId"
  $ R "${S} && set_test_interval 10 $Tr181QosId"
  $ R "${S} && set_test_interval 10 $Tr181CellularManagerId"

Get the Process ID and verify all expected process are running:

  $ for process_name in "tr181-mcastd" "tr181-pcp"  "tr181-qos" \
  > "cellular-manager"; do  R "${S} && get_pid \"$process_name\""; done
  tr181-mcastd.* \d+ (re)
  tr181-pcp.* \d+ (re)
  tr181-qos.* \d+ (re)
  cellular-manager.* \d+ (re)

Get existing values of CurrentTestInterval, Health for processes:

  $ R "${S} && get_health_and_interval \"$Tr181McastdId\" \"$Tr181PcpId\""\
  > " \"$Tr181QosId\" \"$Tr181CellularManagerId\""
  tr181-mcastd \d+ .* (re)
  tr181-pcp \d+ .* (re)
  tr181-qos \d+ .* (re)
  cellular-manager \d+ .* (re)

Change MaxFail parameter for the processes to higher value:

  $ R "ba-cli -l  ProcessMonitor.Test.$Tr181McastdId.MaxFailNum=30 | sed '/^$/d'"
  30

  $ R "ba-cli -l ProcessMonitor.Test.$Tr181PcpId.MaxFailNum=30 | sed '/^$/d'"
  30

  $ R "ba-cli -l ProcessMonitor.Test.$Tr181QosId.MaxFailNum=30 | sed '/^$/d'"
  30

  $ R "ba-cli -l ProcessMonitor.Test.$Tr181CellularManagerId.MaxFailNum=30 | sed '/^$/d'"
  30

Kill the processes and wait - Frist kill attempt:

  $ for process_name in "tr181-mcastd" "tr181-pcp" "tr181-qos" \
  > "cellular-manager"; do R "${S} && kill_process \"$process_name\""; done

  $ sleep 14

Get the Process ID and verify all expected process are running:

  $ for process_name in "tr181-mcastd" "tr181-pcp" "tr181-qos" \
  > "cellular-manager"; do R "${S} && get_pid \"$process_name\""; done
  tr181-mcastd.* \d+ (re)
  tr181-pcp.* \d+ (re)
  tr181-qos.* \d+ (re)
  cellular-manager.* \d+ (re)

Verify amx-processmonitoring has updated the NumProcessRespawn after process respawn:

  $  R "${S} && verify_respawn_value $Tr181McastdId $((Tr181McastdMaxRespawn+1))"
  tr181-mcastd NumProcessRespawn PASS

  $ R "${S} && verify_respawn_value $Tr181PcpId $((Tr181PcpRespawn+1))"
  tr181-pcp NumProcessRespawn PASS

  $ R "${S} && verify_respawn_value $Tr181QosId $((Tr181QosRespawn+1))"
  tr181-qos NumProcessRespawn PASS

  $ R "${S} && verify_respawn_value $Tr181CellularManagerId $((Tr181CellularManagerRespawn+1))"
  cellular-manager NumProcessRespawn PASS

Stop start all the process:

  $ R "service tr181-mcastd stop > /dev/null 2>&1"

  $ R "service tr181-mcastd start > /dev/null 2>&1"

  $ R "service tr181-pcp stop  > /dev/null 2>&1"

  $ R "service tr181-pcp start  > /dev/null 2>&1"

  $ R "service tr181-qos stop  > /dev/null 2>&1"

  $ R "service tr181-qos start  > /dev/null 2>&1"

  $ R "service cellular-manager stop > /dev/null 2>&1"

  $ R "service cellular-manager start > /dev/null 2>&1"

Wait for the processes to come up:

  $ sleep 5

Get the Process ID and verify all expected process are running:

  $ for process_name in "tr181-mcastd" "tr181-pcp" "tr181-qos" \
  > "cellular-manager"; do R "${S} && get_pid \"$process_name\""; done
  tr181-mcastd.* \d+ (re)
  tr181-pcp.* \d+ (re)
  tr181-qos.* \d+ (re)
  cellular-manager.* \d+ (re)

Verify amx-process monitor has reset NumProcessRespawn to 0:

  $  R "${S} && verify_respawn_value $Tr181McastdId 0"
  tr181-mcastd NumProcessRespawn PASS

  $ R "${S} && verify_respawn_value $Tr181PcpId 0"
  tr181-pcp NumProcessRespawn PASS

  $ R "${S} && verify_respawn_value $Tr181QosId 0"
  tr181-qos NumProcessRespawn PASS

  $ R "${S} && verify_respawn_value $Tr181CellularManagerId 0"
  cellular-manager NumProcessRespawn PASS

Revert ProcessMonitor.Test.i TestInterval:

  $ R "${S} && set_test_interval $Tr181McastdTestInterval $Tr181McastdId"
  $ R "${S} && set_test_interval $Tr181PcpTestInterval $Tr181PcpId"
  $ R "${S} && set_test_interval $Tr181QosTestInterval $Tr181QosId"
  $ R "${S} && set_test_interval $Tr181CellularManagerTestInterval $Tr181CellularManagerId"

Clean-up, Revert MaxFail parameter for the process to initial value:

  $ R "ba-cli -l  ProcessMonitor.Test.$Tr181McastdId.MaxFailNum=$Tr181McastdMaxFail | sed '/^$/d'"
  \d+ (re)

  $ R "ba-cli -l ProcessMonitor.Test.$Tr181PcpId.MaxFailNum=$Tr181PcpMaxFail | sed '/^$/d'"
  \d+ (re)

  $ R "ba-cli -l ProcessMonitor.Test.$Tr181QosId.MaxFailNum=$Tr181QosMaxFail | sed '/^$/d'"
  \d+ (re)

  $ R "ba-cli -l ProcessMonitor.Test.$Tr181CellularManagerId.MaxFailNum=$Tr181CellularManagerMaxFail | sed '/^$/d'"
  \d+ (re)

  $ R logger -t cram "Amx-processmonitoring respawn attribute reset test finished"
