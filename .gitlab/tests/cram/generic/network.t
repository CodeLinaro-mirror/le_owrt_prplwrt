Check DUT is reachable over LAN:

  $ sudo ping -c3 -W1 192.168.1.2 2>/dev/null | grep '3 packets' | cut -d, -f1-3
  3 packets transmitted, 3 received, 0% packet loss
