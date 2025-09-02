Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting amx-processmonitor cram test-3"

Helper Methods
This method kills a process, Param#1 - Name of the process to kill
  $ kill_process() { R "pkill -f $1";}

This method gets the PID of the process
  $ get_pid() { R "pgrep -f $1 ";}

Read Initial Process ProcessMonitor.Test
  $ InitialInstance=$(R "ba-cli  ProcessMonitor.Test.? | sed '/^$/d'")
  $ R logger -t cram 'Initial read of Process.Monitor $InitialInstance'

This method verifies increment of NumProcessRespawn with previous value for process respawn, Param#1 - ProcessMonitor Instance Id of the process, Param#2 - expected NumProcessRespawn value
  $ verify_respawn_value() { respawn=$(R "ba-cli -l ProcessMonitor.Test.$1.NumProcessRespawn? | sed '/^$/d'"); if [ $respawn -eq $2 ]; then echo PASS; else echo "FAIL expected ProcessMonitor.Test.$1.NumProcessRespawn value: $2 found: $respawn"; fi;}

Pre-test actions, Restart amx-processmonitor service to clear the respawns and other failures before starting with tests
  $ R "(/etc/init.d/amx-processmonitor restart) > /dev/null 2>&1"

Wait 60 seconds for the monitoring initialization
  $ sleep 60

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

Kill the processes and wait - Frist kill attempt
  $ for process_name in tr181-mqttbroker tr181-pcp deviceinfo-manager wan-manager dhcpv4-manager; do kill_process $process_name; done
  $ sleep 7

  $ for process_name in tr181-mqttbroker tr181-pcp deviceinfo-manager wan-manager dhcpv4-manager; do get_pid $process_name ; done
  \d+ (re)
  \d+ (re)
  \d+ (re)
  \d+ (re)
  \d+ (re)

Verify amx-process monitor has updated the NumProcessRespawn after process respawn
  $ verify_respawn_value $Tr181MqttbrokerId $((Tr181MqttbrokerRespawn+1))
  PASS

  $ verify_respawn_value $Tr181PcpId $((Tr181PcpRespawn+1))
  PASS

  $ verify_respawn_value $DeviceinfoManagerId $((DeviceinfoManagerRespawn+1))
  PASS

  $ verify_respawn_value $WanManagerId $((WanManagerRespawn+1))
  PASS

  $ verify_respawn_value $Dhcpv4ManagerId $((Dhcpv4ManagerRespawn+1))
  PASS

Kill the processes and wait - Second kill attempt
  $ for process_name in tr181-mqttbroker tr181-pcp deviceinfo-manager wan-manager dhcpv4-manager; do kill_process $process_name; done
  $ sleep 7

  $ for process_name in tr181-mqttbroker tr181-pcp deviceinfo-manager wan-manager dhcpv4-manager; do get_pid $process_name ; done
  \d+ (re)
  \d+ (re)
  \d+ (re)
  \d+ (re)
  \d+ (re)

Verify amx-process monitor has updated the NumProcessRespawn after process respawn
  $ verify_respawn_value $Tr181MqttbrokerId $((Tr181MqttbrokerRespawn+2))
  PASS

  $ verify_respawn_value $Tr181PcpId $((Tr181PcpRespawn+2))
  PASS

  $ verify_respawn_value $DeviceinfoManagerId $((DeviceinfoManagerRespawn+2))
  PASS

  $ verify_respawn_value $WanManagerId $((WanManagerRespawn+2))
  PASS

  $ verify_respawn_value $Dhcpv4ManagerId $((Dhcpv4ManagerRespawn+2))
  PASS

Stop all the process
  $ R "service tr181-mqttbroker stop"

  $ R "service tr181-pcp stop"

  $ R "service tr181-pcp stop"

  $ R "service deviceinfo-manager stop"

  $ R "service wan-manager stop"

  $ R "service dhcpv4-manager stop"

Start all the process
  $ R "service tr181-mqttbroker start"

  $ R "service tr181-pcp start"

  $ R "service tr181-pcp start"

  $ R "service deviceinfo-manager start"

  $ R "service wan-manager start"

  $ R "service dhcpv4-manager start"

Wait for the processes to come up
  $ sleep 5

  $ for process_name in tr181-mqttbroker tr181-pcp deviceinfo-manager wan-manager dhcpv4-manager; do get_pid $process_name ; done
  \d+ (re)
  \d+ (re)
  \d+ (re)
  \d+ (re)
  \d+ (re)

Verify amx-process monitor has reset NumProcessRespawn to 0
  $ verify_respawn_value $Tr181MqttbrokerId 0
  PASS

  $ verify_respawn_value $Tr181PcpId 0
  PASS

  $ verify_respawn_value $DeviceinfoManagerId 0
  PASS

  $ verify_respawn_value $WanManagerId 0
  PASS

  $ verify_respawn_value $Dhcpv4ManagerId 0
  PASS

Clean-up, Revert MaxFail parameter for the process to initial value
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

Restart amx-processmonitor service to clear the respawns from above tests
  $ R "(/etc/init.d/amx-processmonitor restart) > /dev/null 2>&1"

Wait 60 seconds for the monitoring to beign
  $ sleep 60

  $ R logger -t cram "Tests finished!"

