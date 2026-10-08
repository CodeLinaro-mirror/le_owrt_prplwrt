Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Disable Time Server and STOMP to avoid interference during the test
  $ R "ba-cli -l Device.Time.Client.1.Enable=0 | awk NF"
  0
  $ R "obuspa -c set Device.STOMP.Connection.1.Enable 0"
  Device.STOMP.Connection.1.Enable => 0
Disable ACS by resetting the URL (EnableCWMP has no effect on DNS resolution)
  $ MANAGEMENT_SERVER_URL="$(R "ba-cli -l Device.ManagementServer.URL? | awk NF")"
  $ R "ba-cli -l Device.ManagementServer.URL='' | awk NF"

Configure DNS relay on lo interface to StrictOrder with no retry for each DNS forwarder 

  $ R "ba-cli -l 'DNS.Relay.Config.lo.ForwardingMode=StrictOrder' | awk NF"
  StrictOrder
  $ R "ba-cli -l 'DNS.Relay.Config.lo.ResponseTimeout=800' | awk NF"
  800
  $ R "ba-cli -l 'DNS.Relay.Config.lo.MaxRetries=0' | awk NF"
  0


Wait for unbound instance for 'lo' interface to restart

  $ sleep 10

  $ R "ba-cli -l  'protected; DNS.Relay.Config.1.DNSMode=Static; DNS.Relay.Config.1.IPv6DNSMode=Static' | grep -v '>' | awk NF"
  Static
  Static

Configure one responsive and one unresponsive DNS server

  $ R "ba-cli -l DNS.Relay.Forwarding.+{ Alias=test-ok, DNSServer=8.8.8.8, Enable=1, Interface=Device.Logical.Interface.1., Type=Static} | awk NF"
  test-ok

  $ R "ba-cli -l DNS.Relay.Forwarding.test-ok.Status? | awk NF"
  Enabled

  $ R "ba-cli -l DNS.Relay.Forwarding.+{ Alias=test-ko, DNSServer=192.168.101.1, Enable=1, Interface=Device.Logical.Interface.1., Type=Static} | awk NF"
  test-ko

  $ R "ba-cli -l DNS.Relay.Forwarding.test-ko.Status? | awk NF"
  Enabled

Check dns-up netmodel flag
  $ R "ba-cli -l 'NetModel.Intf.ip-wan.Flags?' | awk NF"
  .*dns-up.* (re)

Configure Forwarders to have the unresponsive server first

  $ R "ba-cli -l DNS.Relay.Config.1.Forwarders='\"DNS.Relay.Forwarding.test-ko,DNS.Relay.Forwarding.test-ok\"' | awk NF"
  DNS.Relay.Forwarding..* (re)

Send 2 DNS queries. The first one should timeout and the second one should succeed
  $ R "sleep 1; nslookup -timeout=1 -retry=1 -type=A www.google.co.uk"
  ;; connection timed out; no servers could be reached
  
  [1]

Check that DNS query succeeds since the second server is valid
  $ R "sleep 1; nslookup -timeout=1 -retry=1 -type=A www.google.co.uk"
  Server:\t\t127.0.0.1 (esc)
  Address:\t127.0.0.1:53 (esc)
  
  Non-authoritative answer:
  Name:\twww.google.co.uk (esc)
  Address: .* (re)
  

Tear down

  $ R "ba-cli -l DNS.Relay.Forwarding.test-ko- > /dev/null"
  $ R "ba-cli -l DNS.Relay.Forwarding.test-ok- > /dev/null"
  $ R "ba-cli -l  'protected; DNS.Relay.Config.1.DNSMode=Dynamic; DNS.Relay.Config.1.IPv6DNSMode=Dynamic' | grep -v '>' | awk NF"
  Dynamic
  Dynamic

  $ R "ba-cli -l 'DNS.Relay.Config.lo.FailbackMaxTimer=0; DNS.Relay.Config.lo.FailbackMinTimer=0' > /dev/null"
  $ R "ba-cli -l 'DNS.Relay.Config.lo.ResponseTimeout=0; DNS.Relay.Config.lo.MaxRetries=5; DNS.Relay.Config.lo.ForwardingMode=Optimal' > /dev/null"

Let unbound restart with the default configuration
  $ sleep 5

Restore Time Server and STOMP configuration
  $ R "ba-cli -l Device.Time.Client.1.Enable=1 | awk NF"
  1
  $ R "obuspa -c set Device.STOMP.Connection.1.Enable 1"
  Device.STOMP.Connection.1.Enable => 1
Restore ACS configuration
  $ R "ba-cli -l Device.ManagementServer.URL=\"${MANAGEMENT_SERVER_URL}\" > /dev/null"