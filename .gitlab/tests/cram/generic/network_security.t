Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that NO port is open from WAN:

  $ nmap --open 10.0.0.2 | grep open
  [1]

Wait for services to become ready:

$ R '
  > timeout=10
  > while [ $timeout -gt 0 ] && (! pgrep lighttpd >/dev/null || ! pgrep dnsmasq >/dev/null); do
  >   sleep 1
  >   timeout=$((timeout - 1))
  > done
  > '

Check that only certain ports are open from LAN:

  $ nmap --exclude-ports T:5000 --open 192.168.1.1 | grep open
  22/tcp open  ssh
  53/tcp open  domain
  80/tcp open  http
