Verify a process list against rules.yml, as described in "Declaring the
expected privileges" in ../README.md. Each list line is
"pid ppid name user:group caps exe cwd cmdline".

  $ VERIFY="${TESTDIR}/../verify.py"

  $ cat > rules.yml <<'EOF'
  > procd:
  >   id: root:root
  >   caps: full
  >   child:
  >     tr181-usb:
  >       id: tr181_app:tr181_app
  >       caps: dac_override
  >     tr181-sfp:
  >       id: tr181_app:tr181_app
  >       caps: net_admin,dac_override
  >       child:
  >         sh:
  >           id: tr181_app:tr181_app
  >           caps: none
  >           optional: true
  >     dropbear:
  >       id: root:root
  >       caps: full
  >       ignore_child: true
  >     cellular-manager:
  >       id: tr181_app:tr181_app
  >       caps: net_admin
  >       optional: true
  > EOF

A tree that matches the rules:

  $ cat > ok.txt <<'EOF'
  > 1 0 procd root:root full /sbin/procd / /sbin/procd
  > 500 1 tr181-usb tr181_app:tr181_app dac_override /usr/bin/amxrt / tr181-usb -D
  > 501 1 tr181-sfp tr181_app:tr181_app net_admin,dac_override /usr/bin/amxrt / tr181-sfp -D
  > 502 1 dropbear root:root full /usr/sbin/dropbear / /usr/sbin/dropbear -F
  > EOF
  $ python3 "${VERIFY}" --input ok.txt rules.yml
  OK: All process privileges match expected configuration

The order of the capabilities does not matter:

  $ sed 's/net_admin,dac_override/dac_override,net_admin/' ok.txt > reordered.txt
  $ python3 "${VERIFY}" --input reordered.txt rules.yml
  OK: All process privileges match expected configuration

Wrong user or group:

  $ sed 's/^500 1 tr181-usb tr181_app:tr181_app/500 1 tr181-usb root:tr181_app/' ok.txt > wrong-id.txt
  $ python3 "${VERIFY}" --input wrong-id.txt rules.yml
  ERROR: procd > tr181-usb: expected id 'tr181_app:tr181_app', got 'root:tr181_app'
  [1]

Wrong capabilities, too many and too few:

  $ sed 's/^500 1 tr181-usb tr181_app:tr181_app dac_override/500 1 tr181-usb tr181_app:tr181_app full/' ok.txt > full-caps.txt
  $ python3 "${VERIFY}" --input full-caps.txt rules.yml
  ERROR: procd > tr181-usb: expected caps 'dac_override', got 'full'
  [1]

  $ sed 's/net_admin,dac_override/net_admin/' ok.txt > missing-cap.txt
  $ python3 "${VERIFY}" --input missing-cap.txt rules.yml
  ERROR: procd > tr181-sfp: expected caps 'net_admin,dac_override', got 'net_admin'
  [1]

"none" is a process without any capability, which is not the same as one
with a capability that is not expected:

  $ cat > none.txt <<'EOF'
  > 1 0 procd root:root full
  > 500 1 tr181-usb tr181_app:tr181_app dac_override
  > 501 1 tr181-sfp tr181_app:tr181_app net_admin,dac_override
  > 502 1 dropbear root:root full
  > 900 501 sh tr181_app:tr181_app none
  > EOF
  $ python3 "${VERIFY}" --input none.txt rules.yml
  OK: All process privileges match expected configuration

  $ sed 's/^900 501 sh tr181_app:tr181_app none/900 501 sh tr181_app:tr181_app net_admin/' none.txt > child-caps.txt
  $ python3 "${VERIFY}" --input child-caps.txt rules.yml
  ERROR: procd > tr181-sfp > sh: expected caps 'none', got 'net_admin'
  [1]

Both id and caps are reported when both are wrong:

  $ sed 's/^502 1 dropbear root:root full/502 1 dropbear sshd:sshd none/' ok.txt > both.txt
  $ python3 "${VERIFY}" --input both.txt rules.yml
  ERROR: procd > dropbear: expected id 'root:root', got 'sshd:sshd'
  ERROR: procd > dropbear: expected caps 'full', got 'none'
  [1]

A required process that is missing fails, an optional one does not. The
optional cellular-manager is absent in every list above, and it is verified
when present:

  $ grep -v tr181-usb ok.txt > missing-child.txt
  $ python3 "${VERIFY}" --input missing-child.txt rules.yml
  ERROR: procd: missing required child process 'tr181-usb'
  [1]

  $ echo "503 1 cellular-manager root:root full" | cat ok.txt - > optional-present.txt
  $ python3 "${VERIFY}" --input optional-present.txt rules.yml
  ERROR: procd > cellular-manager: expected id 'tr181_app:tr181_app', got 'root:root'
  ERROR: procd > cellular-manager: expected caps 'net_admin', got 'full'
  [1]

  $ python3 "${VERIFY}" --input /dev/null rules.yml
  ERROR: missing required process 'procd'
  [1]

Every process with the name of an entry is verified, not only the first one:

  $ echo "503 1 tr181-usb root:root full" | cat ok.txt - > duplicate.txt
  $ python3 "${VERIFY}" --input duplicate.txt rules.yml
  ERROR: procd > tr181-usb: expected id 'tr181_app:tr181_app', got 'root:root'
  ERROR: procd > tr181-usb: expected caps 'dac_override', got 'full'
  [1]

The children of an ignore_child entry are not checked at all:

  $ cat ok.txt - > ignored.txt <<'EOF'
  > 600 502 dropbear root:root full /usr/sbin/dropbear / /usr/sbin/dropbear -F
  > 601 600 ash root:root full /bin/busybox /root -ash
  > EOF
  $ python3 "${VERIFY}" --input ignored.txt rules.yml
  OK: All process privileges match expected configuration

The rules.yml next to verify.py is used when no rules are given:

  $ python3 "${VERIFY}" --input /dev/null
  ERROR: missing required process 'procd'
  [1]
