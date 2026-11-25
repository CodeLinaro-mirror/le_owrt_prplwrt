--collect prints the process list without loading rules or profiles, so a broken
profile cannot hide it, as described in "Collecting manually" in ../README.md.
fake-dut.sh stands in for scp and ssh.

  $ export FAKE_DUT="${PWD}/dut"
  $ mkdir "${FAKE_DUT}"
  $ export CRAM_REMOTE_COPY="sh ${TESTDIR}/fake-dut.sh copy"
  $ export CRAM_REMOTE_COMMAND="sh ${TESTDIR}/fake-dut.sh ssh root@192.0.2.1"
  $ unset TARGET_LAN_IP VERIFY_TIMEOUT VERIFY_INTERVAL
  $ VERIFY="${TESTDIR}/../verify.py"

  $ cat > "${FAKE_DUT}/list" <<'EOF'
  > 1 0 procd root:root full /sbin/procd / /sbin/procd
  > EOF

A profile that is missing from its manifest is an error for a check, but
--collect still prints the process list:

  $ mkdir -p profiles
  $ cat > profiles/profiles.yml <<'EOF'
  > version: 1
  > profiles:
  >   - file: missing.yml
  > EOF
  $ python3 "${VERIFY}" --collect list --profiles-dir profiles
  1 0 procd root:root full /sbin/procd / /sbin/procd
  $ python3 "${VERIFY}" --profiles-dir profiles
  ERROR: profile file 'missing.yml' is missing from the profiles directory
  [1]

A rules file that is not valid YAML does not block --collect either:

  $ cat > broken.yml <<'EOF'
  > procd: [
  > EOF
  $ python3 "${VERIFY}" --collect list broken.yml
  1 0 procd root:root full /sbin/procd / /sbin/procd
  $ python3 "${VERIFY}" broken.yml
  ERROR: broken.yml: while parsing a flow node
  expected the node content, but found '<stream end>'
    in "broken.yml", line 2, column 1
  [1]
