Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t "Starting with amx-processmonitor cram test-2"

Helper method
This method find the Instance Id and return the ProcessMonitoringEnabled parameter, #Param1 - name of the process
  $ get_amx_process_monitoring() { InstanceId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep $1 | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'"); R "ba-cli -l ProcessMonitor.Test.$InstanceId.ProcessMonitoringEnabled? | sed '/^$/d'";}

Verify expected processes are enabled for monitoring by amx-processmonitor, value of 1 specifies enabled for monitoring
  $ for process in tr181-device tr181-pcp tr181-firewall tr181-qos tr181-mcastd; do get_amx_process_monitoring  $process; done
  1
  1
  1
  1
  1

  $ for process in tr181-mqttbroker tr181-bridging tr181-ppp tr181-dns tr181-xpon; do get_amx_process_monitoring  $process; done
  1
  1
  1
  1
  1

  $ for process in deviceinfo-manager tr181-dns gmap-server tr069-manager reboot-service; do get_amx_process_monitoring  $process; done
  1
  1
  1
  1
  1

  $ for process in odhcpd hosts-manager cellular-manager moca-manager dhcpv4-manager; do get_amx_process_monitoring  $process; done
  1
  1
  1
  1
  1

