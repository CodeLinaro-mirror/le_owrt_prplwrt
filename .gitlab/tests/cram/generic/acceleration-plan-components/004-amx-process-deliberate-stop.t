Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ alias C="${CRAM_REMOTE_COPY:-}"

Set script parameters and copy the script to device:

  $ S=". /tmp/script_functions_amx.sh"

  $ C ${TESTDIR}/script_functions_amx.sh root@${TARGET_LAN_IP}:/tmp/script_functions_amx.sh
  Warning: Permanently added '*' (*) to the list of known hosts* (glob)

  $ R logger -t cram "Starting amx-processmonitoring deliberate stop test"

  $ set_pm_test_max_failnum() { SetStatus=$(R "ba-cli -l  'ProcessMonitor.Test.[Name==\"$1\"].MaxFailNum=$2' | "  \
  > "sed '/^$/d'"); echo "$1 MaxFailNum $SetStatus"; }

  $ verify_pm_test_fail_stats() { FailNum=$(R "ba-cli -l  'ProcessMonitor.Test.[Name==\"$1\"].NumFailed?' | " \
  > "sed '/^$/d'"); if [ ${FailNum} -eq 0 ];then echo "$1 NumFailed PASS"; \
  > else echo "$1 NumFailed Fail, Expected value: 0, found: ${FailNum}";fi; \
  > FailActionNum=$(R "ba-cli -l  'ProcessMonitor.Test.[Name==\"$1\"].NumFailActions?' | " \
  > "sed '/^$/d'"); if [ ${FailActionNum} -eq 0 ];then echo "$1 NumFailAction PASS"; \
  > else echo "$1 NumFailAction Fail, Expected value: 0, found: ${FailActionNum}";fi; }

  $ get_cur_test_interval() { curInterval=$(R "ba-cli -l  'ProcessMonitor.Test.[Name==\"$1\"].CurrentTestInterval?' | " \
  > "sed '/^$/d'"); if [ ${curInterval} -gt 0 ];then echo "$1 CurrentTestInterval $curInterval"; \
  > else echo "$1 CurrentTestInterval Failed, Not configured (0)";fi; }

Initialize the ProcessMonitor.Test.i Id for required processes:

  $ Tr181McastId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep tr181-mcastd | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")
  $ Tr181PcpId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep tr181-pcp | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")
  $ Tr181QosId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep tr181-qos | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")
  $ Dhcpv4ManagerId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep dhcpv4-manager | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")

Get the initial MaxFailNum for all the processes:

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

Change MaxFail parameter for the processes to 1:

  $ for process_name in "tr181-mcastd" "tr181-pcp"  "tr181-qos" "dhcpv4-manager"; \
  > do set_pm_test_max_failnum ${process_name} 1; done
  tr181-mcastd MaxFailNum 1
  tr181-pcp MaxFailNum 1
  tr181-qos MaxFailNum 1
  dhcpv4-manager MaxFailNum 1

Verify process not getting monitored by amx-processmonitor when deliberately shutdown made

  $ R "service tr181-mcastd stop  > /dev/null 2>&1"
  $ R "service tr181-pcp stop  > /dev/null 2>&1"
  $ R "service tr181-qos stop  > /dev/null 2>&1"
  $ R "service dhcpv4-manager stop  > /dev/null 2>&1"

  $ sleep 5

Verify NumFail/NumFailActions not incremented with deliberate stop service as expected

  $ for process_name in "tr181-mcastd" "tr181-pcp"  "tr181-qos" "dhcpv4-manager"; \
  > do verify_pm_test_fail_stats ${process_name}; done
  tr181-mcastd NumFailed PASS
  tr181-mcastd NumFailAction PASS
  tr181-pcp NumFailed PASS
  tr181-pcp NumFailAction PASS
  tr181-qos NumFailed PASS
  tr181-qos NumFailAction PASS
  dhcpv4-manager NumFailed PASS
  dhcpv4-manager NumFailAction PASS

  $ R "service tr181-mcastd start  > /dev/null 2>&1"
  $ R "service tr181-pcp start  > /dev/null 2>&1"
  $ R "service tr181-qos start  > /dev/null 2>&1"
  $ R "service dhcpv4-manager start  > /dev/null 2>&1"

  $ sleep 5

Verify CurrentTestInterval configured back once processes are started back

  $ for process_name in "tr181-mcastd" "tr181-pcp"  "tr181-qos" "dhcpv4-manager"; \
  > do get_cur_test_interval ${process_name}; done
  tr181-mcastd CurrentTestInterval [1-9][0-9]* (re)
  tr181-pcp CurrentTestInterval [1-9][0-9]* (re)
  tr181-qos CurrentTestInterval [1-9][0-9]* (re)
  dhcpv4-manager CurrentTestInterval [1-9][0-9]* (re)

Clean-up Revert MaxFail parameter for the process to initial value:

  $ R "ba-cli -l  ProcessMonitor.Test.$Tr181McastId.MaxFailNum=$Tr181McastMaxFail | sed '/^$/d'"
  \d+ (re)

  $ R "ba-cli -l ProcessMonitor.Test.$Tr181PcpId.MaxFailNum=$Tr181PcpMaxFail | sed '/^$/d'"
  \d+ (re)

  $ R "ba-cli -l ProcessMonitor.Test.$Tr181QosId.MaxFailNum=$Tr181QosMaxFail | sed '/^$/d'"
  \d+ (re)

  $ R "ba-cli -l ProcessMonitor.Test.$Dhcpv4ManagerId.MaxFailNum=$Dhcpv4ManagerMaxFail | sed '/^$/d'"
  \d+ (re)

  $ R logger -t cram "Amx-processmonitoring process deliberate stop test finished"
