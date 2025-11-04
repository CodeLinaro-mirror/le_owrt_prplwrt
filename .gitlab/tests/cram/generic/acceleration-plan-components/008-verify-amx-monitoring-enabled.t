Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t "Starting with amx-processmonitoring enable test"

This Helper method finds the Instance Id and return the ProcessMonitoringEnabled parameter, #Param1 - name of the process:

  $ get_amx_process_monitoring() { InstanceId=$(R "ba-cli  " \
  > "ProcessMonitor.Test.*.Name? | grep $1 | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'"); \
  > amx_enable=$(R "ba-cli -l ProcessMonitor.Test.$InstanceId.ProcessMonitoringEnabled? | sed '/^$/d'"); \
  > echo "$1=$amx_enable";}

Verify all expected processes are enabled for monitoring by amx-processmonitor, value of 1 specifies enabled for monitoring:

  $ for process in tr181-device tr181-pcp tr181-firewall tr181-qos tr181-mcastd; do get_amx_process_monitoring  $process; done
  tr181-device=1
  tr181-pcp=1
  tr181-firewall=1
  tr181-qos=1
  tr181-mcastd=1

  $ for process in tr181-mqttbroker tr181-bridging tr181-ppp tr181-dns tr181-xpon; do get_amx_process_monitoring  $process; done
  tr181-mqttbroker=1
  tr181-bridging=1
  tr181-ppp=1
  tr181-dns=1
  tr181-xpon=1

  $ for process in deviceinfo-manager tr181-dns gmap-server cwmp_plugin reboot-service; do get_amx_process_monitoring  $process; done
  deviceinfo-manager=1
  tr181-dns=1
  gmap-server=1
  cwmp_plugin=1
  reboot-service=1

  $ for process in odhcpd hosts-manager dhcpv4-manager; do get_amx_process_monitoring  $process; done
  odhcpd=1
  hosts-manager=1
  dhcpv4-manager=1

  $ if echo "$CI_JOB_NAME" | grep -q -E "(Mozart|Turris|Haze|HDK-3)"; then exit 80; fi

  $ get_amx_process_monitoring cellular-manager
  cellular-manager=1