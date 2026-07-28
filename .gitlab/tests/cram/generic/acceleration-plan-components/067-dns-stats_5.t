Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Define helper functions:

  $ get_stat() { R "ba-cli --json 'Device.DNS.Relay.Stats.$1?' | sed -n 's/.*\"$1\":[[:space:]]*\([0-9]\+\).*/\1/p'"; }
  $ reset_stats() { R "ba-cli 'Device.DNS.Relay.Stats.Reset()' | grep -v '^>'"; }
  $ assert_incremented() { if [ "$3" -gt "$2" ]; then echo "$1 incremented"; else echo "FAIL: $1 did not increment (before=$2, after=$3)"; fi; }
  $ assert_unchanged() { if [ "$3" -eq "$2" ]; then echo "$1 unchanged"; else echo "FAIL: $1 changed unexpectedly (before=$2, after=$3)"; fi; }
  $ assert_decreased() { if [ "$3" -lt "$2" ]; then echo "$1 decreased after reset"; else echo "FAIL: $1 not decreased (before=$2, after=$3)"; fi; }

Verify DNS Record Type Statistics
Record initial statistics before record type queries:

  $ rtype_pre_total=$(get_stat TotalQueries)
  $ echo "$rtype_pre_total"
  [0-9]+ (re)

  $ rtype_pre_a=$(get_stat QueryTypeA)
  $ echo "$rtype_pre_a"
  [0-9]+ (re)

  $ rtype_pre_aaaa=$(get_stat QueryTypeAAAA)
  $ echo "$rtype_pre_aaaa"
  [0-9]+ (re)

  $ rtype_pre_ptr=$(get_stat QueryTypePTR)
  $ echo "$rtype_pre_ptr"
  [0-9]+ (re)

  $ rtype_pre_srv=$(get_stat QueryTypeSRV)
  $ echo "$rtype_pre_srv"
  [0-9]+ (re)

  $ rtype_pre_txt=$(get_stat QueryTypeTXT)
  $ echo "$rtype_pre_txt"
  [0-9]+ (re)

  $ rtype_pre_any=$(get_stat QueryTypeANY)
  $ echo "$rtype_pre_any"
  [0-9]+ (re)

  $ rtype_pre_noerror=$(get_stat AnswerRCodeNOERROR)
  $ echo "$rtype_pre_noerror"
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