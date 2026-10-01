Device.Users.CreateNewUser() must reject a username that does not match the
username policy (SEC-16). The handler passed Username straight into
putpwent(), so a colon forged extra /etc/passwd fields and a newline forged a
whole extra line. On an unfixed build the colon payload below lands in
/etc/passwd as a line that parses to uid 0, gid 0, home /root, shell /bin/ash:
a root account created by a single RPC call.

The validation lives inside the RPC and is role independent, so this drives it
over the root bus. Each attempt asserts the effect on /etc/passwd rather than an
error string, so the test stays valid however the rejection is signalled.

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
