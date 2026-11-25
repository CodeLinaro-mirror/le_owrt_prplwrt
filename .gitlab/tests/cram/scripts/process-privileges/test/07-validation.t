Checks on the rules files, made when each file is read, as described in
"Several rules files" in ../README.md.

  $ VERIFY="${TESTDIR}/../verify.py"

  $ cat > ok.txt <<'EOF'
  > 1 0 procd root:root full /sbin/procd / /sbin/procd
  > 500 1 tr181-usb tr181_app:tr181_app dac_override /usr/bin/amxrt / tr181-usb -D
  > EOF

  $ cat > base.yml <<'EOF'
  > procd:
  >   id: root:root
  >   caps: full
  >   child:
  >     tr181-usb:
  >       id: tr181_app:tr181_app
  >       caps: dac_override
  >       optional: true
  > EOF

A value of the wrong type is reported with the file and the entry:

  $ cat > string-optional.yml <<'EOF'
  > procd:
  >   child:
  >     tr181-usb:
  >       optional: "false"
  > EOF
  $ python3 "${VERIFY}" --no-profiles --input ok.txt base.yml string-optional.yml
  ERROR: string-optional.yml: procd > tr181-usb: 'optional' must be true or false, got 'false'
  [1]

  $ cat > list-caps.yml <<'EOF'
  > procd:
  >   caps: [full]
  > EOF
  $ python3 "${VERIFY}" --no-profiles --input ok.txt list-caps.yml
  ERROR: list-caps.yml: procd: 'caps' must be a string, got ['full']
  [1]

  $ cat > child-not-map.yml <<'EOF'
  > procd:
  >   child: tr181-usb
  > EOF
  $ python3 "${VERIFY}" --no-profiles --input ok.txt child-not-map.yml
  ERROR: child-not-map.yml: procd: 'child' must be a map, got 'tr181-usb'
  [1]

  $ cat > entry-not-map.yml <<'EOF'
  > procd: root
  > EOF
  $ python3 "${VERIFY}" --no-profiles --input ok.txt entry-not-map.yml
  ERROR: entry-not-map.yml: procd: expected a map
  [1]

A nested child is checked too:

  $ cat > nested-bool.yml <<'EOF'
  > procd:
  >   child:
  >     tr181-usb:
  >       child:
  >         sh:
  >           ignore_child: 1
  > EOF
  $ python3 "${VERIFY}" --no-profiles --input ok.txt nested-bool.yml
  ERROR: nested-bool.yml: procd > tr181-usb > sh: 'ignore_child' must be true or false, got 1
  [1]

A partial override, with only some keys, is fine, and so is null for a value:

  $ cat > partial.yml <<'EOF'
  > procd:
  >   caps: none
  >   child:
  >     tr181-usb:
  >       optional: false
  > EOF
  $ python3 "${VERIFY}" --no-profiles --input ok.txt base.yml partial.yml
  ERROR: procd: expected caps 'none', got 'full'
  [1]

A null that deletes a key defined by an earlier file works. The process it
described is then unexpected:

  $ cat > delete.yml <<'EOF'
  > procd:
  >   child:
  >     tr181-usb: null
  > EOF
  $ python3 "${VERIFY}" --no-profiles --input ok.txt base.yml delete.yml
  ERROR: procd: unexpected child process 'tr181-usb' (id=tr181_app:tr181_app, caps=dac_override)
  procd (pid=1, id=root:root, caps=full, exe=/sbin/procd, cwd=/)
     tr181-usb (pid=500, id=tr181_app:tr181_app, caps=dac_override, exe=/usr/bin/amxrt, cwd=/)
        - cmd: tr181-usb -D
  [1]

A null that matches no earlier key is an error, because it is most likely a
typo. The file and the key path are named:

  $ cat > typo.yml <<'EOF'
  > procd:
  >   child:
  >     tr181-usbb: null
  > EOF
  $ python3 "${VERIFY}" --no-profiles --input ok.txt base.yml typo.yml
  ERROR: typo.yml: procd > tr181-usbb: null deletes a key that no earlier file defines
  [1]

A match on a top-level process is an error. Only children can be matched by
fields, and a top-level process is always found by its name:

  $ cat > top-match.yml <<'EOF'
  > procd:
  >   match:
  >     name: procd
  >   id: root:root
  >   caps: full
  > EOF
  $ python3 "${VERIFY}" --no-profiles --input ok.txt top-match.yml
  ERROR: top-match.yml: procd: 'match' is only allowed under 'child'
  [1]
