Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ : ${TARGET_WAN_INTERFACE:=wan}

Disable the existing ICMP drop rule on WAN interface to allow ping:

  $ R "ba-cli 'Firewall.Service.[ICMPType==8 && Protocol==1 && Action==\"Drop\"].Enable=0'" > /dev/null; sleep 1

Create firewall service allowing ICMP on the WAN interface:

  $ printf "\
  > ba-cli 'Firewall.Service+{Alias=\"ct-svc-test\"}'
  > ba-cli 'Firewall.Service.ct-svc-test.Interface=\"Device.IP.Interface.2\"'
  > ba-cli 'Firewall.Service.ct-svc-test.Protocol=1'
  > ba-cli 'Firewall.Service.ct-svc-test.ICMPType=8'
  > ba-cli 'Firewall.Service.ct-svc-test.IPVersion=4'
  > ba-cli 'Firewall.Service.ct-svc-test.Enable=1'
  > " > /tmp/cram
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/cram)'" > /dev/null; sleep 1

Check that INPUT_Services rule is present:

  $ R "iptables -L INPUT_Services -nv | grep 'icmp' | grep 'ACCEPT' | grep '$TARGET_WAN_INTERFACE' | wc -l"
  1

Start ping from testbed WAN to router WAN IP to create conntrack entry:

  $ ping -I $TESTBED_WAN_IP -c 1 $TARGET_WAN_IP > /dev/null 2>&1 &
  $ sleep 2

Verify conntrack entry is present:

  $ R "conntrack -L -p icmp --src $TESTBED_WAN_IP --dst $TARGET_WAN_IP 2>/dev/null | wc -l"
  1

Kill ping and delete service:

  $ pkill -9 -f "ping.*$TARGET_WAN_IP" 2>/dev/null; sleep 2
  $ script --command "ssh -t root@$TARGET_LAN_IP 'ba-cli \"Firewall.Service.ct-svc-test-\"'" > /dev/null; sleep 2

Check that INPUT_Services ACCEPT rule for icmp is gone:

  $ R "iptables -L INPUT_Services -nv | grep 'icmp' | grep 'ACCEPT' | grep '$TARGET_WAN_INTERFACE' | wc -l"
  0

Verify conntrack entry was flushed after service deletion:

  $ R "conntrack -L -p icmp --src $TESTBED_WAN_IP --dst $TARGET_WAN_IP 2>/dev/null | wc -l"
  0

Create service again to verify conntrack flush on disable:

  $ printf "\
  > ba-cli 'Firewall.Service+{Alias=\"ct-svc-test2\"}'
  > ba-cli 'Firewall.Service.ct-svc-test2.Interface=\"Device.IP.Interface.2\"'
  > ba-cli 'Firewall.Service.ct-svc-test2.Protocol=1'
  > ba-cli 'Firewall.Service.ct-svc-test2.ICMPType=8'
  > ba-cli 'Firewall.Service.ct-svc-test2.IPVersion=4'
  > ba-cli 'Firewall.Service.ct-svc-test2.Enable=1'
  > " > /tmp/cram
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/cram)'" > /dev/null; sleep 1

  $ ping -I $TESTBED_WAN_IP -c 1 $TARGET_WAN_IP > /dev/null 2>&1 &
  $ sleep 2

  $ R "conntrack -L -p icmp --src $TESTBED_WAN_IP --dst $TARGET_WAN_IP 2>/dev/null | wc -l"
  1

Kill ping and disable service:

  $ pkill -9 -f "ping.*$TARGET_WAN_IP" 2>/dev/null; sleep 2
  $ script --command "ssh -t root@$TARGET_LAN_IP 'ba-cli \"Firewall.Service.ct-svc-test2.Enable=0\"'" > /dev/null; sleep 2

Verify conntrack entry was flushed after service disable:

  $ R "conntrack -L -p icmp --src $TESTBED_WAN_IP --dst $TARGET_WAN_IP 2>/dev/null | wc -l"
  0

Remove service and restore ICMP drop rule:

  $ script --command "ssh -t root@$TARGET_LAN_IP 'ba-cli \"Firewall.Service.ct-svc-test2-\"'" > /dev/null
  $ pkill -9 -f "ping.*$TARGET_WAN_IP" 2>/dev/null; true
  $ R "ba-cli 'Firewall.Service.[ICMPType==8 && Protocol==1 && Action==\"Drop\"].Enable=1'" > /dev/null; sleep 1

