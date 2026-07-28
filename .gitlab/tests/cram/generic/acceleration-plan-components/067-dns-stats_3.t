Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Define helper functions:

  $ get_stat() { R "ba-cli --json 'Device.DNS.Relay.Stats.$1?' | sed -n 's/.*\"$1\":[[:space:]]*\([0-9]\+\).*/\1/p'"; }
  $ reset_stats() { R "ba-cli 'Device.DNS.Relay.Stats.Reset()' | grep -v '^>'"; }
  $ assert_incremented() { if [ "$3" -gt "$2" ]; then echo "$1 incremented"; else echo "FAIL: $1 did not increment (before=$2, after=$3)"; fi; }
  $ assert_unchanged() { if [ "$3" -eq "$2" ]; then echo "$1 unchanged"; else echo "FAIL: $1 changed unexpectedly (before=$2, after=$3)"; fi; }
  $ assert_decreased() { if [ "$3" -lt "$2" ]; then echo "$1 decreased after reset"; else echo "FAIL: $1 not decreased (before=$2, after=$3)"; fi; }

Verify Cache Hit and Cache Miss Statistics
Record statistics before cache test:

  $ cache_pre_total=$(get_stat TotalQueries)
  $ echo "$cache_pre_total"
  [0-9]+ (re)

  $ cache_pre_hits=$(get_stat CacheHits)
  $ echo "$cache_pre_hits"
  [0-9]+ (re)

  $ cache_pre_noerror=$(get_stat AnswerRCodeNOERROR)
  $ echo "$cache_pre_noerror"
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

Reset counters before SERVFAIL test:

  $ reset_stats
  Device.DNS.Relay.Stats.Reset() returned
  [
      ""
  ]