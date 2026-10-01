Device.Users.CreateNewUser() must reject a username that does not match the
username policy (SEC-16). The handler passed Username straight into
putpwent(), so a colon forged extra /etc/passwd fields and a newline forged a
whole extra line. On an unfixed build the colon payload below lands in
/etc/passwd as a line that parses to uid 0, gid 0, home /root, shell /bin/ash:
a root account created by a single RPC call.

The validation lives inside the RPC and is role independent, so this drives it
over the root bus. Each attempt asserts the effect on /etc/passwd rather than an
error string, so the test stays valid however the rejection is signalled.

Username policy (tr181-usermanagement MR 27): 1 to 64 characters, a letter
first, then letters, digits, ".", "_" and "-". To change the policy, change
MINLEN and MAXLEN. The regex and the boundary names below follow from them:

  $ MINLEN=1 MAXLEN=64
  $ RPC_MAXLEN=$((MAXLEN-5))
  $ REGEX="^[a-zA-Z][A-Za-z0-9._-]{$((MINLEN-1)),$((MAXLEN-1))}\$"

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Record the /etc/passwd line count before any injection attempt:

  $ before=$(R "wc -l < /etc/passwd")

A colon forges extra passwd fields. It must be rejected:

  $ R "ba-cli 'Device.Users.CreateNewUser(Username=\"sec16colon:x:0:0:r:/root:/bin/ash\",Password=\"password\")'" > /dev/null 2>&1 || true
  $ sleep 1
  $ R "grep sec16colon /etc/passwd"
  [1]

A newline forges an entire extra passwd line. It must be rejected:

  $ R "ba-cli 'Device.Users.CreateNewUser(Username=\"sec16nl\nsec16root:x:0:0:r:/root:/bin/ash\",Password=\"password\")'" > /dev/null 2>&1 || true
  $ sleep 1
  $ R "grep sec16root /etc/passwd"
  [1]

No rejected attempt may have added a passwd line:

  $ after=$(R "wc -l < /etc/passwd"); [ "$after" = "$before" ] && echo unchanged || echo "CHANGED $before -> $after"
  unchanged

Positive control: a plain alphanumeric username is still accepted, proving the
RPC itself works and only the invalid names above are refused:

  $ R "ba-cli 'Device.Users.CreateNewUser(Username=\"sec16valid\",Password=\"password\")'" > /dev/null 2>&1
  $ sleep 1
  $ R "grep -c '^sec16valid:' /etc/passwd"
  1

Remove the user again and assert it is gone:

  $ idx=$(R "ba-cli 'Device.Users.User.?'" 2>/dev/null | sed -n 's/^Device\.Users\.User\.\([0-9]*\)\.Username="sec16valid"$/\1/p' | head -1)
  $ printf "\
  > ba-cli Users.User.$idx.-
  > " > /tmp/cram
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/cram)'" < /dev/null > /dev/null 2>&1
  $ sleep 1
  $ R "grep '^sec16valid:' /etc/passwd"
  [1]

The checks below cover the review findings of tr181-usermanagement MR 27
and the policy boundaries. Each name states the property under test, and
the boundary names follow from MINLEN and MAXLEN:

  $ repeat() { s=; i=0; while [ $i -lt $1 ]; do s="$s$2"; i=$((i+1)); done; printf %s "$s"; }
  $ PASSWORD='Sec16.Passw0rd'
  $ NAME_LEADING_SPACE=' root'
  $ NAME_TRAILING_SPACE='root '
  $ NAME_32_SPACES_ROOT="$(repeat 32 ' ')root"
  $ NAME_MIN_LENGTH=q$(repeat $((MINLEN-1)) a)
  $ NAME_8_CHARS=sec16d08
  $ NAME_MAX_LENGTH=sec16d$(repeat $((MAXLEN-6)) a)
  $ NAME_TOO_LONG=${NAME_MAX_LENGTH}x
  $ NAME_RPC_MAX_LENGTH=sec16r$(repeat $((RPC_MAXLEN-6)) a)
  $ NAME_RPC_TOO_LONG=${NAME_RPC_MAX_LENGTH}x
  $ NAME_WITH_UNDERSCORE=sec16d_u
  $ NAME_WITH_HYPHEN=sec16d-h
  $ NAME_WITH_DOT=sec16d.d
  $ NAME_LEADING_DIGIT_UUID=550e8400-e29b-41d4-a716-446655440000
  $ NAME_VALID=sec16valid
  $ ALIAS_TOO_LONG=$(repeat $((MAXLEN+1)) z)
  $ ALIAS_FOR_UUID_INSTANCE=sec16uuid

ba-cli turns the argument Username="root\ " into the account name "rootr"
(a stray byte). The test does not send that argument, but the cleanup
removes such a leftover of an older run:

  $ NAME_STRAY_BYTE_LEFTOVER=rootr

The names have the intended lengths, and the policy regex agrees with the
expected result for each name:

  $ [ ${#NAME_MIN_LENGTH} -eq $MINLEN ] && [ ${#NAME_MAX_LENGTH} -eq $MAXLEN ] && [ ${#NAME_TOO_LONG} -eq $((MAXLEN+1)) ] && [ ${#ALIAS_TOO_LONG} -eq $((MAXLEN+1)) ] && echo lengths-ok
  lengths-ok
  $ for n in "$NAME_MIN_LENGTH" "$NAME_8_CHARS" "$NAME_MAX_LENGTH" "$NAME_RPC_MAX_LENGTH" "$NAME_WITH_UNDERSCORE" "$NAME_WITH_HYPHEN" "$NAME_WITH_DOT"; do
  >   echo "$n" | grep -Eq "$REGEX" || echo "regex rejects valid name $n"
  > done
  $ for n in "$NAME_TOO_LONG" "$NAME_LEADING_DIGIT_UUID" "$ALIAS_TOO_LONG"; do
  >   echo "$n" | grep -Eq "$REGEX" && echo "regex accepts invalid name $n"
  > done; true

Helpers. They call the remote command directly, because an alias is not
always expanded inside a function. ba-cli exits 0 also after an error, so
each remote command ends with "echo rc=$?". A missing rc line means that
the transport failed. A failed transport or bus query prints ERR,
NO-STATUS or NO-TRANSPORT, so it never reads as a valid result. A listing
counts only if it has no ERROR line and has rows or says "No data found".

users_rpc prints the Status of one Users RPC, and the error code if the
call failed. user_add adds an instance directly and prints 0 or the error
of the add.

ba-cli trims a Name="value" argument and cannot pass a trailing space, so
a name with a leading or trailing space goes over "ubus call" as JSON:

  $ RC="${CRAM_REMOTE_COMMAND:-}"
  $ users_rpc() {
  >   case "$2" in
  >     " "*|*" ") $RC "ubus call Users $1 '{\"Username\":\"$2\",\"Password\":\"$PASSWORD\"}' 2>&1; echo rc=\$?";;
  >     *) $RC "ba-cli 'Users.$1(Username=\"$2\",Password=\"$PASSWORD\")' 2>&1; echo rc=\$?";;
  >   esac 2>/dev/null |
  >     awk '/^ *Status = /{s=$3} /"Status":/{s=$2} /"amxd-error-code": *[1-9]/{e=$2}
  >       /^ERROR/{e=$0; sub(/.*failed with status /, "", e); sub(/ .*/, "", e)} /^rc=/{r=1}
  >       END{gsub(/[",]/, "", s); if(!r) print "NO-TRANSPORT"; else print (s=="" ? "NO-STATUS" : s) (e=="" ? "" : " error " e)}'
  > }
  $ user_add() {
  >   $RC "ba-cli 'Users.User.+{Username=\"$1\",Alias=\"$2\"}' 2>&1; echo rc=\$?" 2>/dev/null |
  >     awk '/^ERROR/{e=$0; sub(/.*failed \(/, "", e); sub(/\)$/, "", e); sub(/ - /, " ", e)} /^Users\.User\.[0-9]+\.$/{ok=1} /^rc=/{r=1}
  >       END{if(!r) print "NO-TRANSPORT"; else if(e!="") print "error " e; else print (ok ? 0 : "NO-OUTPUT")}'
  > }

The helpers never put a test name into a datamodel filter: the filter
Username==" root" trims the spaces and matches the root account.
user_indexes lists all instances and compares the value exactly on the
host. user_delete deletes only those instance numbers:

  $ user_indexes() {
  >   $RC "ba-cli 'Users.User.*.$1?' 2>&1; echo rc=\$?" 2>/dev/null |
  >     awk -v p="$1" -v n="$2" '
  >       /^Users\.User\.[0-9]+\./{rows=1; i=index($0, "." p "=\""); if(i){v=substr($0, i+length(p)+3); sub(/"$/, "", v); if(v==n){split($0, a, "."); ids=ids a[3] "\n"}}}
  >       /^No data found$/{nodata=1} /^ERROR/{err=1} /^rc=/{r=1}
  >       END{if(!r || err || (!rows && !nodata)) print "ERR"; else printf "%s", ids}'
  > }
  $ user_instances() { r=$(user_indexes "$1" "$2"); case "$r" in *ERR*) echo ERR;; "") echo 0;; *) echo "$r" | wc -l | tr -d ' ';; esac; }
  $ user_delete() { for i in $(user_indexes "$1" "$2"); do [ "$i" = ERR ] || $RC "ba-cli 'Users.User.$i.-'" > /dev/null 2>&1; done; true; }
  $ passwd_entries() { $RC "awk -F: -v n='$1' '\$1==n{c++} END{print c+0}' /etc/passwd" 2>/dev/null || echo ERR; }
  $ passwd_checksum() { $RC "md5sum < /etc/passwd" 2>/dev/null | awk 'NR==1 && length($1)==32 && $1 !~ /[^0-9a-f]/ {h=$1} END{print (h=="" ? "ERR" : h)}'; }
  $ user_instances_total() {
  >   $RC "ba-cli 'Users.User.*.Alias?' 2>&1; echo rc=\$?" 2>/dev/null |
  >     awk '/^Users\.User\.[0-9]+\.Alias=/{n++} /^No data found$/{z=1} /^ERROR/{e=1} /^rc=/{r=1} END{if(!r || e || (!n && !z)) print "ERR"; else print n+0}'
  > }

expect_rejected tries to create the name with CreateNewUser. With a third
argument, it adds an instance with that Alias instead. It then counts the
passwd entries of the account name and the instances with that name. The
result reads "rejected" only if the call failed and both counts are 0.
expect_accepted reads "accepted" only if CreateNewUser returned Status 0
and both counts are 1. With a third argument, it adds an instance with a
short Alias directly to test the datamodel maximum:

  $ expect_rejected() {
  >   if [ $# -eq 3 ]; then status=$(user_add "$2" "$3"); sleep 1; passwd=$(passwd_entries "${2:-$3}"); instances=$(user_instances Alias "$3")
  >   else status=$(users_rpc CreateNewUser "$2"); sleep 1; passwd=$(passwd_entries "$2"); instances=$(user_instances Username "$2"); fi
  >   case "$status/$passwd/$instances" in 0/*|NO-*) verdict="NOT rejected";; */0/0) verdict=rejected;; *) verdict="NOT rejected";; esac
  >   echo "$verdict: $1 ($status, passwd=$passwd, instances=$instances)"
  > }
  $ expect_accepted() {
  >   if [ $# -eq 3 ]; then status=$(user_add "$2" "$3"); else status=$(users_rpc CreateNewUser "$2"); fi
  >   sleep 1; passwd=$(passwd_entries "$2"); instances=$(user_instances Username "$2")
  >   if [ "$status/$passwd/$instances" = 0/1/1 ]; then echo "accepted: $1 (passwd=1, instances=1)"; else echo "NOT accepted: $1 ($status, passwd=$passwd, instances=$instances)"; fi
  > }

cleanup_test_users deletes every test name, by Username and by Alias.
leftover_test_users prints each test name that still has a passwd entry or
an instance:

  $ cleanup_test_users() {
  >   for n in "$NAME_LEADING_SPACE" "$NAME_TRAILING_SPACE" "$NAME_32_SPACES_ROOT" "$NAME_MIN_LENGTH" "$NAME_8_CHARS" "$NAME_MAX_LENGTH" \
  >     "$NAME_TOO_LONG" "$NAME_RPC_MAX_LENGTH" "$NAME_RPC_TOO_LONG" "$NAME_WITH_UNDERSCORE" "$NAME_WITH_HYPHEN" "$NAME_WITH_DOT" "$NAME_LEADING_DIGIT_UUID" "$NAME_VALID" "$NAME_STRAY_BYTE_LEFTOVER"; do
  >     user_delete Username "$n"
  >   done
  >   for a in "$ALIAS_TOO_LONG" "$ALIAS_FOR_UUID_INSTANCE"; do user_delete Alias "$a"; done
  > }
  $ leftover_test_users() {
  >   for n in "$NAME_LEADING_SPACE" "$NAME_TRAILING_SPACE" "$NAME_32_SPACES_ROOT" "$NAME_MIN_LENGTH" "$NAME_8_CHARS" "$NAME_MAX_LENGTH" \
  >     "$NAME_TOO_LONG" "$NAME_RPC_MAX_LENGTH" "$NAME_RPC_TOO_LONG" "$NAME_WITH_UNDERSCORE" "$NAME_WITH_HYPHEN" "$NAME_WITH_DOT" "$NAME_LEADING_DIGIT_UUID" "$NAME_VALID" "$NAME_STRAY_BYTE_LEFTOVER"; do
  >     r="$(passwd_entries "$n") $(user_instances Username "$n")"; [ "$r" = "0 0" ] || echo "left: '$n' passwd/instances $r"
  >   done
  >   for a in "$ALIAS_TOO_LONG" "$ALIAS_FOR_UUID_INSTANCE"; do
  >     r="$(passwd_entries "$a") $(user_instances Alias "$a")"; [ "$r" = "0 0" ] || echo "left: alias '$a' passwd/instances $r"
  >   done
  > }

Remove leftovers of an earlier run on a persistent disk, then record the
number of Users.User instances and the /etc/passwd checksum:

  $ cleanup_test_users; sleep 1
  $ TOTAL_BEFORE=$(user_instances_total) CHECKSUM_BEFORE=$(passwd_checksum)
  $ echo "$TOTAL_BEFORE $CHECKSUM_BEFORE" | grep -Eq '^[0-9]+ [0-9a-f]{32}$' && echo baseline-ok
  baseline-ok

The RPCs must not trim spaces before the check (MR 27 thread bf60c497).
A name with a leading or trailing space, or with 32 leading spaces, is not
a valid username. CheckCredentialsDiagnostics must report invalid input,
not a password mismatch for "root":

  $ users_rpc CheckCredentialsDiagnostics "$NAME_LEADING_SPACE"
  Error_Invalid_Input
  $ users_rpc CheckCredentialsDiagnostics "$NAME_TRAILING_SPACE"
  Error_Invalid_Input
  $ users_rpc CheckCredentialsDiagnostics "$NAME_32_SPACES_ROOT"
  Error_Invalid_Input

CreateNewUser must reject the same names and change nothing:

  $ expect_rejected "leading space" "$NAME_LEADING_SPACE"
  rejected: leading space (Error_Invalid_Input error 1, passwd=0, instances=0)
  $ expect_rejected "trailing space" "$NAME_TRAILING_SPACE"
  rejected: trailing space (Error_Invalid_Input error 1, passwd=0, instances=0)
  $ expect_rejected "32 spaces before root" "$NAME_32_SPACES_ROOT"
  rejected: 32 spaces before root (Error_Invalid_Input error 1, passwd=0, instances=0)
  $ TOTAL_NOW=$(user_instances_total) CHECKSUM_NOW=$(passwd_checksum)
  $ [ "$TOTAL_NOW" != ERR ] && [ "$CHECKSUM_NOW" != ERR ] && [ "$TOTAL_NOW $CHECKSUM_NOW" = "$TOTAL_BEFORE $CHECKSUM_BEFORE" ] && echo unchanged || echo "changed: $TOTAL_BEFORE $CHECKSUM_BEFORE -> $TOTAL_NOW $CHECKSUM_NOW"
  unchanged

An empty Username makes the Alias the system account name. The Alias must
then follow the same policy (MR 27 thread 32da252d). An over-long Alias
with an empty Username must be rejected, with no account and no instance:

  $ expect_rejected "alias over MAXLEN, empty username" "" "$ALIAS_TOO_LONG"
  rejected: alias over MAXLEN, empty username (error 10 invalid value, passwd=0, instances=0)

The datamodel accepts up to MAXLEN characters with a short Alias.
CreateNewUser appends "-user" to the Alias, so its maximum is RPC_MAXLEN.
A 59-character RPC name succeeds. A 60-character RPC name fails.
Each accepted name gets an account and an instance:

  $ expect_accepted "MINLEN characters" "$NAME_MIN_LENGTH"
  accepted: MINLEN characters (passwd=1, instances=1)
  $ expect_accepted "8 characters" "$NAME_8_CHARS"
  accepted: 8 characters (passwd=1, instances=1)
  $ expect_accepted "MAXLEN characters" "$NAME_MAX_LENGTH" sec16max
  accepted: MAXLEN characters (passwd=1, instances=1)
  $ expect_accepted "RPC maximum characters" "$NAME_RPC_MAX_LENGTH"
  accepted: RPC maximum characters (passwd=1, instances=1)
  $ expect_rejected "one character over RPC maximum" "$NAME_RPC_TOO_LONG"
  rejected: one character over RPC maximum (1, passwd=0, instances=0)
  $ expect_accepted "underscore" "$NAME_WITH_UNDERSCORE"
  accepted: underscore (passwd=1, instances=1)
  $ expect_accepted "hyphen" "$NAME_WITH_HYPHEN"
  accepted: hyphen (passwd=1, instances=1)
  $ expect_accepted "dot" "$NAME_WITH_DOT"
  accepted: dot (passwd=1, instances=1)

Delete them again. Both the account and the instance must be gone:

  $ for n in "$NAME_MIN_LENGTH" "$NAME_8_CHARS" "$NAME_MAX_LENGTH" "$NAME_RPC_MAX_LENGTH" "$NAME_WITH_UNDERSCORE" "$NAME_WITH_HYPHEN" "$NAME_WITH_DOT"; do user_delete Username "$n"; done; sleep 1
  $ for n in "$NAME_MIN_LENGTH" "$NAME_8_CHARS" "$NAME_MAX_LENGTH" "$NAME_RPC_MAX_LENGTH" "$NAME_WITH_UNDERSCORE" "$NAME_WITH_HYPHEN" "$NAME_WITH_DOT"; do
  >   echo "$n passwd=$(passwd_entries "$n") instances=$(user_instances Username "$n")"
  > done | grep -v ' passwd=0 instances=0$' || echo deleted
  deleted

A name one character over MAXLEN and a name that starts with a digit (a
UUID) are rejected by CreateNewUser:

  $ expect_rejected "one character over MAXLEN" "$NAME_TOO_LONG"
  rejected: one character over MAXLEN (Error_Invalid_Input error 1, passwd=0, instances=0)
  $ expect_rejected "leading digit (UUID)" "$NAME_LEADING_DIGIT_UUID"
  rejected: leading digit (UUID) (Error_Invalid_Input error 1, passwd=0, instances=0)

The UUID is also rejected as the Username of a directly added instance:

  $ expect_rejected "UUID username of an added instance" "$NAME_LEADING_DIGIT_UUID" "$ALIAS_FOR_UUID_INSTANCE"
  rejected: UUID username of an added instance (error 10 invalid value, passwd=0, instances=0)

Clean up, also after a failed run. No test account or instance may be left,
and the number of Users.User instances must be back at the baseline:

  $ cleanup_test_users; sleep 1
  $ { leftover_test_users; [ "$(user_instances_total)" = "$TOTAL_BEFORE" ] || echo "instances: $TOTAL_BEFORE -> $(user_instances_total)"; } | grep . || echo clean
  clean
