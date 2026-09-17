Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

DNS class A query
  $ R "nslookup -timeout=1 -type=A www.google.fr"
  Server:\t\t127.0.0.1 (esc)
  Address:\t127.0.0.1:53 (esc)
  
  Non-authoritative answer:
  Name:\twww.google.fr (esc)
  Address: .* (re)
  

DNS class AAAA query
  $ R "nslookup -timeout=1 -type=AAAA www.google.fr"
  Server:\t\t127.0.0.1 (esc)
  Address:\t127.0.0.1:53 (esc)
  
  Non-authoritative answer:
  Name:\twww.google.fr (esc)
  Address: .* (re)
  

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

Check default values of all DNS.Relay.Config

  $ R "ba-cli 'DNS.Relay.Config.*.?'"  | grep -Ev '^>|^$'
  DNS.Relay.Config.1.
  DNS.Relay.Config.1.Alias="lan"
  DNS.Relay.Config.1.CacheMaxTTL=86400
  DNS.Relay.Config.1.CacheMinTTL=0
  DNS.Relay.Config.1.CacheSize=4000
  DNS.Relay.Config.1.FailbackMaxTimer=0
  DNS.Relay.Config.1.FailbackMinTimer=0
  DNS.Relay.Config.1.Forwarders=""
  DNS.Relay.Config.1.ForwardingMode="Optimal"
  DNS.Relay.Config.1.Interface="Device.Logical.Interface.2"
  DNS.Relay.Config.1.MaxRetries=5
  DNS.Relay.Config.1.ResponseTimeout=0
  DNS.Relay.Config.2.
  DNS.Relay.Config.2.Alias="guest"
  DNS.Relay.Config.2.CacheMaxTTL=86400
  DNS.Relay.Config.2.CacheMinTTL=0
  DNS.Relay.Config.2.CacheSize=1000
  DNS.Relay.Config.2.FailbackMaxTimer=0
  DNS.Relay.Config.2.FailbackMinTimer=0
  DNS.Relay.Config.2.Forwarders=""
  DNS.Relay.Config.2.ForwardingMode="Optimal"
  DNS.Relay.Config.2.Interface="Device.Logical.Interface.3"
  DNS.Relay.Config.2.MaxRetries=5
  DNS.Relay.Config.2.ResponseTimeout=0
  DNS.Relay.Config.3.
  DNS.Relay.Config.3.Alias="lcm"
  DNS.Relay.Config.3.CacheMaxTTL=86400
  DNS.Relay.Config.3.CacheMinTTL=0
  DNS.Relay.Config.3.CacheSize=1000
  DNS.Relay.Config.3.FailbackMaxTimer=0
  DNS.Relay.Config.3.FailbackMinTimer=0
  DNS.Relay.Config.3.Forwarders=""
  DNS.Relay.Config.3.ForwardingMode="Optimal"
  DNS.Relay.Config.3.Interface="Device.Logical.Interface.4"
  DNS.Relay.Config.3.MaxRetries=5
  DNS.Relay.Config.3.ResponseTimeout=0
  DNS.Relay.Config.4.
  DNS.Relay.Config.4.Alias="lo"
  DNS.Relay.Config.4.CacheMaxTTL=86400
  DNS.Relay.Config.4.CacheMinTTL=0
  DNS.Relay.Config.4.CacheSize=256
  DNS.Relay.Config.4.FailbackMaxTimer=0
  DNS.Relay.Config.4.FailbackMinTimer=0
  DNS.Relay.Config.4.Forwarders=""
  DNS.Relay.Config.4.ForwardingMode="Optimal"
  DNS.Relay.Config.4.Interface="Device.IP.Interface.1"
  DNS.Relay.Config.4.MaxRetries=5
  DNS.Relay.Config.4.ResponseTimeout=0

Check that ForwardingMode = Parallel is rejected

  $ R "ba-cli -l 'DNS.Relay.Config.lo.ForwardingMode=Parallel' | awk NF"
  ERROR: set DNS.Relay.Config.lo.ForwardingMode failed (10 - invalid value)

Check that Forwarders do not accept an invalid DNS.Relay.Forwarding reference

  $ R "ba-cli -l DNS.Relay.Config.1.Forwarders='\"DNS.Relay.Forwarding.foo\"' | awk NF"
  ERROR: set DNS.Relay.Config.1.Forwarders failed (21 - invalid path)
