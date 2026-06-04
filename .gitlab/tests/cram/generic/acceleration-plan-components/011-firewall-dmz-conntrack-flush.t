Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check if conntrack tool is enabled in pipeline:

  $ R "which conntrack"
  /usr/sbin/conntrack

Add DMZ host:

  $ printf "\
  > ba-cli 'Firewall.DMZ+{Alias=\"ct-dmz-test\", DestIP=\"$TARGET_LAN_TEST_HOST\"}'
  > ba-cli 'Firewall.DMZ.ct-dmz-test.Enable=1'
  > ba-cli 'Firewall.DMZ.ct-dmz-test.Interface=\"Device.Logical.Interface.1\"'
  > " > /tmp/cram
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/cram)'" > /dev/null; sleep 1

Check that firewall DNAT rule is present:

  $ R "iptables -t nat -L PREROUTING_DMZ | grep $TARGET_LAN_TEST_HOST | wc -l"
  1

Establish TCP connection through DMZ rule to create conntrack entry:

  $ nc -l -p 8080 -s $TARGET_LAN_TEST_HOST > /dev/null 2>&1 &
  $ sleep 1
  $ nc -w 60 -s $TESTBED_WAN_IP $TARGET_WAN_IP 8080 > /dev/null 2>&1 &
  $ sleep 2

Verify conntrack entry is present:

  $ R "conntrack -L -p tcp --dport 8080 2>/dev/null | wc -l"
  1

Remove DMZ host:

  $ script --command "ssh -t root@$TARGET_LAN_IP 'ba-cli \"Firewall.DMZ.ct-dmz-test-\"'" > /dev/null; sleep 2

Check that firewall DNAT rule is gone:

  $ R "iptables -t nat -L PREROUTING_DMZ | grep $TARGET_LAN_TEST_HOST | wc -l"
  0

Verify conntrack entry was flushed after DMZ deletion:

  $ R "conntrack -L -p tcp --dport 8080 2>/dev/null | wc -l"
  0

  $ pkill -f 'nc.*8080' 2>/dev/null; true

