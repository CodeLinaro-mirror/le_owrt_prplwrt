Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Define helper functions:

  $ get_stat() { R "ba-cli --json 'Device.DNS.Relay.Stats.$1?' | sed -n 's/.*\"$1\":[[:space:]]*\([0-9]\+\).*/\1/p'"; }
  $ reset_stats() { R "ba-cli 'Device.DNS.Relay.Stats.Reset()' | grep -v '^>'"; }
  $ assert_incremented() { if [ "$3" -gt "$2" ]; then echo "$1 incremented"; else echo "FAIL: $1 did not increment (before=$2, after=$3)"; fi; }
  $ assert_unchanged() { if [ "$3" -eq "$2" ]; then echo "$1 unchanged"; else echo "FAIL: $1 changed unexpectedly (before=$2, after=$3)"; fi; }
  $ assert_decreased() { if [ "$3" -lt "$2" ]; then echo "$1 decreased after reset"; else echo "FAIL: $1 not decreased (before=$2, after=$3)"; fi; }

Verify Statistics for NXDOMAIN Responses
Record current statistics before NXDOMAIN test:

  $ pre_nx_total=$(get_stat TotalQueries)
  $ echo "$pre_nx_total"
  [0-9]+ (re)

  $ pre_nx_qtype_a=$(get_stat QueryTypeA)
  $ echo "$pre_nx_qtype_a"
  [0-9]+ (re)

  $ pre_nx_nxdomain=$(get_stat AnswerRCodeNXDOMAIN)
  $ echo "$pre_nx_nxdomain"
  [0-9]+ (re)

  $ pre_nx_noerror=$(get_stat AnswerRCodeNOERROR)
  $ echo "$pre_nx_noerror"
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
      ""
  ]