Parse the process list, the "--collect list" output that --input consumes, as
described in "Collecting manually" in ../README.md.

  $ VERIFY="${TESTDIR}/../verify.py"

  $ cat > rules.yml <<'EOF'
  > procd:
  >   id: root:root
  >   caps: full
  >   child:
  >     "-ash":
  >       id: root:root
  >       caps: full
  >     "amxrt:wifi-scheduler":
  >       id: root:root
  >       caps: full
  >     "my daemon":
  >       id: nobody:nogroup
  >       caps: none
  > EOF

Whitespace in name, exe and cwd is escaped as octal, "-" is an empty value,
and the command line takes up the rest of the line, spaces included:

  $ cat > escaped.txt <<'EOF'
  > 1 0 procd root:root full /sbin/procd / /sbin/procd
  > 400 1 -ash root:root full /bin/busybox /root -ash
  > 401 1 amxrt:wifi-scheduler root:root full /usr/bin/amxrt / amxrt:wifi-scheduler
  > 402 1 my\040daemon nobody:nogroup none /opt/my\040app/daemon /var/my\040dir /opt/my app/daemon
  > 403 402 my\040helper nobody:nogroup none /opt/my\040app/helper - /opt/my app/helper --name "a  b"
  > EOF
  $ python3 "${VERIFY}" --input escaped.txt rules.yml
  ERROR: procd > my daemon: unexpected child process 'my helper' (id=nobody:nogroup, caps=none)
  procd (pid=1, id=root:root, caps=full, exe=/sbin/procd, cwd=/)
     my daemon (pid=402, id=nobody:nogroup, caps=none, exe=/opt/my app/daemon, cwd=/var/my dir)
        my helper (pid=403, id=nobody:nogroup, caps=none, exe=/opt/my app/helper, cwd=-)
           - cmd: /opt/my app/helper --name "a  b"
  [1]

The older format, which stops after caps, is still accepted:

  $ cat > old.txt <<'EOF'
  > 1 0 procd root:root full
  > 400 1 -ash root:root full
  > 401 1 amxrt:wifi-scheduler root:root full
  > 402 1 my\040daemon nobody:nogroup none
  > EOF
  $ python3 "${VERIFY}" --input old.txt rules.yml
  OK: All process privileges match expected configuration

Lines with fewer than five fields are skipped:

  $ printf '\n# comment\n1 0 broken\n' | cat old.txt - > short.txt
  $ python3 "${VERIFY}" --input short.txt rules.yml
  OK: All process privileges match expected configuration

"-" reads the list from standard input:

  $ python3 "${VERIFY}" --input - rules.yml < old.txt
  OK: All process privileges match expected configuration

A process whose parent is not in the list, or that is its own parent, is a
root process:

  $ cat > roots.txt <<'EOF'
  > 1 1 procd root:root full
  > 7 6 orphan root:root full
  > 400 1 -ash root:root full
  > 401 1 amxrt:wifi-scheduler root:root full
  > 402 1 my\040daemon nobody:nogroup none
  > EOF
  $ python3 "${VERIFY}" --input roots.txt rules.yml
  ERROR: unexpected root process 'orphan' (id=root:root, caps=full)
  [1]
