Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Record initial values of DNS Relay Stats parameters:

  $ init_total=$(R "ba-cli --json 'DNS.Relay.Stats.TotalQueries?' | sed -n 's/.*\"TotalQueries\":\([0-9]*\).*/\1/p'")
  $ echo "$init_total"
  [0-9]+ (re)

  $ init_qtype_a=$(R "ba-cli --json 'DNS.Relay.Stats.QueryTypeA?' | sed -n 's/.*\"QueryTypeA\":\([0-9]*\).*/\1/p'")
  $ echo "$init_qtype_a"
  [0-9]+ (re)

  $ init_qtype_aaaa=$(R "ba-cli --json 'DNS.Relay.Stats.QueryTypeAAAA?' | sed -n 's/.*\"QueryTypeAAAA\":\([0-9]*\).*/\1/p'")
  $ echo "$init_qtype_aaaa"
  [0-9]+ (re)

  $ init_class_in=$(R "ba-cli --json 'DNS.Relay.Stats.QueryClassIN?' | sed -n 's/.*\"QueryClassIN\":\([0-9]*\).*/\1/p'")
  $ echo "$init_class_in"
  [0-9]+ (re)

  $ init_opcode=$(R "ba-cli --json 'DNS.Relay.Stats.OpcodeQUERY?' | sed -n 's/.*\"OpcodeQUERY\":\([0-9]*\).*/\1/p'")
  $ echo "$init_opcode"
  [0-9]+ (re)

  $ init_noerror=$(R "ba-cli --json 'DNS.Relay.Stats.AnswerRCodeNOERROR?' | sed -n 's/.*\"AnswerRCodeNOERROR\":\([0-9]*\).*/\1/p'")
  $ echo "$init_noerror"
  [0-9]+ (re)

  $ init_recursive=$(R "ba-cli --json 'DNS.Relay.Stats.RecursiveReplies?' | sed -n 's/.*\"RecursiveReplies\":\([0-9]*\).*/\1/p'")
  $ echo "$init_recursive"
  [0-9]+ (re)

Execute an IPv4 (A record) lookup through the DNS relay:

  $ dig @192.168.1.1 example.com A  > /dev/null

Execute an IPv6 (AAAA record) lookup through the DNS relay:

  $ dig @192.168.1.1 example.com AAAA > /dev/null

Read all statistics parameters and verify they have incremented:

  $ final_total=$(R "ba-cli --json 'DNS.Relay.Stats.TotalQueries?' | sed -n 's/.*\"TotalQueries\":\([0-9]*\).*/\1/p'")
  $ if [ "$final_total" -gt "$init_total" ]; then echo "TotalQueries incremented"; else echo "FAIL: TotalQueries did not increment (init=$init_total, final=$final_total)"; fi
  TotalQueries incremented

  $ final_qtype_a=$(R "ba-cli --json 'DNS.Relay.Stats.QueryTypeA?' | sed -n 's/.*\"QueryTypeA\":\([0-9]*\).*/\1/p'")
  $ if [ "$final_qtype_a" -gt "$init_qtype_a" ]; then echo "QueryTypeA incremented"; else echo "FAIL: QueryTypeA did not increment (init=$init_qtype_a, final=$final_qtype_a)"; fi
  QueryTypeA incremented

  $ final_qtype_aaaa=$(R "ba-cli --json 'DNS.Relay.Stats.QueryTypeAAAA?' | sed -n 's/.*\"QueryTypeAAAA\":\([0-9]*\).*/\1/p'")
  $ if [ "$final_qtype_aaaa" -gt "$init_qtype_aaaa" ]; then echo "QueryTypeAAAA incremented"; else echo "FAIL: QueryTypeAAAA did not increment (init=$init_qtype_aaaa, final=$final_qtype_aaaa)"; fi
  QueryTypeAAAA incremented

  $ final_class_in=$(R "ba-cli --json 'DNS.Relay.Stats.QueryClassIN?' | sed -n 's/.*\"QueryClassIN\":\([0-9]*\).*/\1/p'")
  $ if [ "$final_class_in" -gt "$init_class_in" ]; then echo "QueryClassIN incremented"; else echo "FAIL: QueryClassIN did not increment (init=$init_class_in, final=$final_class_in)"; fi
  QueryClassIN incremented

  $ final_opcode=$(R "ba-cli --json 'DNS.Relay.Stats.OpcodeQUERY?' | sed -n 's/.*\"OpcodeQUERY\":\([0-9]*\).*/\1/p'")
  $ if [ "$final_opcode" -gt "$init_opcode" ]; then echo "OpcodeQUERY incremented"; else echo "FAIL: OpcodeQUERY did not increment (init=$init_opcode, final=$final_opcode)"; fi
  OpcodeQUERY incremented

Reset all DNS Relay Stats counters:

  $ R "ba-cli 'DNS.Relay.Stats.Reset()' | grep -v '^>'"
  DNS.Relay.Stats.Reset() returned

Verify all statistics parameters are reset to 0:

  $ R "ba-cli --json 'DNS.Relay.Stats.TotalQueries?' | sed -n 's/.*\"TotalQueries\":\([0-9]*\).*/\1/p'"
  0

  $ R "ba-cli --json 'DNS.Relay.Stats.QueryTypeA?' | sed -n 's/.*\"QueryTypeA\":\([0-9]*\).*/\1/p'"
  0

  $ R "ba-cli --json 'DNS.Relay.Stats.QueryTypeAAAA?' | sed -n 's/.*\"QueryTypeAAAA\":\([0-9]*\).*/\1/p'"
  0

  $ R "ba-cli --json 'DNS.Relay.Stats.QueryClassIN?' | sed -n 's/.*\"QueryClassIN\":\([0-9]*\).*/\1/p'"
  0

  $ R "ba-cli --json 'DNS.Relay.Stats.OpcodeQUERY?' | sed -n 's/.*\"OpcodeQUERY\":\([0-9]*\).*/\1/p'"
  0