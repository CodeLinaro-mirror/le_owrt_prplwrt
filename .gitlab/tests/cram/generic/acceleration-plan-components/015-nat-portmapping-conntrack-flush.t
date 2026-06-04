Create R alias and set WAN IP:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Create portmapping on TCP port 5002:

  $ printf "\
  > ba-cli 'NAT.PortMapping+{Alias=\"ct-pm-test\"}'
  > ba-cli 'NAT.PortMapping.ct-pm-test.ExternalPort=5002'
  > ba-cli 'NAT.PortMapping.ct-pm-test.Interface=\"Device.IP.Interface.2\"'
  > ba-cli 'NAT.PortMapping.ct-pm-test.InternalClient=\"$TARGET_LAN_TEST_HOST\"'
  > ba-cli 'NAT.PortMapping.ct-pm-test.InternalPort=12347'
  > ba-cli 'NAT.PortMapping.ct-pm-test.Protocol=\"TCP\"'
  > ba-cli 'NAT.PortMapping.ct-pm-test.Enable=1'
  > " > /tmp/cram
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/cram)'" > /dev/null; sleep 1

Establish TCP connection through portmapping to create conntrack entry:

  $ nc -l -p 12347 -s $TARGET_LAN_TEST_HOST > /dev/null 2>&1 &
  $ sleep 1
  $ nc -w 60 -s $TESTBED_WAN_IP $TARGET_WAN_IP 5002 > /dev/null 2>&1 &
  $ sleep 2

Verify conntrack entry is present:

  $ R "conntrack -L -p tcp --dport 5002 2>/dev/null | wc -l"
  1

Remove portmapping:

  $ script --command "ssh -t root@$TARGET_LAN_IP 'ba-cli \"NAT.PortMapping.ct-pm-test-\"'" > /dev/null; sleep 2

Verify conntrack entry was flushed:

  $ R "conntrack -L -p tcp --dport 5002 2>/dev/null | wc -l"
  0

  $ pkill -f 'nc.*12347' 2>/dev/null; pkill -f 'nc.*5002' 2>/dev/null; true

Create portmapping again to verify conntrack flush on disable:

  $ printf "\
  > ba-cli 'NAT.PortMapping+{Alias=\"ct-pm-test2\"}'
  > ba-cli 'NAT.PortMapping.ct-pm-test2.ExternalPort=5002'
  > ba-cli 'NAT.PortMapping.ct-pm-test2.Interface=\"Device.IP.Interface.2\"'
  > ba-cli 'NAT.PortMapping.ct-pm-test2.InternalClient=\"$TARGET_LAN_TEST_HOST\"'
  > ba-cli 'NAT.PortMapping.ct-pm-test2.InternalPort=12347'
  > ba-cli 'NAT.PortMapping.ct-pm-test2.Protocol=\"TCP\"'
  > ba-cli 'NAT.PortMapping.ct-pm-test2.Enable=1'
  > " > /tmp/cram
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/cram)'" > /dev/null; sleep 1

  $ nc -l -p 12347 -s $TARGET_LAN_TEST_HOST > /dev/null 2>&1 &
  $ sleep 1
  $ nc -w 60 -s $TESTBED_WAN_IP $TARGET_WAN_IP 5002 > /dev/null 2>&1 &
  $ sleep 2

  $ R "conntrack -L -p tcp --dport 5002 2>/dev/null | wc -l"
  1

Disable portmapping:

  $ script --command "ssh -t root@$TARGET_LAN_IP 'ba-cli \"NAT.PortMapping.ct-pm-test2.Enable=0\"'" > /dev/null; sleep 2

Verify conntrack flushed after disable:

  $ R "conntrack -L -p tcp --dport 5002 2>/dev/null | wc -l"
  0

  $ pkill -f 'nc.*12347' 2>/dev/null; pkill -f 'nc.*5002' 2>/dev/null; true

Re-enable and verify conntrack flush on ExternalPort change:

  $ script --command "ssh -t root@$TARGET_LAN_IP 'ba-cli \"NAT.PortMapping.ct-pm-test2.Enable=1\"'" > /dev/null; sleep 1

  $ nc -l -p 12347 -s $TARGET_LAN_TEST_HOST > /dev/null 2>&1 &
  $ sleep 1
  $ nc -w 60 -s $TESTBED_WAN_IP $TARGET_WAN_IP 5002 > /dev/null 2>&1 &
  $ sleep 2

  $ R "conntrack -L -p tcp --dport 5002 2>/dev/null | wc -l"
  1

Change ExternalPort:

  $ script --command "ssh -t root@$TARGET_LAN_IP 'ba-cli \"NAT.PortMapping.ct-pm-test2.ExternalPort=5003\"'" > /dev/null; sleep 2

Verify conntrack for old port 5002 was flushed:

  $ R "conntrack -L -p tcp --dport 5002 2>/dev/null | wc -l"
  0

Remove portmapping:

  $ script --command "ssh -t root@$TARGET_LAN_IP 'ba-cli \"NAT.PortMapping.ct-pm-test2-\"'" > /dev/null
  $ pkill -f 'nc.*12347' 2>/dev/null; pkill -f 'nc.*500[23]' 2>/dev/null; true

