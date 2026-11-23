Collect from the DUT and retry, as described in "Transient processes",
"Collecting manually" and "Transport" in ../README.md. fake-dut.sh stands in
for scp and ssh, and serves canned process lists instead of running the
collector.

  $ VERIFY="${TESTDIR}/../verify.py"
  $ export FAKE_DUT="${PWD}/dut"
  $ mkdir "${FAKE_DUT}"
  $ export CRAM_REMOTE_COPY="sh ${TESTDIR}/fake-dut.sh copy"
  $ export CRAM_REMOTE_COMMAND="sh ${TESTDIR}/fake-dut.sh ssh root@192.0.2.1"
  $ unset TARGET_LAN_IP VERIFY_TIMEOUT VERIFY_INTERVAL

  $ cat > rules.yml <<'EOF'
  > procd:
  >   id: root:root
  >   caps: full
  >   child:
  >     tr181-sfp:
  >       id: tr181_app:tr181_app
  >       caps: net_admin
  > EOF

  $ cat > "${FAKE_DUT}/list" <<'EOF'
  > 1 0 procd root:root full /sbin/procd / /sbin/procd
  > 500 1 tr181-sfp tr181_app:tr181_app net_admin /usr/bin/amxrt / tr181-sfp -D
  > EOF
  $ cat > transient.txt <<'EOF'
  > 1 0 procd root:root full /sbin/procd / /sbin/procd
  > 500 1 tr181-sfp root:root full /usr/bin/amxrt / tr181-sfp -D
  > EOF

The collector is copied to the DUT, run, and removed again. The host is taken
from CRAM_REMOTE_COMMAND:

  $ python3 "${VERIFY}" rules.yml
  OK: All process privileges match expected configuration
  $ cat "${FAKE_DUT}/log"
  copy process-privileges.lua root@192.0.2.1:/tmp/process-privileges.lua
  ssh root@192.0.2.1 lua /tmp/process-privileges.lua list
  ssh root@192.0.2.1 rm -f '/tmp/process-privileges.lua'

TARGET_LAN_IP names the host when CRAM_REMOTE_COMMAND does not, and --lua
selects the interpreter on the DUT:

  $ rm "${FAKE_DUT}/log"
  $ CRAM_REMOTE_COMMAND="sh ${TESTDIR}/fake-dut.sh ssh dut" TARGET_LAN_IP=198.51.100.7 \
  >   python3 "${VERIFY}" --lua lua5.1 rules.yml
  OK: All process privileges match expected configuration
  $ cat "${FAKE_DUT}/log"
  copy process-privileges.lua root@198.51.100.7:/tmp/process-privileges.lua
  ssh dut lua5.1 /tmp/process-privileges.lua list
  ssh dut rm -f '/tmp/process-privileges.lua'

  $ CRAM_REMOTE_COMMAND="sh ${TESTDIR}/fake-dut.sh ssh dut" python3 "${VERIFY}" rules.yml
  TARGET_LAN_IP or a remote command naming the host is required
  [1]

A failing copy or collector run is an error:

  $ touch "${FAKE_DUT}/copy-fails"
  $ python3 "${VERIFY}" rules.yml
  Failed to copy */target/process-privileges.lua to 192.0.2.1 (glob)
  [1]
  $ rm "${FAKE_DUT}/copy-fails"

  $ echo 1 > "${FAKE_DUT}/exit-code"
  $ python3 "${VERIFY}" rules.yml
  ERROR: failed to collect the process list
  [1]
  $ rm "${FAKE_DUT}/exit-code"

--collect only prints what the collector prints, a tree by default, and
passes on its exit code:

  $ printf 'procd [root:root] full\n  tr181-sfp [tr181_app:tr181_app] net_admin\n' > "${FAKE_DUT}/tree"
  $ rm "${FAKE_DUT}/log"
  $ python3 "${VERIFY}" --collect
  procd [root:root] full
    tr181-sfp [tr181_app:tr181_app] net_admin
  $ python3 "${VERIFY}" --collect color > /dev/null
  $ python3 "${VERIFY}" --collect list
  1 0 procd root:root full /sbin/procd / /sbin/procd
  500 1 tr181-sfp tr181_app:tr181_app net_admin /usr/bin/amxrt / tr181-sfp -D
  $ grep 'lua /tmp' "${FAKE_DUT}/log"
  ssh root@192.0.2.1 lua /tmp/process-privileges.lua tree
  ssh root@192.0.2.1 lua /tmp/process-privileges.lua color
  ssh root@192.0.2.1 lua /tmp/process-privileges.lua list

  $ echo 3 > "${FAKE_DUT}/exit-code"
  $ python3 "${VERIFY}" --collect
  procd [root:root] full
    tr181-sfp [tr181_app:tr181_app] net_admin
  [3]
  $ rm "${FAKE_DUT}/exit-code"

The collected list can be saved and verified later with --input:

  $ python3 "${VERIFY}" --collect list > processes.txt
  $ python3 "${VERIFY}" --input processes.txt rules.yml
  OK: All process privileges match expected configuration

Without a timeout a single snapshot is verified, so a transient state fails
the test:

  $ rm -f "${FAKE_DUT}/attempts" "${FAKE_DUT}/log"
  $ cp transient.txt "${FAKE_DUT}/list.1"
  $ python3 "${VERIFY}" rules.yml
  ERROR: procd > tr181-sfp: expected id 'tr181_app:tr181_app', got 'root:root'
  ERROR: procd > tr181-sfp: expected caps 'net_admin', got 'full'
  [1]
  $ grep -c ' list$' "${FAKE_DUT}/log"
  1

With a timeout it collects again until the tree matches, and copies the
collector only once. Only the OK line is printed:

  $ rm -f "${FAKE_DUT}/attempts" "${FAKE_DUT}/log"
  $ cp transient.txt "${FAKE_DUT}/list.2"
  $ python3 "${VERIFY}" --timeout 30 --interval 0 rules.yml
  OK: All process privileges match expected configuration
  $ cat "${FAKE_DUT}/log"
  copy process-privileges.lua root@192.0.2.1:/tmp/process-privileges.lua
  ssh root@192.0.2.1 lua /tmp/process-privileges.lua list
  ssh root@192.0.2.1 lua /tmp/process-privileges.lua list
  ssh root@192.0.2.1 lua /tmp/process-privileges.lua list
  ssh root@192.0.2.1 rm -f '/tmp/process-privileges.lua'

--verbose also prints what the failed attempts caught:

  $ rm -f "${FAKE_DUT}/attempts"
  $ python3 "${VERIFY}" --verbose --timeout 30 --interval 0 rules.yml
  attempt 1 failed after 0s:
  ERROR: procd > tr181-sfp: expected id 'tr181_app:tr181_app', got 'root:root'
  ERROR: procd > tr181-sfp: expected caps 'net_admin', got 'full'
  attempt 2 failed after 0s:
  ERROR: procd > tr181-sfp: expected id 'tr181_app:tr181_app', got 'root:root'
  ERROR: procd > tr181-sfp: expected caps 'net_admin', got 'full'
  OK: All process privileges match expected configuration

When the timeout expires, the errors of the last attempt are printed with the
number of attempts. VERIFY_TIMEOUT and VERIFY_INTERVAL set the defaults:

  $ rm -f "${FAKE_DUT}/attempts" "${FAKE_DUT}/list.1" "${FAKE_DUT}/list.2"
  $ cp transient.txt "${FAKE_DUT}/list"
  $ VERIFY_TIMEOUT=1 VERIFY_INTERVAL=1 python3 "${VERIFY}" rules.yml
  ERROR: procd > tr181-sfp: expected id 'tr181_app:tr181_app', got 'root:root'
  ERROR: procd > tr181-sfp: expected caps 'net_admin', got 'full'
  ERROR: process privileges did not match after 2 attempts in 1s
  [1]
