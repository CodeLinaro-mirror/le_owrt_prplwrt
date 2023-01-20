Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that NTP pools are reachable over network:

  $ ping -c3 -W30 0.europe.pool.ntp.org | grep '3 packets' | cut -d, -f1-3
  3 packets transmitted, 3 received, 0% packet loss

  $ ping -c3 -W30 1.europe.pool.ntp.org | grep '3 packets' | cut -d, -f1-3
  3 packets transmitted, 3 received, 0% packet loss

Check that we've expected datamodel:

  $ R "ubus list | grep Time. | sort"
  Time.Client
  Time.Client.1
  Time.Client.1.Authentication
  Time.Client.1.Stats
  Time.Server
  Time.Server.1
  Time.Server.1.Authentication
  Time.Server.1.Stats
  Time.Server.2
  Time.Server.2.Authentication
  Time.Server.2.Stats

  $ R "ubus call Time.Client.1 _get | jsonfilter -e @[*].Port -e @[*].Status -e @[*].Servers -e @[*].Alias -e @[*].Mode | sort"
  0.europe.pool.ntp.org, 1.europe.pool.ntp.org
  123
  Manycast
  Synchronized
  cpe-client-1

  $ R "ubus call Time.Server _get | jsonfilter -e @[*].Port -e @[*].Status -e @[*].Alias -e @[*].Mode | sort"
  123
  123
  Enabled
  Enabled
  Unicast
  Unicast
  cpe-br-guest
  cpe-br-lan

Check that we've correct Time.CurrentLocalTime:

  $ time=$(R "ubus call Time _get '{\"rel_path\":\"CurrentLocalTime\"}' | jsonfilter -e @[*].CurrentLocalTime")
  $ time=$(echo $time | sed -E 's/([0-9\-]+)T([0-9]+:[0-9]+:[0-9]+).*/\1 \2/')
  $ time=$(date -d "$time" +'%s')
  $ sys=$(R date +"%s")
  $ diff=$(( (sys - time) ))
  $ tolerance=5
  $ R logger -t cram "Time.CurrentLocalTime=$(date -d @$time +'%c') SystemTime=$(date -d @$sys +'%c') diff=${diff}s tolerance=${tolerance}s"
  $ test "$diff" -le "$tolerance" && echo "Time is OK"
  Time is OK

Disable outgoing NTP traffic:

  $ R "iptables -A OUTPUT -p udp --dport 123 -j DROP"

Disable and enable the Time manager to force time synchronization:

  $ R "ubus -S call Time _set '{\"parameters\":{\"Enable\":False}}'" ; sleep 1
  {"Time.":{"Enable":false}}

  $ R "ubus -S call Time.Client.1 _get | jsonfilter -e @[*].Status"
  Disabled

  $ R "ubus -S call Time _get | jsonfilter -e @[*].Status"
  Disabled

  $ R "ubus -S call Time _set '{\"parameters\":{\"Enable\":True}}'" ; sleep 5
  {"Time.":{"Enable":true}}

Check that Status has expected Unsynchronized state:

  $ R "ubus -S call Time.Client.1 _get | jsonfilter -e @[*].Status"
  Unsynchronized

  $ R "ubus -S call Time _get | jsonfilter -e @[*].Status"
  Unsynchronized

Enable outgoing NTP traffic:

  $ R "iptables -D OUTPUT -p udp --dport 123 -j DROP"

Disable and enable the Time manager to force time synchronization:

  $ R "ubus -S call Time _set '{\"parameters\":{\"Enable\":False}}'" ; sleep 1
  {"Time.":{"Enable":false}}

  $ R "ubus -S call Time.Client.1 _get | jsonfilter -e @[*].Status"
  Disabled

  $ R "ubus -S call Time _get | jsonfilter -e @[*].Status"
  Disabled

  $ R "ubus -S call Time _set '{\"parameters\":{\"Enable\":True}}'" ; sleep 10
  {"Time.":{"Enable":true}}

Check that Status has expected Synchronized state:

  $ R "ubus -S call Time.Client.1 _get | jsonfilter -e @[*].Status"
  Synchronized

  $ R "ubus -S call Time _get | jsonfilter -e @[*].Status"
  Synchronized

Check that CPE can provide NTP to LAN clients:

  $ ntpdate -q 192.168.1.1 2>&1 | grep adjust
  .* adjust time server .* (re)

Disable NTP server for LAN clients:

  $ R "ubus -S call Time.Server.1 _set '{\"parameters\":{\"Enable\":False}}'" ; sleep 1
  {"Time.Server.1.":{"Enable":false}}

Check that CPE can't provide NTP to LAN clients:

  $ ntpdate -q 192.168.1.1 2>&1 | grep adjust
  [1]

Enable NTP server for LAN clients:

  $ R "ubus -S call Time.Server.1 _set '{\"parameters\":{\"Enable\":True}}'" ; sleep 10
  {"Time.Server.1.":{"Enable":true}}

Check that CPE provides again NTP to the LAN clients:

  $ ntpdate -q 192.168.1.1 2>&1 | grep adjust
  .* adjust time server .* (re)
