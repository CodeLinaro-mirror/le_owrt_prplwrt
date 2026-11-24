Children that are told apart by their command line, with "match" under "child", and
rules files merged in order, as described in "Declaring the expected
privileges" in ../README.md. The two shell scripts of tr181-sfp run with
different privileges, so each one needs its own rule.

  $ VERIFY="${TESTDIR}/../verify.py"

  $ cat > rules.yml <<'EOF'
  > procd:
  >   id: root:root
  >   caps: full
  >   child:
  >     tr181-sfp:
  >       id: tr181_app:tr181_app
  >       caps: dac_override,net_admin
  >       child:
  >         eeprom:
  >           match:
  >             name: sh
  >             cmd: "~get_eeprom_info\\.sh"
  >           id: tr181_app:tr181_app
  >           caps: net_admin
  >           optional: true
  >           ignore_child: true
  >         oper-state:
  >           match:
  >             name: sh
  >             cmd: "~get_oper_state\\.sh"
  >           id: tr181_app:tr181_app
  >           caps: net_admin
  >           optional: true
  >           ignore_child: true
  > EOF

  $ cat > ok.txt <<'EOF'
  > 1 0 procd root:root full /sbin/procd / /sbin/procd
  > 501 1 tr181-sfp tr181_app:tr181_app dac_override,net_admin /usr/bin/amxrt / tr181-sfp -D
  > 900 501 sh tr181_app:tr181_app net_admin /bin/busybox / /bin/sh /lib/sfp/get_eeprom_info.sh eth0
  > 901 501 sh tr181_app:tr181_app net_admin /bin/busybox / /bin/sh /lib/sfp/get_oper_state.sh eth0
  > EOF
  $ python3 "${VERIFY}" --input ok.txt rules.yml
  OK: All process privileges match expected configuration

Each script is checked against its own rule, so a wrong capability on one of
them is reported with the name of the rule:

  $ sed 's/^900 501 sh tr181_app:tr181_app net_admin/900 501 sh tr181_app:tr181_app dac_override,net_admin/' ok.txt > wrong-caps.txt
  $ python3 "${VERIFY}" --input wrong-caps.txt rules.yml
  ERROR: procd > tr181-sfp > sh[eeprom]: expected caps 'net_admin', got 'dac_override,net_admin'
  [1]

A script without a rule is an unexpected child, even though another script of
the same name has one:

  $ cat > unlisted.txt <<'EOF'
  > 1 0 procd root:root full /sbin/procd / /sbin/procd
  > 501 1 tr181-sfp tr181_app:tr181_app dac_override,net_admin /usr/bin/amxrt / tr181-sfp -D
  > 900 501 sh tr181_app:tr181_app net_admin /bin/busybox / /bin/sh /lib/sfp/get_eeprom_info.sh eth0
  > 902 501 sh tr181_app:tr181_app net_admin /bin/busybox / /bin/sh /lib/sfp/other.sh eth0
  > EOF
  $ python3 "${VERIFY}" --input unlisted.txt rules.yml
  ERROR: procd > tr181-sfp: unexpected child process 'sh' (id=tr181_app:tr181_app, caps=net_admin)
  procd (pid=1, id=root:root, caps=full, exe=/sbin/procd, cwd=/)
     tr181-sfp (pid=501, id=tr181_app:tr181_app, caps=dac_override,net_admin, exe=/usr/bin/amxrt, cwd=/)
        sh (pid=902, id=tr181_app:tr181_app, caps=net_admin, exe=/bin/busybox, cwd=/)
           - cmd: /bin/sh /lib/sfp/other.sh eth0
  [1]

A rule that is not optional must match at least one child, and the report names
its match:

  $ cat > required.yml <<'EOF'
  > procd:
  >   id: root:root
  >   caps: full
  >   child:
  >     tr181-sfp:
  >       id: tr181_app:tr181_app
  >       caps: dac_override,net_admin
  >       child:
  >         eeprom:
  >           match:
  >             name: sh
  >             cmd: "~get_eeprom_info\\.sh"
  >           id: tr181_app:tr181_app
  >           caps: net_admin
  >           ignore_child: true
  > EOF
  $ grep -v '^900 ' ok.txt > no-eeprom.txt
  $ python3 "${VERIFY}" --input no-eeprom.txt required.yml
  ERROR: procd > tr181-sfp: missing required child process 'eeprom (name=sh, cmd=~get_eeprom_info\.sh)'
  ERROR: procd > tr181-sfp: unexpected child process 'sh' (id=tr181_app:tr181_app, caps=net_admin)
  procd (pid=1, id=root:root, caps=full, exe=/sbin/procd, cwd=/)
     tr181-sfp (pid=501, id=tr181_app:tr181_app, caps=dac_override,net_admin, exe=/usr/bin/amxrt, cwd=/)
        sh (pid=901, id=tr181_app:tr181_app, caps=net_admin, exe=/bin/busybox, cwd=/)
           - cmd: /bin/sh /lib/sfp/get_oper_state.sh eth0
  [1]

A child that matches two rules is an error, not a guess:

  $ cat > ambiguous.yml <<'EOF'
  > procd:
  >   id: root:root
  >   caps: full
  >   child:
  >     tr181-sfp:
  >       id: tr181_app:tr181_app
  >       caps: dac_override,net_admin
  >       child:
  >         any-sh:
  >           match:
  >             name: sh
  >           id: tr181_app:tr181_app
  >           caps: net_admin
  >           ignore_child: true
  >         eeprom:
  >           match:
  >             name: sh
  >             cmd: "~get_eeprom_info\\.sh"
  >           id: tr181_app:tr181_app
  >           caps: net_admin
  >           ignore_child: true
  > EOF
  $ python3 "${VERIFY}" --input ok.txt ambiguous.yml
  ERROR: procd > tr181-sfp: child process 'sh' (id=tr181_app:tr181_app, caps=net_admin) matches more than one rule: any-sh (name=sh) and eeprom (name=sh, cmd=~get_eeprom_info\.sh)
  procd (pid=1, id=root:root, caps=full, exe=/sbin/procd, cwd=/)
     tr181-sfp (pid=501, id=tr181_app:tr181_app, caps=dac_override,net_admin, exe=/usr/bin/amxrt, cwd=/)
        sh (pid=900, id=tr181_app:tr181_app, caps=net_admin, exe=/bin/busybox, cwd=/)
           - cmd: /bin/sh /lib/sfp/get_eeprom_info.sh eth0
  ERROR: procd > tr181-sfp: missing required child process 'eeprom (name=sh, cmd=~get_eeprom_info\.sh)'
  [1]

A board file is merged over the base rules. A null value deletes a rule, and a
map replaces only the keys it sets:

  $ cat > board.yml <<'EOF'
  > procd:
  >   child:
  >     tr181-sfp:
  >       child:
  >         eeprom: null
  >         oper-state:
  >           caps: none
  > EOF
  $ python3 "${VERIFY}" --input ok.txt rules.yml board.yml
  ERROR: procd > tr181-sfp > sh[oper-state]: expected caps 'none', got 'net_admin'
  ERROR: procd > tr181-sfp: unexpected child process 'sh' (id=tr181_app:tr181_app, caps=net_admin)
  procd (pid=1, id=root:root, caps=full, exe=/sbin/procd, cwd=/)
     tr181-sfp (pid=501, id=tr181_app:tr181_app, caps=dac_override,net_admin, exe=/usr/bin/amxrt, cwd=/)
        sh (pid=900, id=tr181_app:tr181_app, caps=net_admin, exe=/bin/busybox, cwd=/)
           - cmd: /bin/sh /lib/sfp/get_eeprom_info.sh eth0
  [1]

A repeated key in a rules file is an error, not a silent override:

  $ cat > duplicate.yml <<'EOF'
  > procd:
  >   id: root:root
  > procd:
  >   id: root:root
  > EOF
  $ python3 "${VERIFY}" --input ok.txt duplicate.yml 2>&1 | grep -F "duplicate key"
  duplicate key 'procd'

A match must name a field that exists and cannot be empty:

  $ cat > typo.yml <<'EOF'
  > procd:
  >   child:
  >     tr181-sfp:
  >       child:
  >         eeprom:
  >           match:
  >             nmae: sh
  > EOF
  $ python3 "${VERIFY}" --input ok.txt typo.yml
  ERROR: child 'eeprom': unknown match field 'nmae'
  [1]
