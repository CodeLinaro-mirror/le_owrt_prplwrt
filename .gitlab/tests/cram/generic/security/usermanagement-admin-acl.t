The admin role reaches Device.Users over the REST interface only through the admin
ACL of tr181-usermanagement. Since v0.31.2 (tr181-usermanagement MR 26) that ACL no
longer lets the admin call Device.Users.CreateNewUser() or write non-static user
instances. The admin keeps read access to its own instance and may write its own
Password. This test checks both sides over REST. It uses the root bus only for the
setup, the positive control and the cleanup.

Helpers. Every remote call and every HTTP request has a deadline. A bus or passwd
read counts only if it succeeded and returned the always present admin or root
entry, so an empty read is never taken as absence:

  $ R() { timeout 30 $CRAM_REMOTE_COMMAND "$@"; }
  $ base="http://$TARGET_LAN_IP"
  $ code() { timeout 15 curl -s -o /dev/null -w '%{http_code}\n' --max-time 10 "$@"; }
  $ body() { timeout 15 curl -s --max-time 10 "$@"; }
  $ users() { u=$(R "ubus-cli 'Device.Users.User.?'") && printf '%s\n' "$u" | grep -q '\.Username="admin"$' && printf '%s\n' "$u"; }
  $ passwd() { p=$(R "cat /etc/passwd") && printf '%s\n' "$p" | grep -q '^root:' && printf '%s\n' "$p"; }
  $ esc() { printf '%s' "$1" | sed 's/[.]/\\./g'; }
  $ get() { v=$(R "ubus-cli 'Device.Users.$1?'") && printf '%s\n' "$v" | sed -nE "s/^Device\.Users\.$(esc "$1")=\"?([^\"]*)\"?$/\1/p"; }
  $ idx() { users | sed -nE "s/^Device\.Users\.User\.([0-9]+)\.Username=\"$1\"$/\1/p"; }
  $ path_by() { v=$(R "ubus-cli 'Device.Users.$1.?'") && printf '%s\n' "$v" | sed -nE "s#^Device\.Users\.$1\.([0-9]+)\.$2=\"$3\"\$#Users.$1.\1#p"; }
  $ need() { [ "$(printf '%s\n' "$2" | grep -cxE "$3")" = 1 ] || { echo "prerequisite failed: $1"; exit 1; }; }
  $ owned='sec27(target|denied|addpst|rootctl)'
  $ restore=0
  $ cleanup() {
  >   rc=0
  >   if [ "$restore" = 1 ]; then
  >     [ "$(get User.$aidx.Shell)" = "$ashell" ] || R "ubus-cli \"Device.Users.User.$aidx.Shell='$ashell'\"" >/dev/null 2>&1 || { echo "cleanup: restore of Shell failed"; rc=1; }
  >     [ "$(get User.$aidx.GroupParticipation)" = "$agrp" ] || R "ubus-cli \"Device.Users.User.$aidx.GroupParticipation='$agrp'\"" >/dev/null 2>&1 || { echo "cleanup: restore of GroupParticipation failed"; rc=1; }
  >     [ "$(get User.$aidx.RoleParticipation)" = "$arole" ] || R "ubus-cli \"Device.Users.User.$aidx.RoleParticipation='$arole'\"" >/dev/null 2>&1 || { echo "cleanup: restore of RoleParticipation failed"; rc=1; }
  >   fi
  >   cu=$(users) || { echo "cleanup: bus read failed"; return 1; }
  >   for i in $(printf '%s\n' "$cu" | sed -nE "s/^Device\.Users\.User\.([0-9]+)\.Username=\"$owned\"$/\1/p"); do
  >     R "ubus-cli 'Device.Users.User.$i.-'" >/dev/null 2>&1 || { echo "cleanup: delete of Device.Users.User.$i. failed"; rc=1; }
  >   done
  >   return $rc
  > }

Remove what an aborted earlier run may have left, and check that the owned names
and the UIDs 27001 and 27003 are free. Each check ends the test with a
"prerequisite failed" line if it does not hold:

  $ cleanup || { echo "prerequisite failed: cleanup"; exit 1; }
  $ sleep 2
  $ u=$(users) || { echo "prerequisite failed: bus read"; exit 1; }
  $ if printf '%s\n' "$u" | grep -qE "Username=\"$owned\""; then echo "prerequisite failed: owned users left on the bus"; exit 1; fi
  $ if printf '%s\n' "$u" | grep -qE '\.UserID=(27001|27003)$'; then echo "prerequisite failed: UID 27001 or 27003 in use on the bus"; exit 1; fi
  $ p=$(passwd) || { echo "prerequisite failed: passwd read"; exit 1; }
  $ if printf '%s\n' "$p" | grep -qE "^$owned:"; then echo "prerequisite failed: owned users left in passwd"; exit 1; fi
  $ if printf '%s\n' "$p" | cut -d: -f3 | grep -qxE '27001|27003'; then echo "prerequisite failed: UID 27001 or 27003 in passwd"; exit 1; fi

Resolve the admin and root instances, save the admin's current references and
resolve the valid values for the denied writes by name (indices differ per
board). Only then install the cleanup trap, before the first user is created:

  $ aidx=$(idx admin); ridx=$(idx root)
  $ need admin-index "$aidx" '[0-9]+'; need root-index "$ridx" '[0-9]+'
  $ need admin-static "$(get User.$aidx.StaticUser)" 1
  $ ashell=$(get User.$aidx.Shell); agrp=$(get User.$aidx.GroupParticipation); arole=$(get User.$aidx.RoleParticipation)
  $ need admin-shell "$ashell" 'Users\.SupportedShell\.[0-9]+'
  $ need admin-groups "$agrp" "Users\.Group\.[0-9]+(,Users\.Group\.[0-9]+)*"
  $ need admin-roles "$arole" "Users\.Role\.[0-9]+(,Users\.Role\.[0-9]+)*"
  $ ash=$(path_by SupportedShell Name /bin/ash); gusers=$(path_by Group Groupname users); rguest=$(path_by Role RoleName guest)
  $ need ash-shell "$ash" 'Users\.SupportedShell\.[0-9]+'
  $ need users-group "$gusers" 'Users\.Group\.[0-9]+'
  $ need guest-role "$rguest" 'Users\.Role\.[0-9]+'
  $ restore=1
  $ trap 'cleanup || echo "cleanup incomplete" >&2' EXIT; trap 'exit 1' INT TERM

Create the runtime user (StaticUser 0) that the admin must not reach, and record
the baselines:

  $ R "ubus-cli \"Device.Users.User.+{UserID=27001,Username='sec27target',Alias='sec27target',Password='sec27Pass0',Enable=1}\"" >/dev/null
  $ for i in $(seq 10); do R "grep -q '^sec27target:x:27001:' /etc/passwd" && break; sleep 1; done
  $ need target-passwd "$(passwd | grep -c '^sec27target:x:27001:')" 1
  $ tidx=$(idx sec27target)
  $ need target-index "$tidx" '[0-9]+'
  $ need target-static "$(get User.$tidx.StaticUser)" 0
  $ tshell=$(get User.$tidx.Shell)
  $ need target-shell "$tshell" 'Users\.SupportedShell\.[0-9]+'
  $ [ "$tshell" != "$ash" ] || { echo "prerequisite failed: target already has /bin/ash"; exit 1; }
  $ n0=$(users | grep -c '^Device\.Users\.User\.[0-9]*\.Username='); p0=$(passwd | wc -l)
  $ need baselines "$n0 $p0" '[1-9][0-9]* [1-9][0-9]*'

The admin REST login must work before any denial means anything. An invalid
bearer token is refused (observed on QEMU x86-64):

  $ pw=admin
  $ code -X POST "$base/session" --data "{\"username\":\"admin\",\"password\":\"$pw\"}"
  200
  $ token=$(body -X POST "$base/session" --data "{\"username\":\"admin\",\"password\":\"$pw\"}" | jq -r .sessionID)
  $ need login "$token" '[^[:space:]]{16,}'
  $ auth="Authorization: bearer $token"; json='Content-Type: application/json'
  $ code -H 'Authorization: bearer invalid0000' "$base/serviceElements/Device.Users.User.$aidx."
  401

The admin must not be able to call CreateNewUser, and the refused call must not
create anything:

  $ code -X POST -H "$auth" -H "$json" "$base/commands" --data '{"sendresp":true,"command":"Device.Users.CreateNewUser()","inputArgs":{"Username":"sec27denied","Password":"sec27Pass0"}}'
  403
  $ sleep 2
  $ p=$(passwd) || { echo "passwd read failed"; exit 1; }
  $ printf '%s\n' "$p" | grep '^sec27denied:'
  [1]
  $ echo $(( $(users | grep -c '^Device\.Users\.User\.[0-9]*\.Username=') - n0 )) $(( $(printf '%s\n' "$p" | wc -l) - p0 ))
  0 0

The admin must not read the runtime user, another static user, or the user table:

  $ code -H "$auth" "$base/serviceElements/Device.Users.User.$tidx."
  403
  $ code -H "$auth" "$base/serviceElements/Device.Users.User.$tidx.Username"
  403
  $ code -H "$auth" "$base/serviceElements/Device.Users.User.$ridx."
  403
  $ code -H "$auth" "$base/serviceElements/Device.Users.User."
  403

Searches: the admin finds its own instance by name, a search over all users
returns nothing to it, and a search for the runtime users is refused:

  $ q() { jq -rn --arg p "$1" '$p|@uri'; }
  $ code -H "$auth" "$base/serviceElements/$(q "Device.Users.User.[Username=='admin'].")"
  200
  $ body -H "$auth" "$base/serviceElements/$(q "Device.Users.User.[Username=='admin'].")" | jq -r '[.[].parameters.Username] | join(",")'
  admin
  $ code -H "$auth" "$base/serviceElements/Device.Users.User.*."
  200
  $ echo "$(body -H "$auth" "$base/serviceElements/Device.Users.User.*.")"
  []
  $ code -H "$auth" "$base/serviceElements/$(q "Device.Users.User.[StaticUser==0].")"
  403
  $ code -H "$auth" "$base/serviceElements/$(q "Device.Users.User.[Username=='sec27target'].")"
  403

The admin must not write the runtime user. Both values are valid, so the refusal
comes from the ACL, and the bus shows no change:

  $ code -X PATCH -H "$auth" -H "$json" "$base/serviceElements/Device.Users.User.$tidx." --data '{"parameters":{"Enable":false}}'
  403
  $ code -X PATCH -H "$auth" -H "$json" "$base/serviceElements/Device.Users.User.$tidx." --data "{\"parameters\":{\"Shell\":\"$ash\"}}"
  403
  $ get User.$tidx.Enable
  1
  $ [ "$(get User.$tidx.Shell)" = "$tshell" ] && echo unchanged
  unchanged

On its own instance the admin must not change its shell, groups or roles:

  $ code -X PATCH -H "$auth" -H "$json" "$base/serviceElements/Device.Users.User.$aidx." --data "{\"parameters\":{\"Shell\":\"$ashell\"}}"
  403
  $ code -X PATCH -H "$auth" -H "$json" "$base/serviceElements/Device.Users.User.$aidx." --data "{\"parameters\":{\"GroupParticipation\":\"$gusers\"}}"
  403
  $ code -X PATCH -H "$auth" -H "$json" "$base/serviceElements/Device.Users.User.$aidx." --data "{\"parameters\":{\"RoleParticipation\":\"$rguest\"}}"
  403
  $ [ "$(get User.$aidx.Shell)" = "$ashell" ] && [ "$(get User.$aidx.GroupParticipation)" = "$agrp" ] && [ "$(get User.$aidx.RoleParticipation)" = "$arole" ] && echo unchanged
  unchanged

The admin may write its own Password. The write uses the password verified at
login, so the account keeps its credential and a new login still works:

  $ code -X PATCH -H "$auth" -H "$json" "$base/serviceElements/Device.Users.User.$aidx." --data "{\"parameters\":{\"Password\":\"$pw\"}}"
  204
  $ code -X POST "$base/session" --data "{\"username\":\"admin\",\"password\":\"$pw\"}"
  200

The admin must not add a user instance:

  $ code -X POST -H "$auth" -H "$json" "$base/serviceElements/Device.Users.User." --data '{"parameters":{"Username":"sec27addpst","UserID":27003,"Password":"sec27Pass0"}}'
  403
  $ sleep 2
  $ p=$(passwd) || { echo "passwd read failed"; exit 1; }
  $ printf '%s\n' "$p" | grep '^sec27addpst:'
  [1]
  $ echo $(( $(users | grep -c '^Device\.Users\.User\.[0-9]*\.Username=') - n0 )) $(( $(printf '%s\n' "$p" | wc -l) - p0 ))
  0 0

The admin must not delete the runtime user or its own instance:

  $ code -X DELETE -H "$auth" "$base/serviceElements/Device.Users.User.$tidx."
  403
  $ sleep 1; [ "$(idx sec27target)" = "$tidx" ] && echo kept
  kept
  $ code -X DELETE -H "$auth" "$base/serviceElements/Device.Users.User.$aidx."
  403
  $ sleep 1; [ "$(idx admin)" = "$aidx" ] && [ "$(get User.$aidx.StaticUser)" = 1 ] && echo kept
  kept

The admin can still read its own instance:

  $ code -H "$auth" "$base/serviceElements/Device.Users.User.$aidx."
  200
  $ body -H "$auth" "$base/serviceElements/Device.Users.User.$aidx." | grep -o '"Username":"admin"'
  "Username":"admin"

Positive control: over the unrestricted root bus the same RPC still creates a
user, so the command exists and only the admin ACL narrowed:

  $ R "ubus-cli 'Device.Users.CreateNewUser(Username=\"sec27rootctl\",Password=\"sec27Pass0\")'" >/dev/null
  $ for i in $(seq 10); do R "grep -q '^sec27rootctl:' /etc/passwd" && break; sleep 1; done
  $ passwd | grep -c '^sec27rootctl:'
  1

Clean up: restore the admin references if anything changed them, remove every
owned user by index, and check both the bus and passwd:

  $ cleanup
  $ sleep 2
  $ u=$(users) || { echo "bus read failed"; exit 1; }
  $ printf '%s\n' "$u" | grep -E "Username=\"$owned\""
  [1]
  $ p=$(passwd) || { echo "passwd read failed"; exit 1; }
  $ printf '%s\n' "$p" | grep -E "^$owned:"
  [1]
  $ [ "$(get User.$aidx.Shell)" = "$ashell" ] && [ "$(get User.$aidx.GroupParticipation)" = "$agrp" ] && [ "$(get User.$aidx.RoleParticipation)" = "$arole" ] && echo restored
  restored
  $ trap - EXIT INT TERM
