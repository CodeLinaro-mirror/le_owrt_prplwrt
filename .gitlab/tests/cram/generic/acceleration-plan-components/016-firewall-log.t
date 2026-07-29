Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Create a dedicated LAN service and a log entry referencing it, using the
nested Firewall.Log.{i}.Filter.* object and Severity parameter (Filter and
Severity replace the former flat FilterPolicy/FilterSourceInterface/
FilterDestinationInterface and Level parameters):

  $ printf "\
  > ba-cli Firewall.Log+{Alias='test-log', Prefix='TESTLOG', Severity='Warning', Enable=1}
  > ba-cli Firewall.Service+{Alias='test-log-svc'}
  > ba-cli Firewall.Service.test-log-svc.Interface='Device.IP.Interface.3'
  > ba-cli Firewall.Service.test-log-svc.DestPort=8079
  > ba-cli Firewall.Service.test-log-svc.Protocol='6'
  > ba-cli Firewall.Service.test-log-svc.Action=Accept
  > ba-cli Firewall.Service.test-log-svc.LogRef='Firewall.Log.test-log'
  > ba-cli Firewall.Service.test-log-svc.Log=1
  > ba-cli Firewall.Service.test-log-svc.Enable=1
  > " > /tmp/cram
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/cram)'" > /dev/null; sleep 1

Check that a LOG rule was created for the service, using the Severity
("Warning" -> syslog level 4) and Prefix ("TESTLOG") of the log entry:

  $ R "iptables -L INPUT_Services -n | grep -c 'LOG.*dpt:8079.*level 4.*prefix .\[FW\]\[TESTLOG\]:.'"
  1

Check that the ACCEPT rule for the service is still present next to the LOG rule:

  $ R "iptables -L INPUT_Services -n | grep -c 'ACCEPT.*dpt:8079'"
  1

Disable the log entry and check that the LOG rule is removed while the
service keeps working:

  $ script --command "ssh -t root@$TARGET_LAN_IP ba-cli Firewall.Log.test-log.Enable=0" > /dev/null; sleep 1
  $ R "iptables -L INPUT_Services -n | grep -c 'LOG.*dpt:8079'"
  0
  [1]
  $ R "iptables -L INPUT_Services -n | grep -c 'ACCEPT.*dpt:8079'"
  1

Re-enable the log entry but restrict Filter.Policy to Denied traffic only;
since the service Action is Accept, the entry must no longer match:

  $ printf "\
  > ba-cli Firewall.Log.test-log.Enable=1
  > ba-cli Firewall.Log.test-log.Filter.Policy=Denied
  > " > /tmp/cram
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/cram)'" > /dev/null; sleep 1
  $ R "iptables -L INPUT_Services -n | grep -c 'LOG.*dpt:8079'"
  0
  [1]

Set Filter.Policy back to Allowed and check that the LOG rule reappears:

  $ script --command "ssh -t root@$TARGET_LAN_IP ba-cli Firewall.Log.test-log.Filter.Policy=Allowed" > /dev/null; sleep 1
  $ R "iptables -L INPUT_Services -n | grep -c 'LOG.*dpt:8079.*level 4.*prefix .\[FW\]\[TESTLOG\]:.'"
  1

Remove the service and log entry:

  $ script --command "ssh -t root@$TARGET_LAN_IP ba-cli Firewall.Service.test-log-svc-" > /dev/null
  $ script --command "ssh -t root@$TARGET_LAN_IP ba-cli Firewall.Log.test-log-" > /dev/null
