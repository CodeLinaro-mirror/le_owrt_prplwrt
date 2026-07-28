Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Define helper functions:

  $ get_stat() { R "ba-cli --json 'Device.DNS.Relay.Stats.$1?' | sed -n 's/.*\"$1\":[[:space:]]*\([0-9]\+\).*/\1/p'"; }
  $ reset_stats() { R "ba-cli 'Device.DNS.Relay.Stats.Reset()' | grep -v '^>'"; }
  $ assert_incremented() { if [ "$3" -gt "$2" ]; then echo "$1 incremented"; else echo "FAIL: $1 did not increment (before=$2, after=$3)"; fi; }
  $ assert_unchanged() { if [ "$3" -eq "$2" ]; then echo "$1 unchanged"; else echo "FAIL: $1 changed unexpectedly (before=$2, after=$3)"; fi; }
  $ assert_decreased() { if [ "$3" -lt "$2" ]; then echo "$1 decreased after reset"; else echo "FAIL: $1 not decreased (before=$2, after=$3)"; fi; }

Verify Statistics for Failed DNS Queries
Record initial statistics before blocking upstream DNS:

  $ srv_pre_total=$(get_stat TotalQueries)
  $ echo "$srv_pre_total"
  [0-9]+ (re)

  $ srv_pre_qtype_a=$(get_stat QueryTypeA)
  $ echo "$srv_pre_qtype_a"
  [0-9]+ (re)

  $ srv_pre_class_in=$(get_stat QueryClassIN)
  $ echo "$srv_pre_class_in"
  [0-9]+ (re)

  $ srv_pre_opcode=$(get_stat OpcodeQUERY)
  $ echo "$srv_pre_opcode"
  [0-9]+ (re)

  $ srv_pre_servfail=$(get_stat AnswerRCodeSERVFAIL)
  $ echo "$srv_pre_servfail"
  [0-9]+ (re)

  $ srv_pre_noerror=$(get_stat AnswerRCodeNOERROR)
  $ echo "$srv_pre_noerror"
  [0-9]+ (re)

  $ srv_pre_nxdomain=$(get_stat AnswerRCodeNXDOMAIN)
  $ echo "$srv_pre_nxdomain"
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
      ""
  ]