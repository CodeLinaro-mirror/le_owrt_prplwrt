Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Define helper functions:

  $ get_stat() { R "ba-cli --json 'Device.DNS.Relay.Stats.$1?' | sed -n 's/.*\"$1\":[[:space:]]*\([0-9]\+\).*/\1/p'"; }
  $ reset_stats() { R "ba-cli 'Device.DNS.Relay.Stats.Reset()' | grep -v '^>'"; }
  $ assert_incremented() { if [ "$3" -gt "$2" ]; then echo "$1 incremented"; else echo "FAIL: $1 did not increment (before=$2, after=$3)"; fi; }
  $ assert_unchanged() { if [ "$3" -eq "$2" ]; then echo "$1 unchanged"; else echo "FAIL: $1 changed unexpectedly (before=$2, after=$3)"; fi; }
  $ assert_decreased() { if [ "$3" -lt "$2" ]; then echo "$1 decreased after reset"; else echo "FAIL: $1 not decreased (before=$2, after=$3)"; fi; }

Check dig is available, install dnsutils if missing:

  $ command -v dig > /dev/null 2>&1 || sudo apt-get install --yes --no-install-recommends dnsutils > /dev/null 2>&1 || true
  $ command -v dig || { echo "dig not found, install dnsutils on the test host"; exit 1; }
  .*/dig (re)

Verify Statistics for Successful A and AAAA Queries
Record initial values of DNS Relay Stats parameters:

  $ init_total=$(get_stat TotalQueries)
  $ echo "$init_total"
  [0-9]+ (re)

  $ init_qtype_a=$(get_stat QueryTypeA)
  $ echo "$init_qtype_a"
  [0-9]+ (re)

  $ init_qtype_aaaa=$(get_stat QueryTypeAAAA)
  $ echo "$init_qtype_aaaa"
  [0-9]+ (re)

  $ init_class_in=$(get_stat QueryClassIN)
  $ echo "$init_class_in"
  [0-9]+ (re)

  $ init_opcode=$(get_stat OpcodeQUERY)
  $ echo "$init_opcode"
  [0-9]+ (re)

  $ init_noerror=$(get_stat AnswerRCodeNOERROR)
  $ echo "$init_noerror"
  [0-9]+ (re)

  $ init_recursive=$(get_stat RecursiveReplies)
  $ echo "$init_recursive"
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

Reset all DNS Relay Stats counters:

  $ final_total=$(get_stat TotalQueries)
  $ final_qtype_a=$(get_stat QueryTypeA)
  $ final_qtype_aaaa=$(get_stat QueryTypeAAAA)
  $ final_class_in=$(get_stat QueryClassIN)
  $ final_opcode=$(get_stat OpcodeQUERY)
  $ reset_stats
  Device.DNS.Relay.Stats.Reset() returned
  [
      ""
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
