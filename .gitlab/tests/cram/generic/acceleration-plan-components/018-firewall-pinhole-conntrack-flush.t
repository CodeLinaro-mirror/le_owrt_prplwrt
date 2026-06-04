Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Add a portmapping to supply DNAT for port 6022:

  $ printf "\
  > ba-cli 'NAT.PortMapping+{Alias=\"ct-ph-pm\"}'
  > ba-cli 'NAT.PortMapping.ct-ph-pm.ExternalPort=6022'
  > ba-cli 'NAT.PortMapping.ct-ph-pm.Interface=\"Device.IP.Interface.2\"'
  > ba-cli 'NAT.PortMapping.ct-ph-pm.InternalClient=\"$TARGET_LAN_TEST_HOST\"'
  > ba-cli 'NAT.PortMapping.ct-ph-pm.InternalPort=6022'
  > ba-cli 'NAT.PortMapping.ct-ph-pm.Protocol=\"TCP\"'
  > ba-cli 'NAT.PortMapping.ct-ph-pm.Enable=1'
  > " > /tmp/cram
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/cram)'" > /dev/null; sleep 1

Add pinhole allowing the forwarded traffic to reach the internal host:

  $ printf "\
  > ba-cli 'Firewall.Pinhole+{Alias=\"ct-ph-test\"}'
  > ba-cli 'Firewall.Pinhole.ct-ph-test.Protocol=6'
  > ba-cli 'Firewall.Pinhole.ct-ph-test.Interface=\"Device.IP.Interface.2\"'
  > ba-cli 'Firewall.Pinhole.ct-ph-test.DestIP=\"$TARGET_LAN_TEST_HOST\"'
  > ba-cli 'Firewall.Pinhole.ct-ph-test.DestPort=6022'
  > ba-cli 'Firewall.Pinhole.ct-ph-test.Enable=1'
  > " > /tmp/cram
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/cram)'" > /dev/null; sleep 1

Check that FORWARD_Pinhole rule is present:

  $ R "iptables -L FORWARD_Pinhole -n | grep $TARGET_LAN_TEST_HOST | grep 'dpt:6022' | wc -l"
  1

Establish TCP connection through portmapping to create conntrack entry:

  $ nc -l -p 6022 -s $TARGET_LAN_TEST_HOST > /dev/null 2>&1 &
  $ sleep 1
  $ nc -w 60 -s $TESTBED_WAN_IP $TARGET_WAN_IP 6022 > /dev/null 2>&1 &
  $ sleep 2

Verify conntrack entry is present:

  $ R "conntrack -L -p tcp --dport 6022 2>/dev/null | wc -l"
  1

Kill nc connections and delete pinhole:

  $ pkill -f 'nc.*6022' 2>/dev/null; sleep 1
  $ script --command "ssh -t root@$TARGET_LAN_IP 'ba-cli \"Firewall.Pinhole.ct-ph-test-\"'" > /dev/null; sleep 2

Check that FORWARD_Pinhole rule is gone:

  $ R "iptables -L FORWARD_Pinhole -n | grep $TARGET_LAN_TEST_HOST | grep 'dpt:6022' | wc -l"
  0

Verify conntrack entry was flushed after pinhole deletion:

  $ R "conntrack -L -p tcp --dport 6022 2>/dev/null | wc -l"
  0

Add pinhole again to verify conntrack flush on disable:

  $ printf "\
  > ba-cli 'Firewall.Pinhole+{Alias=\"ct-ph-test2\"}'
  > ba-cli 'Firewall.Pinhole.ct-ph-test2.Protocol=6'
  > ba-cli 'Firewall.Pinhole.ct-ph-test2.Interface=\"Device.IP.Interface.2\"'
  > ba-cli 'Firewall.Pinhole.ct-ph-test2.DestIP=\"$TARGET_LAN_TEST_HOST\"'
  > ba-cli 'Firewall.Pinhole.ct-ph-test2.DestPort=6022'
  > ba-cli 'Firewall.Pinhole.ct-ph-test2.Enable=1'
  > " > /tmp/cram
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/cram)'" > /dev/null; sleep 1

  $ nc -l -p 6022 -s $TARGET_LAN_TEST_HOST > /dev/null 2>&1 &
  $ sleep 1
  $ nc -w 60 -s $TESTBED_WAN_IP $TARGET_WAN_IP 6022 > /dev/null 2>&1 &
  $ sleep 2

  $ R "conntrack -L -p tcp --dport 6022 2>/dev/null | wc -l"
  1

Kill nc connections and disable pinhole:

  $ pkill -f 'nc.*6022' 2>/dev/null; sleep 1
  $ script --command "ssh -t root@$TARGET_LAN_IP 'ba-cli \"Firewall.Pinhole.ct-ph-test2.Enable=0\"'" > /dev/null; sleep 2

Verify conntrack entry was flushed after pinhole disable:

  $ R "conntrack -L -p tcp --dport 6022 2>/dev/null | wc -l"
  0

Remove pinhole and supporting portmapping:

  $ script --command "ssh -t root@$TARGET_LAN_IP 'ba-cli \"Firewall.Pinhole.ct-ph-test2-\"'" > /dev/null
  $ script --command "ssh -t root@$TARGET_LAN_IP 'ba-cli \"NAT.PortMapping.ct-ph-pm-\"'" > /dev/null
  $ pkill -f 'nc.*6022' 2>/dev/null; true

