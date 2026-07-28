Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Define helper functions:

  $ get_stat() { R "ba-cli --json 'Device.DNS.Relay.Stats.$1?' | sed -n 's/.*\"$1\":[[:space:]]*\([0-9]\+\).*/\1/p'"; }
  $ reset_stats() { R "ba-cli 'Device.DNS.Relay.Stats.Reset()' | grep -v '^>'"; }
  $ assert_incremented() { if [ "$3" -gt "$2" ]; then echo "$1 incremented"; else echo "FAIL: $1 did not increment (before=$2, after=$3)"; fi; }
  $ assert_unchanged() { if [ "$3" -eq "$2" ]; then echo "$1 unchanged"; else echo "FAIL: $1 changed unexpectedly (before=$2, after=$3)"; fi; }
  $ assert_decreased() { if [ "$3" -lt "$2" ]; then echo "$1 decreased after reset"; else echo "FAIL: $1 not decreased (before=$2, after=$3)"; fi; }

Check dig is available, install dnsutils if missing:

  $ command -v dig > /dev/null 2>&1 || apt-get install --yes --no-install-recommends dnsutils > /dev/null 2>&1 || true
  $ command -v dig || { echo "dig not found, install dnsutils on the test host"; exit 1; }
  .*/dig (re)

Record initial values of DNS Relay Stats parameters:

  $ init_total=$(get_stat TotalQueries) && echo "$init_total"
  [0-9]+ (re)

  $ init_qtype_a=$(get_stat QueryTypeA) && echo "$init_qtype_a"
  [0-9]+ (re)

  $ init_qtype_aaaa=$(get_stat QueryTypeAAAA) && echo "$init_qtype_aaaa"
  [0-9]+ (re)

  $ init_class_in=$(get_stat QueryClassIN) && echo "$init_class_in"
  [0-9]+ (re)

  $ init_opcode=$(get_stat OpcodeQUERY) && echo "$init_opcode"
  [0-9]+ (re)

  $ init_noerror=$(get_stat AnswerRCodeNOERROR) && echo "$init_noerror"
  [0-9]+ (re)

  $ init_recursive=$(get_stat RecursiveReplies) && echo "$init_recursive"
  [0-9]+ (re)

Execute an IPv4 (A record) lookup through the DNS relay:

  $ dig @192.168.1.1 example.com A > /dev/null

Execute an IPv6 (AAAA record) lookup through the DNS relay:

  $ dig @192.168.1.1 example.com AAAA > /dev/null

Read all statistics parameters and verify they have incremented:

  $ assert_incremented TotalQueries "$init_total" "$(get_stat TotalQueries)"
  TotalQueries incremented

  $ assert_incremented QueryTypeA "$init_qtype_a" "$(get_stat QueryTypeA)"
  QueryTypeA incremented

  $ assert_incremented QueryTypeAAAA "$init_qtype_aaaa" "$(get_stat QueryTypeAAAA)"
  QueryTypeAAAA incremented

  $ assert_incremented QueryClassIN "$init_class_in" "$(get_stat QueryClassIN)"
  QueryClassIN incremented

  $ assert_incremented OpcodeQUERY "$init_opcode" "$(get_stat OpcodeQUERY)"
  OpcodeQUERY incremented

  $ assert_incremented AnswerRCodeNOERROR "$init_noerror" "$(get_stat AnswerRCodeNOERROR)"
  AnswerRCodeNOERROR incremented

  $ assert_incremented RecursiveReplies "$init_recursive" "$(get_stat RecursiveReplies)"
  RecursiveReplies incremented

Reset all DNS Relay Stats counters:

  $ final_total=$(get_stat TotalQueries)
  $ final_qtype_a=$(get_stat QueryTypeA)
  $ final_qtype_aaaa=$(get_stat QueryTypeAAAA)
  $ final_class_in=$(get_stat QueryClassIN)
  $ final_opcode=$(get_stat OpcodeQUERY)
  $ reset_stats
  Device.DNS.Relay.Stats.Reset() returned
  [
      1
  ]

Verify all statistics parameters are less than their pre-reset values:

  $ assert_decreased TotalQueries "$final_total" "$(get_stat TotalQueries)"
  TotalQueries decreased after reset

  $ assert_decreased QueryTypeA "$final_qtype_a" "$(get_stat QueryTypeA)"
  QueryTypeA decreased after reset

  $ assert_decreased QueryTypeAAAA "$final_qtype_aaaa" "$(get_stat QueryTypeAAAA)"
  QueryTypeAAAA decreased after reset

  $ assert_decreased QueryClassIN "$final_class_in" "$(get_stat QueryClassIN)"
  QueryClassIN decreased after reset

  $ assert_decreased OpcodeQUERY "$final_opcode" "$(get_stat OpcodeQUERY)"
  OpcodeQUERY decreased after reset

Record current statistics before NXDOMAIN test:

  $ pre_nx_total=$(get_stat TotalQueries) && echo "$pre_nx_total"
  [0-9]+ (re)

  $ pre_nx_qtype_a=$(get_stat QueryTypeA) && echo "$pre_nx_qtype_a"
  [0-9]+ (re)

  $ pre_nx_nxdomain=$(get_stat AnswerRCodeNXDOMAIN) && echo "$pre_nx_nxdomain"
  [0-9]+ (re)

  $ pre_nx_noerror=$(get_stat AnswerRCodeNOERROR) && echo "$pre_nx_noerror"
  [0-9]+ (re)

Query a non-existent domain (expects NXDOMAIN):

  $ dig @192.168.1.1 this-domain-does-not-exist.invalid A > /dev/null

Verify TotalQueries and QueryTypeA incremented, AnswerRCodeNXDOMAIN incremented, AnswerRCodeNOERROR unchanged:

  $ assert_incremented TotalQueries "$pre_nx_total" "$(get_stat TotalQueries)"
  TotalQueries incremented

  $ assert_incremented QueryTypeA "$pre_nx_qtype_a" "$(get_stat QueryTypeA)"
  QueryTypeA incremented

  $ assert_incremented AnswerRCodeNXDOMAIN "$pre_nx_nxdomain" "$(get_stat AnswerRCodeNXDOMAIN)"
  AnswerRCodeNXDOMAIN incremented

  $ assert_unchanged AnswerRCodeNOERROR "$pre_nx_noerror" "$(get_stat AnswerRCodeNOERROR)"
  AnswerRCodeNOERROR unchanged

Reset counters before cache test:

  $ reset_stats
  Device.DNS.Relay.Stats.Reset() returned
  [
      1
  ]

Record statistics before cache test:

  $ cache_pre_total=$(get_stat TotalQueries) && echo "$cache_pre_total"
  [0-9]+ (re)

  $ cache_pre_hits=$(get_stat CacheHits) && echo "$cache_pre_hits"
  [0-9]+ (re)

  $ cache_pre_noerror=$(get_stat AnswerRCodeNOERROR) && echo "$cache_pre_noerror"
  [0-9]+ (re)

Execute initial lookup to populate cache, then repeat 10 times:

  $ for i in $(seq 1 11); do dig @192.168.1.1 example.com A > /dev/null; done

Verify cache statistics incremented correctly:

  $ assert_incremented TotalQueries "$cache_pre_total" "$(get_stat TotalQueries)"
  TotalQueries incremented

  $ assert_incremented CacheHits "$cache_pre_hits" "$(get_stat CacheHits)"
  CacheHits incremented

  $ assert_incremented AnswerRCodeNOERROR "$cache_pre_noerror" "$(get_stat AnswerRCodeNOERROR)"
  AnswerRCodeNOERROR incremented

Reset counters before TCP/IPv6 test:

  $ reset_stats
  Device.DNS.Relay.Stats.Reset() returned
  [
      1
  ]

Record statistics before TCP/IPv6 test:

  $ tcpv6_pre_total=$(get_stat TotalQueries) && echo "$tcpv6_pre_total"
  [0-9]+ (re)

  $ tcpv6_pre_tcp=$(get_stat QueryTCP) && echo "$tcpv6_pre_tcp"
  [0-9]+ (re)

  $ tcpv6_pre_ipv6=$(get_stat QueryIPv6) && echo "$tcpv6_pre_ipv6"
  [0-9]+ (re)

  $ tcpv6_pre_noerror=$(get_stat AnswerRCodeNOERROR) && echo "$tcpv6_pre_noerror"
  [0-9]+ (re)

Get gateway IPv6 LAN address:

  $ GW_IPV6=$(R "ip -6 addr show dev br-lan | grep 'inet6' | grep -v 'fe80' | awk '{print \$2}' | cut -d'/' -f1 | head -1")
  $ echo "$GW_IPV6"
  [0-9a-f:]+ (re)

Send a DNS query over TCP:

  $ dig +tcp @192.168.1.1 example.com A > /dev/null

Send a DNS query over IPv6:

  $ dig -6 @$GW_IPV6 example.com A > /dev/null

Verify QueryTCP, QueryIPv6, TotalQueries and AnswerRCodeNOERROR incremented:

  $ assert_incremented TotalQueries "$tcpv6_pre_total" "$(get_stat TotalQueries)"
  TotalQueries incremented

  $ assert_incremented QueryTCP "$tcpv6_pre_tcp" "$(get_stat QueryTCP)"
  QueryTCP incremented

  $ assert_incremented QueryIPv6 "$tcpv6_pre_ipv6" "$(get_stat QueryIPv6)"
  QueryIPv6 incremented

  $ assert_incremented AnswerRCodeNOERROR "$tcpv6_pre_noerror" "$(get_stat AnswerRCodeNOERROR)"
  AnswerRCodeNOERROR incremented

Reset counters before SERVFAIL test:

  $ reset_stats
  Device.DNS.Relay.Stats.Reset() returned
  [
      1
  ]

Record initial statistics before blocking upstream DNS:

  $ srv_pre_total=$(get_stat TotalQueries) && echo "$srv_pre_total"
  [0-9]+ (re)

  $ srv_pre_qtype_a=$(get_stat QueryTypeA) && echo "$srv_pre_qtype_a"
  [0-9]+ (re)

  $ srv_pre_class_in=$(get_stat QueryClassIN) && echo "$srv_pre_class_in"
  [0-9]+ (re)

  $ srv_pre_opcode=$(get_stat OpcodeQUERY) && echo "$srv_pre_opcode"
  [0-9]+ (re)

  $ srv_pre_servfail=$(get_stat AnswerRCodeSERVFAIL) && echo "$srv_pre_servfail"
  [0-9]+ (re)

  $ srv_pre_noerror=$(get_stat AnswerRCodeNOERROR) && echo "$srv_pre_noerror"
  [0-9]+ (re)

  $ srv_pre_nxdomain=$(get_stat AnswerRCodeNXDOMAIN) && echo "$srv_pre_nxdomain"
  [0-9]+ (re)

Block outgoing DNS traffic (UDP and TCP port 53) on the gateway:

  $ R "iptables -I OUTPUT -p udp --dport 53 -j DROP && iptables -I OUTPUT -p tcp --dport 53 -j DROP"

Generate 10 DNS queries for unique domains (all will fail due to blocked upstream):

  $ for i in $(seq 1 10); do dig @192.168.1.1 servfail-test-$i.example.com A > /dev/null 2>&1 || true; done

Wait for all queries to time out and be processed by the relay:

  $ sleep 5

Remove the firewall rules and restore upstream DNS connectivity:

  $ R "iptables -D OUTPUT -p udp --dport 53 -j DROP && iptables -D OUTPUT -p tcp --dport 53 -j DROP"

Verify TotalQueries, QueryTypeA, QueryClassIN, OpcodeQUERY and AnswerRCodeSERVFAIL incremented:

  $ assert_incremented TotalQueries "$srv_pre_total" "$(get_stat TotalQueries)"
  TotalQueries incremented

  $ assert_incremented QueryTypeA "$srv_pre_qtype_a" "$(get_stat QueryTypeA)"
  QueryTypeA incremented

  $ assert_incremented QueryClassIN "$srv_pre_class_in" "$(get_stat QueryClassIN)"
  QueryClassIN incremented

  $ assert_incremented OpcodeQUERY "$srv_pre_opcode" "$(get_stat OpcodeQUERY)"
  OpcodeQUERY incremented

  $ assert_incremented AnswerRCodeSERVFAIL "$srv_pre_servfail" "$(get_stat AnswerRCodeSERVFAIL)"
  AnswerRCodeSERVFAIL incremented

Verify AnswerRCodeNOERROR and AnswerRCodeNXDOMAIN are unchanged:

  $ assert_unchanged AnswerRCodeNOERROR "$srv_pre_noerror" "$(get_stat AnswerRCodeNOERROR)"
  AnswerRCodeNOERROR unchanged

  $ assert_unchanged AnswerRCodeNXDOMAIN "$srv_pre_nxdomain" "$(get_stat AnswerRCodeNXDOMAIN)"
  AnswerRCodeNXDOMAIN unchanged

Reset counters before record type test:

  $ reset_stats
  Device.DNS.Relay.Stats.Reset() returned
  [
      1
  ]

Record initial statistics before record type queries:

  $ rtype_pre_total=$(get_stat TotalQueries) && echo "$rtype_pre_total"
  [0-9]+ (re)

  $ rtype_pre_a=$(get_stat QueryTypeA) && echo "$rtype_pre_a"
  [0-9]+ (re)

  $ rtype_pre_aaaa=$(get_stat QueryTypeAAAA) && echo "$rtype_pre_aaaa"
  [0-9]+ (re)

  $ rtype_pre_ptr=$(get_stat QueryTypePTR) && echo "$rtype_pre_ptr"
  [0-9]+ (re)

  $ rtype_pre_srv=$(get_stat QueryTypeSRV) && echo "$rtype_pre_srv"
  [0-9]+ (re)

  $ rtype_pre_txt=$(get_stat QueryTypeTXT) && echo "$rtype_pre_txt"
  [0-9]+ (re)

  $ rtype_pre_any=$(get_stat QueryTypeANY) && echo "$rtype_pre_any"
  [0-9]+ (re)

  $ rtype_pre_noerror=$(get_stat AnswerRCodeNOERROR) && echo "$rtype_pre_noerror"
  [0-9]+ (re)

Generate one query for each supported record type:

  $ dig @192.168.1.1 example.com A > /dev/null

  $ dig @192.168.1.1 example.com AAAA > /dev/null

  $ dig @192.168.1.1 -x 1.1.1.1 > /dev/null

  $ dig @192.168.1.1 _http._tcp.example.com SRV > /dev/null 2>&1 || true

  $ dig @192.168.1.1 example.com TXT > /dev/null

  $ dig @192.168.1.1 example.com ANY > /dev/null

Read statistics and verify each QueryType counter incremented:

  $ assert_incremented TotalQueries "$rtype_pre_total" "$(get_stat TotalQueries)"
  TotalQueries incremented

  $ assert_incremented QueryTypeA "$rtype_pre_a" "$(get_stat QueryTypeA)"
  QueryTypeA incremented

  $ assert_incremented QueryTypeAAAA "$rtype_pre_aaaa" "$(get_stat QueryTypeAAAA)"
  QueryTypeAAAA incremented

  $ assert_incremented QueryTypePTR "$rtype_pre_ptr" "$(get_stat QueryTypePTR)"
  QueryTypePTR incremented

  $ assert_incremented QueryTypeSRV "$rtype_pre_srv" "$(get_stat QueryTypeSRV)"
  QueryTypeSRV incremented

  $ assert_incremented QueryTypeTXT "$rtype_pre_txt" "$(get_stat QueryTypeTXT)"
  QueryTypeTXT incremented

  $ assert_incremented QueryTypeANY "$rtype_pre_any" "$(get_stat QueryTypeANY)"
  QueryTypeANY incremented

  $ assert_incremented AnswerRCodeNOERROR "$rtype_pre_noerror" "$(get_stat AnswerRCodeNOERROR)"
  AnswerRCodeNOERROR incremented