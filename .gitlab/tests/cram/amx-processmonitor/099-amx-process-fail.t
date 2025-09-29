Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting amx-processmonitor cram test-1"

Helper Methods
This method kills a process, Param#1 - Name of the process to kill
  $ kill_process() { R "pkill -f $1";}

This method gets the PID of the process
  $ get_pid() { R "pgrep -f $1";}

Read Initial Process ProcessMonitor.Test
  $ InitialInstance=$(R "ba-cli  ProcessMonitor.Test.? | sed '/^$/d'")
  $ R logger -t cram 'Initial read of Process.Monitor $InitialInstance'

This method verifies increment of NumProcessRespawn with previous value for process respawn, Param#1 - ProcessMonitor Instance Id of the process, Param#2 - Expected NumProcessRespawn value
  $ verify_respawn_increment() { respawn=$(R "ba-cli -l ProcessMonitor.Test.$1.NumProcessRespawn? | sed '/^$/d'"); if [ $respawn -eq $2 ]; then echo PASS; else echo "FAIL Expected ProcessMonitor.Test.$1.NumProcessRespawn value: $2 found: $respawn"; fi;}

This method verifies expected  NumProcessFail value attribute of ProcessMonitor.Test, Param#1 - ProcessMonitor Instance Id, Param#2 expected value of NumProcessFail
  $ verify_num_Process_fail() { num_process_fail=$(R "ba-cli -l ProcessMonitor.Test.$1.NumProcessFail? | sed '/^$/d'"); if [ $num_process_fail -eq $2 ]; then echo PASS; else echo "Fail Expected value for ProcessMonitor.Test.$1.NumProcessFail: $2, found: $num_process_fail"; fi;}

Pre-test actions, Restart the process service to clear the respawns and other failures before starting with tests
  $ R "service tr181-mqttbroker restart  > /dev/null 2>&1 && service tr181-pcp restart  > /dev/null 2>&1 && service deviceinfo-manager restart  > /dev/null 2>&1 && service wan-manager restart > /dev/null 2>&1 && service dhcpv4-manager restart  > /dev/null 2>&1"

Wait 15 seconds for the process to become functional
  $ sleep 15

Initialize the ProcessMonitor.Test.i Id for required processes
  $ Tr181MqttbrokerId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep tr181-mqttbroker | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")
  $ Tr181PcpId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep tr181-pcp | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")
  $ DeviceinfoManagerId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep deviceinfo-manager | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")
  $ WanManagerId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep wan-manager | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")
  $ Dhcpv4ManagerId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep dhcpv4-manager | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")

Get the initial NumProcessRespawn for all the process
  $ Tr181MqttbrokerRespawn=$(R "ba-cli -l ProcessMonitor.Test.$Tr181MqttbrokerId.NumProcessRespawn? | sed '/^$/d'")
  $ Tr181PcpRespawn=$(R "ba-cli -l ProcessMonitor.Test.$Tr181PcpId.NumProcessRespawn? | sed '/^$/d'")
  $ DeviceinfoManagerRespawn=$(R "ba-cli -l ProcessMonitor.Test.$DeviceinfoManagerId.NumProcessRespawn? | sed '/^$/d'")
  $ WanManagerRespawn=$(R "ba-cli -l ProcessMonitor.Test.$WanManagerId.NumProcessRespawn? | sed '/^$/d'")
  $ Dhcpv4ManagerRespawn=$(R "ba-cli -l ProcessMonitor.Test.$Dhcpv4ManagerId.NumProcessRespawn? | sed '/^$/d'")

Get the initial NumProcessFail for all the process
  $ Tr181MqttbrokerFail=$(R "ba-cli -l ProcessMonitor.Test.$Tr181MqttbrokerId.NumProcessFail? | sed '/^$/d'")
  $ Tr181PcpFail=$(R "ba-cli -l ProcessMonitor.Test.$Tr181PcpId.NumProcessFail? | sed '/^$/d'")
  $ DeviceinfoManagerFail=$(R "ba-cli -l ProcessMonitor.Test.$DeviceinfoManagerId.NumProcessFail? | sed '/^$/d'")
  $ WanManagerFail=$(R "ba-cli -l ProcessMonitor.Test.$WanManagerId.NumProcessFail? | sed '/^$/d'")
  $ Dhcpv4ManagerFail=$(R "ba-cli -l ProcessMonitor.Test.$Dhcpv4ManagerId.NumProcessFail? | sed '/^$/d'")

Get the initial MaxFailNum for all the process
  $ Tr181MqttbrokerMaxFail=$(R "ba-cli -l ProcessMonitor.Test.$Tr181MqttbrokerId.MaxFailNum? | sed '/^$/d'")
  $ Tr181PcpMaxFail=$(R "ba-cli -l ProcessMonitor.Test.$Tr181PcpId.MaxFailNum? | sed '/^$/d'")
  $ DeviceinfoManagerMaxFail=$(R "ba-cli -l ProcessMonitor.Test.$DeviceinfoManagerId.MaxFailNum? | sed '/^$/d'")
  $ WanManagerMaxFail=$(R "ba-cli -l ProcessMonitor.Test.$WanManagerId.MaxFailNum? | sed '/^$/d'")
  $ Dhcpv4ManagerMaxFail=$(R "ba-cli -l ProcessMonitor.Test.$Dhcpv4ManagerId.MaxFailNum? | sed '/^$/d'")

Get the Process ID and verify all expected process are running
  $ for process_name in tr181-mqttbroker tr181-pcp deviceinfo-manager wan-manager dhcpv4-manager; do get_pid $process_name ; done
  \d+ (re)
  \d+ (re)
  \d+ (re)
  \d+ (re)
  \d+ (re)

Change MaxFail parameter for the processes to higher value
  $ R "ba-cli -l  ProcessMonitor.Test.$Tr181MqttbrokerId.MaxFailNum=30 | sed '/^$/d'"
  30
  $ R "ba-cli -l ProcessMonitor.Test.$Tr181PcpId.MaxFailNum=30 | sed '/^$/d'"
  30
  $ R "ba-cli -l ProcessMonitor.Test.$DeviceinfoManagerId.MaxFailNum=30 | sed '/^$/d'"
  30
  $ R "ba-cli -l ProcessMonitor.Test.$WanManagerId.MaxFailNum=30 | sed '/^$/d'"
  30
  $ R "ba-cli -l ProcessMonitor.Test.$Dhcpv4ManagerId.MaxFailNum=30 | sed '/^$/d'"
  30

Kill the processes and wait for respawn - Frist kill attempt
  $ for process_name in tr181-mqttbroker tr181-pcp deviceinfo-manager wan-manager dhcpv4-manager; do kill_process $process_name; done
  $ sleep 15

  $ for process_name in tr181-mqttbroker tr181-pcp deviceinfo-manager wan-manager dhcpv4-manager; do get_pid $process_name ; done
  \d+ (re)
  \d+ (re)
  \d+ (re)
  \d+ (re)
  \d+ (re)

Kill the processes - Second kill attempt
  $ for process_name in tr181-mqttbroker tr181-pcp deviceinfo-manager wan-manager dhcpv4-manager; do kill_process $process_name; done
  $ sleep 15

Kill the processes - third kill attempt
  $ for process_name in tr181-mqttbroker tr181-pcp deviceinfo-manager wan-manager dhcpv4-manager; do kill_process $process_name; done
  $ sleep 15

Kill the processes - Fourth kill attempt, no more respawns of failed process by procd and NumProcessFail will increment
  $ for process_name in tr181-mqttbroker tr181-pcp deviceinfo-manager wan-manager dhcpv4-manager; do kill_process $process_name; done
  $ sleep 15

Verify NumProcessFail is incremented for process fail
  $ verify_num_Process_fail $Tr181MqttbrokerId $((Tr181MqttbrokerFail+1))
  PASS

  $ verify_num_Process_fail $Tr181PcpId $((Tr181PcpFail+1))
  PASS

  $ verify_num_Process_fail $DeviceinfoManagerId $((DeviceinfoManagerFail+1))
  PASS

  $ verify_num_Process_fail $WanManagerId $((WanManagerFail+1))
  PASS

  $ verify_num_Process_fail $Dhcpv4ManagerId $((Dhcpv4ManagerFail+1))
  PASS

Verify amx-process monitor has updated the NumProcessRespawn after process respawn for all kill attempts above
  $ verify_respawn_increment $Tr181MqttbrokerId $((Tr181MqttbrokerRespawn+3))
  PASS

  $ verify_respawn_increment $Tr181PcpId $((Tr181PcpRespawn+3))
  PASS

  $ verify_respawn_increment $DeviceinfoManagerId $((DeviceinfoManagerRespawn+3))
  PASS

  $ verify_respawn_increment $WanManagerId $((WanManagerRespawn+3))
  PASS

  $ verify_respawn_increment $Dhcpv4ManagerId $((Dhcpv4ManagerRespawn+3))
  PASS

Clean-up Revert MaxFail parameter for the process to initial value
  $ R "ba-cli -l  ProcessMonitor.Test.$Tr181MqttbrokerId.MaxFailNum=$Tr181MqttbrokerMaxFail | sed '/^$/d'"
  \d+ (re)
  $ R "ba-cli -l ProcessMonitor.Test.$Tr181PcpId.MaxFailNum=$Tr181PcpMaxFail | sed '/^$/d'"
  \d+ (re)
  $ R "ba-cli -l ProcessMonitor.Test.$DeviceinfoManagerId.MaxFailNum=$DeviceinfoManagerMaxFail | sed '/^$/d'"
  \d+ (re)
  $ R "ba-cli -l ProcessMonitor.Test.$WanManagerId.MaxFailNum=$WanManagerMaxFail | sed '/^$/d'"
  \d+ (re)
  $ R "ba-cli -l ProcessMonitor.Test.$Dhcpv4ManagerId.MaxFailNum=$Dhcpv4ManagerMaxFail | sed '/^$/d'"
  \d+ (re)

Restart process service to clear the respawns from above tests
  $ R "service tr181-mqttbroker restart  > /dev/null 2>&1 && service tr181-pcp restart  > /dev/null 2>&1 && service deviceinfo-manager restart  > /dev/null 2>&1 && service wan-manager restart > /dev/null 2>&1 && service dhcpv4-manager restart  > /dev/null 2>&1"

Wait 15 seconds for the process to turn functional
  $ sleep 15

  $ R logger -t cram "Tests finished!"

