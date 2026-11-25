Situation specific rules, loaded from the profiles directory on top of the rules
files, as described in "Profiles" in ../README.md. The profiles are chosen by the
environment, so every case here uses its own profiles directory and environment.

  $ verify() { env -u DUT_BOARD -u DUT_WAN_INTERFACE -u DUT_HAS_MODEM python3 "${TESTDIR}/../verify.py" --profiles-dir profiles "$@"; }

  $ cat > rules.yml <<'EOF'
  > procd:
  >   id: root:root
  >   caps: full
  >   child:
  >     tr181-usb:
  >       id: tr181_app:tr181_app
  >       caps: dac_override
  > EOF

  $ cat > ok.txt <<'EOF'
  > 1 0 procd root:root full /sbin/procd / /sbin/procd
  > 500 1 tr181-usb tr181_app:tr181_app dac_override /usr/bin/amxrt / tr181-usb -D
  > EOF

  $ mkdir -p profiles
  $ cat > profiles/profiles.yml <<'EOF'
  > version: 1
  > defaults:
  >   DUT_HAS_MODEM: "1"
  > profiles:
  >   - file: has_modem.yml
  >     when:
  >       DUT_HAS_MODEM: "1"
  >   - file: "${DUT_BOARD}.yml"
  >     optional: true
  >   - file: wan_ppp.yml
  >     when:
  >       DUT_WAN_INTERFACE: "~^ppp"
  >     optional: true
  > EOF
  $ cat > profiles/has_modem.yml <<'EOF'
  > procd:
  >   child:
  >     cellular-manager:
  >       id: tr181_app:tr181_app
  >       caps: net_admin
  >       optional: true
  > EOF

With no board set and the default modem, only has_modem.yml loads. A file name
that uses an unset variable is skipped:

  $ env -u DUT_BOARD -u DUT_WAN_INTERFACE -u DUT_HAS_MODEM python3 "${TESTDIR}/../verify.py" --profiles-dir profiles --list-profiles --input ok.txt rules.yml
  profile has_modem.yml: loaded
  profile ${DUT_BOARD}.yml: skipped (a variable in the file name is not set)
  profile wan_ppp.yml: skipped (DUT_WAN_INTERFACE is not set)
  OK: All process privileges match expected configuration

The default in the manifest applies when the environment does not set the
variable, and the environment wins over it:

  $ env -u DUT_BOARD -u DUT_WAN_INTERFACE DUT_HAS_MODEM=0 python3 "${TESTDIR}/../verify.py" --profiles-dir profiles --list-profiles --input ok.txt rules.yml
  profile has_modem.yml: skipped (DUT_HAS_MODEM=0 does not match)
  profile ${DUT_BOARD}.yml: skipped (a variable in the file name is not set)
  profile wan_ppp.yml: skipped (DUT_WAN_INTERFACE is not set)
  OK: All process privileges match expected configuration

A board file loads when its variable is set. An empty variable counts as unset:

  $ cat > profiles/x86_64.yml <<'EOF'
  > procd:
  >   child:
  >     tr181-usb:
  >       id: tr181_app:tr181_app
  >       caps: none
  > EOF
  $ env DUT_BOARD=x86_64 DUT_WAN_INTERFACE= DUT_HAS_MODEM=1 python3 "${TESTDIR}/../verify.py" --profiles-dir profiles --list-profiles --input ok.txt rules.yml
  profile has_modem.yml: loaded
  profile x86_64.yml: loaded
  profile wan_ppp.yml: skipped (DUT_WAN_INTERFACE is not set)
  ERROR: procd > tr181-usb: expected caps 'none', got 'dac_override'
  [1]

A profile is applied on top of the rules files, and --no-profiles turns them
all off:

  $ verify --no-profiles --input ok.txt rules.yml
  OK: All process privileges match expected configuration

A regex condition matches the value. An optional file that is absent is skipped:

  $ env DUT_WAN_INTERFACE=ppp0 DUT_HAS_MODEM=1 python3 "${TESTDIR}/../verify.py" --profiles-dir profiles --list-profiles --input ok.txt rules.yml 2>&1 | grep wan_ppp
  profile wan_ppp.yml: skipped (not present)

A profile listed without optional must exist:

  $ cat > profiles/profiles.yml <<'EOF'
  > version: 1
  > profiles:
  >   - file: missing.yml
  > EOF
  $ verify --input ok.txt rules.yml
  ERROR: profile file 'missing.yml' is missing from the profiles directory
  [1]

A file name must stay inside the profiles directory:

  $ cat > profiles/profiles.yml <<'EOF'
  > version: 1
  > profiles:
  >   - file: "${DUT_BOARD}.yml"
  > EOF
  $ env DUT_BOARD=../../rules DUT_HAS_MODEM=1 python3 "${TESTDIR}/../verify.py" --profiles-dir profiles --input ok.txt rules.yml
  ERROR: profile '${DUT_BOARD}.yml' must name a file in the profiles directory
  [1]

A bare boolean in a condition is an error, so it cannot silently never match:

  $ cat > profiles/profiles.yml <<'EOF'
  > version: 1
  > profiles:
  >   - file: has_modem.yml
  >     when:
  >       DUT_HAS_MODEM: true
  > EOF
  $ verify --input ok.txt rules.yml
  ERROR: profiles/profiles.yml: profiles[0]: when.DUT_HAS_MODEM: quote the value, e.g. "1" or "true"
  [1]
