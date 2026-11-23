Report processes that are not in rules.yml, and show the context of an
unexpected child process, as described in "Verifying" in ../README.md.

  $ VERIFY="${TESTDIR}/../verify.py"

  $ cat > rules.yml <<'EOF'
  > procd:
  >   id: root:root
  >   caps: full
  >   child:
  >     tr181-sfp:
  >       id: tr181_app:tr181_app
  >       caps: net_admin
  > EOF

An unexpected root process is a single line:

  $ cat > root.txt <<'EOF'
  > 1 0 procd root:root full /sbin/procd / /sbin/procd
  > 2 0 kthreadd root:root full - - kthreadd
  > 500 1 tr181-sfp tr181_app:tr181_app net_admin /usr/bin/amxrt / tr181-sfp -D
  > EOF
  $ python3 "${VERIFY}" --input root.txt rules.yml
  ERROR: unexpected root process 'kthreadd' (id=root:root, caps=full)
  [1]

An unexpected child process is followed by its ancestors, then itself and all
its descendants with their command line, so a short-lived helper can still be
identified after it is gone:

  $ cat > child.txt <<'EOF'
  > 1 0 procd root:root full /sbin/procd / /sbin/procd
  > 500 1 tr181-sfp tr181_app:tr181_app net_admin /usr/bin/amxrt / tr181-sfp -D
  > 900 500 sh tr181_app:tr181_app none /bin/busybox / /bin/sh /lib/sfp/get_eeprom_info.sh sfp0
  > 901 900 ethtool tr181_app:tr181_app none /usr/sbin/ethtool / ethtool -m eth5 raw on
  > EOF
  $ python3 "${VERIFY}" --input child.txt rules.yml
  ERROR: procd > tr181-sfp: unexpected child process 'sh' (id=tr181_app:tr181_app, caps=none)
  procd (pid=1, id=root:root, caps=full, exe=/sbin/procd, cwd=/)
     tr181-sfp (pid=500, id=tr181_app:tr181_app, caps=net_admin, exe=/usr/bin/amxrt, cwd=/)
        sh (pid=900, id=tr181_app:tr181_app, caps=none, exe=/bin/busybox, cwd=/)
           - cmd: /bin/sh /lib/sfp/get_eeprom_info.sh sfp0
           ethtool (pid=901, id=tr181_app:tr181_app, caps=none, exe=/usr/sbin/ethtool, cwd=/)
              - cmd: ethtool -m eth5 raw on
  [1]

Every unexpected child is reported, each with its own context, and the
descendants are sorted by name, then pid:

  $ cat > children.txt <<'EOF'
  > 1 0 procd root:root full /sbin/procd / /sbin/procd
  > 500 1 tr181-sfp tr181_app:tr181_app net_admin /usr/bin/amxrt / tr181-sfp -D
  > 700 1 logger root:root full /usr/bin/logger / logger -t test
  > 900 500 sh tr181_app:tr181_app none /bin/busybox / sh -c helper
  > 903 900 sleep tr181_app:tr181_app none /bin/busybox / sleep 1
  > 902 900 cat tr181_app:tr181_app none /bin/busybox / cat
  > 901 900 sleep tr181_app:tr181_app none /bin/busybox / sleep 2
  > EOF
  $ python3 "${VERIFY}" --input children.txt rules.yml
  ERROR: procd > tr181-sfp: unexpected child process 'sh' (id=tr181_app:tr181_app, caps=none)
  procd (pid=1, id=root:root, caps=full, exe=/sbin/procd, cwd=/)
     tr181-sfp (pid=500, id=tr181_app:tr181_app, caps=net_admin, exe=/usr/bin/amxrt, cwd=/)
        sh (pid=900, id=tr181_app:tr181_app, caps=none, exe=/bin/busybox, cwd=/)
           - cmd: sh -c helper
           cat (pid=902, id=tr181_app:tr181_app, caps=none, exe=/bin/busybox, cwd=/)
              - cmd: cat
           sleep (pid=901, id=tr181_app:tr181_app, caps=none, exe=/bin/busybox, cwd=/)
              - cmd: sleep 2
           sleep (pid=903, id=tr181_app:tr181_app, caps=none, exe=/bin/busybox, cwd=/)
              - cmd: sleep 1
  ERROR: procd: unexpected child process 'logger' (id=root:root, caps=full)
  procd (pid=1, id=root:root, caps=full, exe=/sbin/procd, cwd=/)
     logger (pid=700, id=root:root, caps=full, exe=/usr/bin/logger, cwd=/)
        - cmd: logger -t test
  [1]

The descendants of an unexpected child are not reported separately, and an
expected process below an unexpected one is not verified either:

  $ cat > nested.txt <<'EOF'
  > 1 0 procd root:root full
  > 500 1 tr181-sfp tr181_app:tr181_app net_admin
  > 900 500 sh tr181_app:tr181_app none
  > 901 900 tr181-sfp root:root full
  > EOF
  $ python3 "${VERIFY}" --input nested.txt rules.yml
  ERROR: procd > tr181-sfp: unexpected child process 'sh' (id=tr181_app:tr181_app, caps=none)
  procd (pid=1, id=root:root, caps=full, exe=-, cwd=-)
     tr181-sfp (pid=500, id=tr181_app:tr181_app, caps=net_admin, exe=-, cwd=-)
        sh (pid=900, id=tr181_app:tr181_app, caps=none, exe=-, cwd=-)
           tr181-sfp (pid=901, id=root:root, caps=full, exe=-, cwd=-)
  [1]
