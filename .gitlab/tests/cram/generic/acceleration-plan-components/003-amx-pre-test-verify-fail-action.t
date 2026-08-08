Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ if [ "$DUT_BOARD" = "qemu-standard-pc-q35-ich9-2009" ]; then exit 80; fi

  $ R logger -t cram "Starting with amx-processmonitoring pre-checks"

Ensure ProcessMonitor.Test.i.FailAction does not have REBOOT action:

  $ R "ba-cli -l ProcessMonitor.Test.*.FailAction\? | "\
  > "grep -vE '(RESTART|NONE)' | sed '/^$/d'"


Initialize the ProcessMonitor.Test.i Id for required processes:

  $ Tr181McastdId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep tr181-mcastd | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")
  $ Tr181PcpId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep tr181-pcp | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")
  $ Tr181QosId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep tr181-qos | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")
  $ Dhcpv4ManagerId=$(R "ba-cli  ProcessMonitor.Test.*.Name? | grep dhcpv4-manager | sed -n 's/.*Test\.\([0-9]\+\)\..*/\1/p'")

Ensure all previous NumFail params has been reset before starting the new cram on amx-processmonitor on all above PIds

  $ R "ba-cli 'ProcessMonitor.Test.tr181-mcastd.reset()' >/dev/null 2>&1"
  $ R "ba-cli 'ProcessMonitor.Test.tr181-pcp.reset()' >/dev/null 2>&1"
  $ R "ba-cli 'ProcessMonitor.Test.tr181-qos.reset()' >/dev/null 2>&1"
  $ R "ba-cli 'ProcessMonitor.Test.dhcpv4-manager.reset()'  >/dev/null 2>&1"

Verify any process monitoring failures observed before starting with tests:
Exclude prplmesh, wifi-sensing and pwhm checks till FEAT-27 is merged:
Exclude wifi-scheduler PPW-1679:

  $ R "grep \"amx-processmonitor: process - \[!\]Test.*failed too often,"\
  > " executing action\" /var/log/messages* /var/log/messagess.? 2>/dev/null" \
  > "| grep -vE '(prplmesh|wifi-sensing|wifi-scheduler|wld)' || true"

  $ R logger -t cram "Pre-checks for amx-processmonitoring tests completed"
