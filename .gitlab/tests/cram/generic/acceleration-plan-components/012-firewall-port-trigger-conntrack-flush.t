Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Configure port trigger rule with TCP on both trigger and mapped port:

  $ printf "\
  > ba-cli 'NAT.PortTrigger+{Alias=\"ct-pt-test\"}'
  > ba-cli 'NAT.PortTrigger.ct-pt-test.Port=6000'
  > ba-cli 'NAT.PortTrigger.ct-pt-test.Protocol=\"TCP\"'
  > ba-cli 'NAT.PortTrigger.ct-pt-test.AutoDisableDuration=300'
  > ba-cli 'NAT.PortTrigger.ct-pt-test.Rule+{Alias=\"ct-pt-rule\"}'
  > ba-cli 'NAT.PortTrigger.ct-pt-test.Rule.ct-pt-rule.Port=8000'
  > ba-cli 'NAT.PortTrigger.ct-pt-test.Rule.ct-pt-rule.Protocol=\"TCP\"'
  > ba-cli 'NAT.PortTrigger.ct-pt-test.Enable=1'
  > " > /tmp/cram
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/cram)'" > /dev/null; sleep 1

Check that NFQUEUE rule is present on trigger port 6000:

  $ R "iptables -L FORWARD_PortTrigger -n | grep 6000 | wc -l"
  1

Add route for outbound TCP trigger:

  $ sudo ip route add 10.10.10.10/32 via $TARGET_LAN_IP dev $TESTBED_LAN_INTERFACE 2>/dev/null; true

Trigger port trigger rule on port 6000:

  $ curl --silent --output /dev/null --max-time 2 http://10.10.10.10:6000; sleep 2

Check that inbound rules for port 8000 were dynamically created:

  $ R "iptables -L FORWARD_PortTrigger -n | grep 8000 | wc -l"
  2

Establish TCP connection on port 8000 to create conntrack entry:

  $ nc -l -p 8000 -s $TARGET_LAN_TEST_HOST > /dev/null 2>&1 &
  $ sleep 1
  $ timeout 15 nc -s $TESTBED_WAN_IP $TARGET_WAN_IP 8000 > /dev/null 2>&1 &
  $ sleep 2

Verify TCP conntrack entry is present:

  $ R "conntrack -L -p tcp --dport 8000 2>/dev/null | wc -l"
  1

Kill nc and delete port trigger:

  $ pkill -f 'nc.*8000' 2>/dev/null; sleep 1
  $ script --command "ssh -t root@$TARGET_LAN_IP 'ba-cli \"NAT.PortTrigger.ct-pt-test-\"'" > /dev/null; sleep 2

Check that FORWARD_PortTrigger rules for port 8000 are gone:

  $ R "iptables -L FORWARD_PortTrigger -n | grep 8000 | wc -l"
  0

Verify conntrack entry was flushed after port trigger deletion:

  $ R "conntrack -L -p tcp --dport 8000 2>/dev/null | wc -l"
  0

Configure port trigger again to verify conntrack flush on disable:

  $ printf "\
  > ba-cli 'NAT.PortTrigger+{Alias=\"ct-pt-test2\"}'
  > ba-cli 'NAT.PortTrigger.ct-pt-test2.Port=6000'
  > ba-cli 'NAT.PortTrigger.ct-pt-test2.Protocol=\"TCP\"'
  > ba-cli 'NAT.PortTrigger.ct-pt-test2.AutoDisableDuration=300'
  > ba-cli 'NAT.PortTrigger.ct-pt-test2.Rule+{Alias=\"ct-pt-rule2\"}'
  > ba-cli 'NAT.PortTrigger.ct-pt-test2.Rule.ct-pt-rule2.Port=8000'
  > ba-cli 'NAT.PortTrigger.ct-pt-test2.Rule.ct-pt-rule2.Protocol=\"TCP\"'
  > ba-cli 'NAT.PortTrigger.ct-pt-test2.Enable=1'
  > " > /tmp/cram
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/cram)'" > /dev/null; sleep 1

  $ curl --silent --output /dev/null --max-time 2 http://10.10.10.10:6000; sleep 2

  $ R "iptables -L FORWARD_PortTrigger -n | grep 8000 | wc -l"
  2

Establish TCP connection on port 8000 to create conntrack entry:

  $ nc -l -p 8000 -s $TARGET_LAN_TEST_HOST > /dev/null 2>&1 &
  $ sleep 1
  $ timeout 15 nc -s $TESTBED_WAN_IP $TARGET_WAN_IP 8000 > /dev/null 2>&1 &
  $ sleep 2

Verify TCP conntrack entry is present:

  $ R "conntrack -L -p tcp --dport 8000 2>/dev/null | wc -l"
  1

Kill nc and disable port trigger:

  $ pkill -f 'nc.*8000' 2>/dev/null; sleep 1
  $ script --command "ssh -t root@$TARGET_LAN_IP 'ba-cli \"NAT.PortTrigger.ct-pt-test2.Enable=0\"'" > /dev/null; sleep 2

Check that FORWARD_PortTrigger rules for port 8000 are gone:

  $ R "iptables -L FORWARD_PortTrigger -n | grep 8000 | wc -l"
  0

Verify conntrack entry was flushed after port trigger disable:

  $ R "conntrack -L -p tcp --dport 8000 2>/dev/null | wc -l"
  0

Remove port trigger and route:

  $ script --command "ssh -t root@$TARGET_LAN_IP 'ba-cli \"NAT.PortTrigger.ct-pt-test2-\"'" > /dev/null
  $ pkill -f 'nc.*8000' 2>/dev/null; true
  $ sudo ip route del 10.10.10.10/32 via $TARGET_LAN_IP dev $TESTBED_LAN_INTERFACE 2>/dev/null; true

