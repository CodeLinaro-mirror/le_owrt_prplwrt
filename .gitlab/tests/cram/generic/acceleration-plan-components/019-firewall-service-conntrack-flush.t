Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Resolve the WAN interface name from the logical reference:

  $ WAN_IFACE=$(R "ba-cli --less --json 'NetModel.Intf.ip-wan.getFirstParameter(name="NetDevName", flag = "netdev-bound")'" | sed '/^$/d' | tail -n 1 | cut -d'"' -f2)
  $ test -n "$WAN_IFACE"

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

  $ R "i=0; n=0; while [ \$i -lt 10 ]; do n=\$(iptables -L INPUT_Services -nv | grep 'icmp' | grep 'ACCEPT' | grep '$WAN_IFACE' | wc -l); [ \$n -ge 1 ] && break; i=\$((i+1)); sleep 1; done; [ \$n -ge 1 ] && echo rule-present || echo rule-count=\$n"
  rule-present

Start ping from testbed WAN to router WAN IP to create conntrack entry:

  $ R "conntrack -D -p icmp --src $TESTBED_WAN_IP --dst $TARGET_WAN_IP" > /dev/null 2>&1; true
  $ ping -I $TESTBED_WAN_IP -c 1 $TARGET_WAN_IP > /dev/null 2>&1 &
  $ sleep 2

Verify conntrack entry is present:

  $ R "i=0; n=0; while [ \$i -lt 10 ]; do n=\$(conntrack -L -p icmp --src $TESTBED_WAN_IP --dst $TARGET_WAN_IP 2>/dev/null | wc -l); [ \$n -ge 1 ] && break; i=\$((i+1)); sleep 1; done; [ \$n -ge 1 ] && echo entry-present || echo entry-count=\$n"
  entry-present

Kill ping and delete service:

  $ pkill -9 -f "ping.*$TARGET_WAN_IP" 2>/dev/null; sleep 2
  $ script --command "ssh -t root@$TARGET_LAN_IP 'ba-cli \"Firewall.Service.ct-svc-test-\"'" > /dev/null; sleep 2

Check that INPUT_Services ACCEPT rule for icmp is gone:

  $ R "iptables -L INPUT_Services -nv | grep 'icmp' | grep 'ACCEPT' | grep '$WAN_IFACE' | wc -l"
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

  $ R "conntrack -D -p icmp --src $TESTBED_WAN_IP --dst $TARGET_WAN_IP" > /dev/null 2>&1; true
  $ ping -I $TESTBED_WAN_IP -c 1 $TARGET_WAN_IP > /dev/null 2>&1 &
  $ sleep 2

  $ R "i=0; n=0; while [ \$i -lt 10 ]; do n=\$(conntrack -L -p icmp --src $TESTBED_WAN_IP --dst $TARGET_WAN_IP 2>/dev/null | wc -l); [ \$n -ge 1 ] && break; i=\$((i+1)); sleep 1; done; [ \$n -ge 1 ] && echo entry-present || echo entry-count=\$n"
  entry-present

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

