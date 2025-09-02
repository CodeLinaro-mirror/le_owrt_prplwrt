Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting amx-processmonitor cram test-4"

Helper Methods
This method kills a process, Param#1 - Name of the process to kill
  $ kill_process() { R "pkill -f $1";}

This method gets the PID of the process
  $ get_pid() { R "pgrep -f $1 ";}

Read Initial Process ProcessMonitor.Test
  $ InitialInstance=$(R "ba-cli  ProcessMonitor.Test.? | sed '/^$/d'")
  $ R logger -t cram 'Initial read of Process.Monitor $InitialInstance'

This method verifies update to MaxFailedDuration, MaxNumFailed and increment of NumProcessRespawn for process, Param#1 - ProcessMonitor Instance Id of the process, Param#2 - expected NumProcessRespawn value (used only for NumProcessRespawn attribute)
  $ verify_process_fail_update() { respawn=$(R "ba-cli -l ProcessMonitor.Test.$1.NumProcessRespawn? | sed '/^$/d'"); if [ $respawn -eq $2 ]; then echo PASS; else echo "FAIL expected ProcessMonitor.Test.$1.NumProcessRespawn value: $2 found: $respawn"; fi; MaxNumFailed=$(R "ba-cli -l ProcessMonitor.Test.$1.MaxNumFailed? | sed '/^$/d'"); if [ $MaxNumFailed -eq 0 ]; then echo "FAIL Expected ProcessMonitor.Test.$1.MaxNumFailed to be updated but found $MaxNumFailed"; else echo "PASS"; fi; MaxFailedDuration=$(R "ba-cli -l ProcessMonitor.Test.$1.MaxFailedDuration? | sed '/^$/d'"); if [ $MaxFailedDuration -eq 0 ]; then echo "FAIL Expected ProcessMonitor.Test.$1.MaxFailedDuration to be updated but found $MaxFailedDuration"; else echo "PASS"; fi; }

This method verifies reset of amx-processmonitor values to default values, Param#1 - ProcessMonitor Instance Id of the process
  $ verify_value_reset() { ProcessMonitoringEnabled=$(R "ba-cli -l ProcessMonitor.Test.$1.ProcessMonitoringEnabled? | sed '/^$/d'"); if [ $ProcessMonitoringEnabled -eq 1 ]; then echo PASS; else echo "FAIL ProcessMonitor.Test.$1.ProcessMonitoringEnabled - $ProcessMonitoringEnabled not enabled after reset"; fi; LastFailReason=$(R "ba-cli -l ProcessMonitor.Test.$1.LastFailReason? | sed '/^$/d'"); if [ "$LastFailReason" = "Error_None" ]; then echo PASS; else echo "FAIL ProcessMonitor.Test.$1.LastFailReason - $LastFailReason not reset"; fi; MaxFailedDuration=$(R "ba-cli -l ProcessMonitor.Test.$1.MaxFailedDuration? | sed '/^$/d'"); if [ $MaxFailedDuration -eq 0 ]; then echo PASS; else echo "FAIL ProcessMonitor.Test.$1.MaxFailedDuration - $MaxFailedDuration not reset"; fi; MaxNumFailed=$(R "ba-cli -l ProcessMonitor.Test.$1.MaxNumFailed? | sed '/^$/d'"); if [ $MaxNumFailed -eq 0 ]; then echo PASS; else echo "FAIL ProcessMonitor.Test.$1.MaxNumFailed - $MaxNumFailed not reset"; fi; NumProcessFail=$(R "ba-cli -l ProcessMonitor.Test.$1.NumProcessFail? | sed '/^$/d'"); if [ $NumProcessFail -eq 0 ]; then echo PASS; else echo "FAIL ProcessMonitor.Test.$1.NumProcessFail - $NumProcessFail not reset"; fi; NumProcessRespawn=$(R "ba-cli -l ProcessMonitor.Test.$1.NumProcessRespawn? | sed '/^$/d'"); if [ $NumProcessRespawn -eq 0 ]; then echo PASS; else echo "FAIL ProcessMonitor.Test.$1.NumProcessRespawn - $NumProcessRespawn not reset"; fi;}

This method changes the subject attribute of amx-processmonitor, Param#1 - ProcessMonitor Instance Id of the process
  $ change_process_subject() { R "ba-cli -l ProcessMonitor.Test.$1.Subject=\"test_subject_$1\" | sed '/^$/d'" ; }

Initialize the ProcessMonitor.Test.i Id for required processes
  $ Tr181MqttbrokerId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep tr181-mqttbroker | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")
  $ Tr181PcpId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep tr181-pcp | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")
  $ DeviceinfoManagerId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep deviceinfo-manager | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")
  $ WanManagerId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep wan-manager | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")
  $ Dhcpv4ManagerId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep dhcpv4-manager | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")

Pre-test actions to clear attributes from other testcases.
Restart the services, to reset respawn parameters
  $ R "service tr181-mqttbroker restart"

  $ R "service tr181-pcp restart"

  $ R "service deviceinfo-manager restart"

  $ R "service wan-manager restart"

  $ R "service dhcpv4-manager restart"

Wait 5 seconds for the process to come up
  $ sleep 5

Change subject of processes amx-processmonitor to reset previous attributes.
  $ for process_id in $Tr181MqttbrokerId $Tr181PcpId $DeviceinfoManagerId $WanManagerId $Dhcpv4ManagerId; do change_process_subject $process_id ; done
  test_subject_\d+ (re)
  test_subject_\d+ (re)
  test_subject_\d+ (re)
  test_subject_\d+ (re)
  test_subject_\d+ (re)

Wait 245 seconds (with few more seconds) for amx-process monitoring status to turn good
  $ sleep 245

Get the initial NumProcessRespawn for all the process
  $ Tr181MqttbrokerRespawn=$(R "ba-cli -l ProcessMonitor.Test.$Tr181MqttbrokerId.NumProcessRespawn? | sed '/^$/d'")
  $ Tr181PcpRespawn=$(R "ba-cli -l ProcessMonitor.Test.$Tr181PcpId.NumProcessRespawn? | sed '/^$/d'")
  $ DeviceinfoManagerRespawn=$(R "ba-cli -l ProcessMonitor.Test.$DeviceinfoManagerId.NumProcessRespawn? | sed '/^$/d'")
  $ WanManagerRespawn=$(R "ba-cli -l ProcessMonitor.Test.$WanManagerId.NumProcessRespawn? | sed '/^$/d'")
  $ Dhcpv4ManagerRespawn=$(R "ba-cli -l ProcessMonitor.Test.$Dhcpv4ManagerId.NumProcessRespawn? | sed '/^$/d'")

Get the initial MaxFailNum for all the process
  $ Tr181MqttbrokerMaxFail=$(R "ba-cli -l ProcessMonitor.Test.$Tr181MqttbrokerId.MaxFailNum? | sed '/^$/d'")
  $ Tr181PcpMaxFail=$(R "ba-cli -l ProcessMonitor.Test.$Tr181PcpId.MaxFailNum? | sed '/^$/d'")
  $ DeviceinfoManagerMaxFail=$(R "ba-cli -l ProcessMonitor.Test.$DeviceinfoManagerId.MaxFailNum? | sed '/^$/d'")
  $ WanManagerMaxFail=$(R "ba-cli -l ProcessMonitor.Test.$WanManagerId.MaxFailNum? | sed '/^$/d'")
  $ Dhcpv4ManagerMaxFail=$(R "ba-cli -l ProcessMonitor.Test.$Dhcpv4ManagerId.MaxFailNum? | sed '/^$/d'")

Get the Process ID and verify all expected process are running
  $ for process_name in tr181-mqttbroker tr181-pcp deviceinfo-manager wan-manager dhcpv4-manager; do get_pid $process_name; done
  \d+ (re)
  \d+ (re)
  \d+ (re)
  \d+ (re)
  \d+ (re)

Kill the processes - Frist kill attempt
  $ for process_name in tr181-mqttbroker tr181-pcp deviceinfo-manager wan-manager dhcpv4-manager; do kill_process $process_name; done

Wait for procd to respawn the processes, 5 seconds(with few more seconds) - default retry timeout for respawn and verify process respawn
  $ sleep 7

  $ for process_name in tr181-mqttbroker tr181-pcp deviceinfo-manager wan-manager dhcpv4-manager; do get_pid $process_name ; done
  \d+ (re)
  \d+ (re)
  \d+ (re)
  \d+ (re)
  \d+ (re)

Kill the processes - Second kill attempt
  $ for process_name in tr181-mqttbroker tr181-pcp deviceinfo-manager wan-manager dhcpv4-manager; do kill_process $process_name; done

Wait for procd to respawn the processes, 5 seconds(with few more seconds) - default retry timeout for respawn and verify process respawn
  $ sleep 7

  $ for process_name in tr181-mqttbroker tr181-pcp deviceinfo-manager wan-manager dhcpv4-manager; do get_pid $process_name ; done
  \d+ (re)
  \d+ (re)
  \d+ (re)
  \d+ (re)
  \d+ (re)

Wait 245 seconds (with few more seconds) for amx-process monitoring status to turn good
  $ sleep 245

Verify amx-process monitor has updated the MaxFailedDuration, MaxNumFailed and NumProcessRespawn after process respawn
  $ verify_process_fail_update $Tr181MqttbrokerId $((Tr181MqttbrokerRespawn+2))
  PASS
  PASS
  PASS

  $ verify_process_fail_update $Tr181PcpId $((Tr181PcpRespawn+2))
  PASS
  PASS
  PASS

  $ verify_process_fail_update $DeviceinfoManagerId $((DeviceinfoManagerRespawn+2))
  PASS
  PASS
  PASS

  $ verify_process_fail_update $WanManagerId $((WanManagerRespawn+2))
  PASS
  PASS
  PASS

  $ verify_process_fail_update $Dhcpv4ManagerId $((Dhcpv4ManagerRespawn+2))
  PASS
  PASS
  PASS

Change test subject of amx-processmonitor and verify process monitoring parameters are reset.
  $ for process_id in $Tr181MqttbrokerId $Tr181PcpId $DeviceinfoManagerId $WanManagerId $Dhcpv4ManagerId; do change_process_subject $process_id; done
  test_subject_\d+ (re)
  test_subject_\d+ (re)
  test_subject_\d+ (re)
  test_subject_\d+ (re)
  test_subject_\d+ (re)

Wait 245 seconds for amx-process monitoring status to turn good
  $ sleep 245

Verify processes are UP and running
  $ for process_name in tr181-mqttbroker tr181-pcp deviceinfo-manager wan-manager dhcpv4-manager; do get_pid $process_name ; done
  \d+ (re)
  \d+ (re)
  \d+ (re)
  \d+ (re)
  \d+ (re)

Verify ProcessMonitoring parameter reset after calling reset method
  $ verify_value_reset $Tr181MqttbrokerId
  PASS
  PASS
  PASS
  PASS
  PASS
  PASS

  $ verify_value_reset $Tr181PcpId
  PASS
  PASS
  PASS
  PASS
  PASS
  PASS

  $ verify_value_reset $DeviceinfoManagerId
  PASS
  PASS
  PASS
  PASS
  PASS
  PASS

  $ verify_value_reset $WanManagerId
  PASS
  PASS
  PASS
  PASS
  PASS
  PASS

  $ verify_value_reset $Dhcpv4ManagerId
  PASS
  PASS
  PASS
  PASS
  PASS
  PASS

  $ R logger -t cram "Tests finished!"

