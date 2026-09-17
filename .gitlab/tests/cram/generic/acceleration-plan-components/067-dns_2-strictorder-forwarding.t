Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Disable ACS and Time Server to avoid interference during the test

  $ TIME_SERVERS="'$(R "ba-cli -l Device.Time.Client.1.Servers? | awk NF")'"
  $ MANAGEMENT_SERVER_URL="$(R "ba-cli -l Device.ManagementServer.URL? | awk NF")"
  $ STOMP_CONNECTION="$(R "obuspa -c get Device.STOMP.Connection.1.Host | cut -d' ' -f3")"
  $ R "ba-cli -l Device.Time.Client.1.Servers='' | awk NF"
  $ R "ba-cli -l Device.ManagementServer.URL='' | awk NF"
  $ R "obuspa -c set Device.STOMP.Connection.1.Host ''"
  Device.STOMP.Connection.1.Host => 

Configure DNS relay on lo interface to StrictOrder with no retry for each DNS forwarder 

  $ R "ba-cli -l 'DNS.Relay.Config.lo.ForwardingMode=StrictOrder' | awk NF"
  StrictOrder
  $ R "ba-cli -l 'DNS.Relay.Config.lo.ResponseTimeout=800' | awk NF"
  800
  $ R "ba-cli -l 'DNS.Relay.Config.lo.MaxRetries=0' | awk NF"
  0

Wait for unbound instance for 'lo' interface to restart

  $ sleep 10

DNS class A query for a non-existing domain
  $ R "nslookup -timeout=1 -type=A this-domain-does-not-exist.invalid"
  Server:\t\t127.0.0.1 (esc)
  Address:\t127.0.0.1:53 (esc)
  
  ** server can't find this-domain-does-not-exist.invalid: NXDOMAIN
  
  [1]

DNS class AAAA query for a non-existing domain
  $ R "nslookup -timeout=1 -type=AAAA this-domain-does-not-exist.invalid"
  Server:\t\t127.0.0.1 (esc)
  Address:\t127.0.0.1:53 (esc)
  
  ** server can't find this-domain-does-not-exist.invalid: NXDOMAIN
  
  [1]

Configure unresponsive DNS servers as the first three forwarders
  $ R "ba-cli -l  'protected; DNS.Relay.Config.1.DNSMode=Static; DNS.Relay.Config.1.IPv6DNSMode=Static' | grep -v '>' | awk NF"
  Static
  Static

  $ R "ba-cli -l DNS.Relay.Forwarding.+{ Alias=test-ko-1, DNSServer=192.168.101.1, Enable=1, Interface=Device.Logical.Interface.1., Type=Static} | awk NF"
  test-ko-1

  $ R "ba-cli -l DNS.Relay.Forwarding.test-ko-1.Status? | awk NF"
  Enabled

  $ R "ba-cli -l DNS.Relay.Forwarding.+{ Alias=test-ko-2, DNSServer=192.168.102.1, Enable=1, Interface=Device.Logical.Interface.1., Type=Static} | awk NF"
  test-ko-2

  $ R "ba-cli -l DNS.Relay.Forwarding.test-ko-2.Status? | awk NF"
  Enabled

  $ R "ba-cli -l DNS.Relay.Forwarding.+{ Alias=test-ko-3, DNSServer=192.168.103.1, Enable=1, Interface=Device.Logical.Interface.1., Type=Static} | awk NF"
  test-ko-3

  $ R "ba-cli -l DNS.Relay.Forwarding.test-ko-3.Status? | awk NF"
  Enabled

Configure a valid DNS server as the fourth one

  $ R "ba-cli -l DNS.Relay.Forwarding.+{ Alias=test-ok, DNSServer=8.8.8.8, Enable=1, Interface=Device.Logical.Interface.1., Type=Static} | awk NF"
  test-ok

  $ R "ba-cli -l DNS.Relay.Forwarding.test-ok.Status? | awk NF"
  Enabled

Check dns-up netmodel flag
  $ R "ba-cli -l 'NetModel.Intf.ip-wan.Flags?' | awk NF"
  .*dns-up.* (re)

Send 4 DNS queries (both class A and class AAAA). The 3 first ones should timeout and the 4th one should succeed
  $ R "sleep 1; nslookup -timeout=1 -retry=1 www.google.be"
  ;; connection timed out; no servers could be reached
  
  [1]

  $ R "sleep 1; nslookup -timeout=1 -retry=1 www.google.be"
  ;; connection timed out; no servers could be reached
  
  [1]

  $ R "sleep 1; nslookup -timeout=1 -retry=1 www.google.be"
  ;; connection timed out; no servers could be reached
  
  [1]

Check that DNS query succeeds since the fourth server is valid
  $ R "sleep 1; nslookup -timeout=1 -retry=1 www.google.be"
  Server:\t\t127.0.0.1 (esc)
  Address:\t127.0.0.1:53 (esc)
  
  Non-authoritative answer:
  Name:\twww.google.be (esc)
  Address: .* (re)
  
  Non-authoritative answer:
  Name:\twww.google.be (esc)
  Address: .* (re)
  

Check failback mechanism: disable the 2 middle servers

  $ R "ba-cli -l DNS.Relay.Forwarding.test-ko-2.Enable=0 | awk NF"
  0
  $ R "ba-cli -l DNS.Relay.Forwarding.test-ko-3.Enable=0 | awk NF"
  0

  $ R "ba-cli -l DNS.Relay.Config.lo.MaxRetries=2 | awk NF"
  2

First DNS query should fail (first server is KO)
  $ R "sleep 1; nslookup -timeout=1 -retry=1 -type=A www.google.it"
  ;; connection timed out; no servers could be reached
  
  [1]

Second DNS query to the same forwarder should fail (retry = 1)
  $ R "sleep 1; nslookup -timeout=1 -retry=1 -type=A www.google.it"
  ;; connection timed out; no servers could be reached
  
  [1]

Third DNS query to the same forwarder should fail (retry = 2)
  $ R "sleep 1; nslookup -timeout=1 -retry=1 -type=A www.google.it"
  ;; connection timed out; no servers could be reached
  
  [1]

Retries are exhausted, so fourth DNS query should use the second server which is OK, so the query should succeed
  $ R "sleep 1; nslookup -timeout=1 -retry=1 -type=A www.google.it"
  Server:\t\t127.0.0.1 (esc)
  Address:\t127.0.0.1:53 (esc)
  
  Non-authoritative answer:
  Name:\twww.google.it (esc)
  Address: .* (re)
  

Set max retries to 0 and a delay between 5 and 10 seconds for the failback mechanism
  $ R "ba-cli -l DNS.Relay.Config.lo.MaxRetries=0 | awk NF"
  0
  $ R "ba-cli -l DNS.Relay.Config.lo.FailbackMaxTimer=10000 | awk NF"
  10000
  $ R "ba-cli -l DNS.Relay.Config.lo.FailbackMinTimer=5000 | awk NF"
  5000

First DNS query should fail (first server is KO)
  $ R "sleep 1; nslookup -timeout=1 -retry=1 -type=A www.google.co.uk"
  ;; connection timed out; no servers could be reached
  
  [1]

Second server is OK so query should succeed
  $ R "sleep 1; nslookup -timeout=1 -retry=1 -type=A www.google.co.uk"
  Server:\t\t127.0.0.1 (esc)
  Address:\t127.0.0.1:53 (esc)
  
  Non-authoritative answer:
  Name:\twww.google.co.uk (esc)
  Address: .* (re)
  

Wait 10 seconds to allow fallback to primary DNS server
  $ R "sleep 10; nslookup -timeout=1 -retry=1 -type=A www.google.es"
  ;; connection timed out; no servers could be reached
  
  [1]

Tear down

  $ R "ba-cli -l DNS.Relay.Forwarding.test-ko-1- > /dev/null"
  $ R "ba-cli -l DNS.Relay.Forwarding.test-ko-2- > /dev/null"
  $ R "ba-cli -l DNS.Relay.Forwarding.test-ko-3- > /dev/null"
  $ R "ba-cli -l DNS.Relay.Forwarding.test-ok- > /dev/null"
  $ R "ba-cli -l  'protected; DNS.Relay.Config.1.DNSMode=Dynamic; DNS.Relay.Config.1.IPv6DNSMode=Dynamic' | grep -v '>' | awk NF"
  Dynamic
  Dynamic

  $ R "obuspa -c set Device.STOMP.Connection.1.Host \"${STOMP_CONNECTION}\" > /dev/null"
  $ R "ba-cli -l Device.ManagementServer.URL=\"${MANAGEMENT_SERVER_URL}\" > /dev/null"
  $ R "ba-cli -l Device.Time.Client.1.Servers=\"${TIME_SERVERS}\" > /dev/null"
  $ R "ba-cli -l 'DNS.Relay.Config.lo.FailbackMaxTimer=0; DNS.Relay.Config.lo.FailbackMinTimer=0' > /dev/null"
  $ R "ba-cli -l 'DNS.Relay.Config.lo.ResponseTimeout=0; DNS.Relay.Config.lo.MaxRetries=5; DNS.Relay.Config.lo.ForwardingMode=Optimal' > /dev/null"

Let unbound restart with the default configuration

  $ sleep 5