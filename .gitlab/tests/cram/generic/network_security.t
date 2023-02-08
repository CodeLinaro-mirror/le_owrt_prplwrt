Check that NO port is open from WAN:

  $ nmap --open 10.0.0.2 | grep open
  [1]

Check that only certain ports are open from LAN:

  $ nmap --open 192.168.1.1 | grep open
  22/tcp open  ssh
  53/tcp open  domain
  80/tcp open  http
