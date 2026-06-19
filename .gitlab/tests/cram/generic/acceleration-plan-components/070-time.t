Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that we've expected datamodel:

  $ R "ba-cli 'dump -r Time.' | cut -b 34- | sort"
  Time.
  Time.Client.
  Time.Client.1.
  Time.Client.1.Authentication.
  Time.Client.1.Stats.
  Time.Server.
  Time.Server.1.
  Time.Server.1.Authentication.
  Time.Server.1.Stats.
  Time.Server.2.
  Time.Server.2.Authentication.
  Time.Server.2.Stats.
  Time.Server.3.
  Time.Server.3.Authentication.
  Time.Server.3.Stats.

  $ R "ba-cli -l 'Time.Client.1.Port?;Time.Client.1.Status?;Time.Client.1.Servers?;Time.Client.1.Alias?;Time.Client.1.Mode?' | sort"
  0.europe.pool.ntp.org, 1.europe.pool.ntp.org
  123
  Synchronized
  Unicast
  cpe-Client-1

  $ R "ba-cli -l 'Time.Server.*.Port?;Time.Server.*.Status?;Time.Server.*.Alias?;Time.Server.*.Mode?' | sort"
  123
  123
  123
  Unicast
  Unicast
  Unicast
  Up
  Up
  Up
  cpe-br-guest
  cpe-br-lan
  cpe-br-lcm

Check that we've correct Time.CurrentLocalTime:

  $ time=$(R "ba-cli -l 'Time.CurrentLocalTime?'")
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

  $ R "ba-cli 'Time.Enable=false' > /dev/null" ; sleep 5

  $ R "ba-cli -l 'Time.Client.1.Status?'"
  Disabled

  $ R "ba-cli -l 'Time.Status?'"
  Disabled

  $ R "ba-cli 'Time.Enable=true' > /dev/null" ; sleep 5

Check that Status has expected Unsynchronized state:

  $ R "ba-cli -l 'Time.Client.1.Status?'"
  Unsynchronized

  $ R "ba-cli -l 'Time.Status?'"
  Unsynchronized

Enable outgoing NTP traffic:

  $ R "iptables -D OUTPUT -p udp --dport 123 -j DROP"

Disable and enable the Time manager to force time synchronization:

  $ R "ba-cli 'Time.Enable=false' > /dev/null" ; sleep 5

  $ R "ba-cli -l 'Time.Client.1.Status?'"
  Disabled

  $ R "ba-cli -l 'Time.Status?'"
  Disabled

  $ R "ba-cli 'Time.Enable=true' > /dev/null" ; sleep 10

Check that Status has expected Synchronized state:

  $ R "ba-cli -l 'Time.Client.1.Status?'"
  Synchronized

  $ R "ba-cli -l 'Time.Status?'"
  Synchronized

Check that CPE can provide NTP to LAN clients:

  $ ntpdate -q 192.168.1.1 2>&1 | grep adjust
  .* adjust time server .* (re)

Disable NTP server for LAN clients:

  $ R "ba-cli 'Time.Server.1.Enable=false' > /dev/null" ; sleep 1

Check that CPE can't provide NTP to LAN clients:

  $ ntpdate -q 192.168.1.1 2>&1 | grep adjust
  [1]

Enable NTP server for LAN clients:

  $ R "ba-cli 'Time.Server.1.Enable=true' > /dev/null" ; sleep 10

Check that CPE provides again NTP to the LAN clients:

  $ ntpdate -q 192.168.1.1 2>&1 | grep adjust
  .* adjust time server .* (re)

Check default timezone:

  $ (R "date +%Z")
  GMT

Check LocalTimeZone correctly filter wrong TZ:

  $ (R "ba-cli Time.LocalTimeZone=\"JST-9\"") | sed 's|[>,]||g'
   Time.LocalTimeZone=JST-9
  Time.
  Time.LocalTimeZone="JST-9"
  
  $ (R "date +%Z")
  JST

  $ (R "ba-cli Time.LocalTimeZone=\"UTC0\"") | sed 's|[>,]||g'
   Time.LocalTimeZone=UTC0
  Time.
  Time.LocalTimeZone="UTC0"
  
  $ (R "date +%Z")
  UTC

  $ (R "ba-cli Time.LocalTimeZone=\"NOTAVALIDETZ\"") | sed 's|[>,]||g'
   Time.LocalTimeZone=NOTAVALIDETZ
  ERROR: set Time.LocalTimeZone failed (10 - invalid value)
  
  $ (R "date +%Z")
  UTC

  $ (R "ba-cli Time.LocalTimeZone=\"GMT0\"") | sed 's|[>,]||g'
   Time.LocalTimeZone=GMT0
  Time.
  Time.LocalTimeZone="GMT0"
  
  $ (R "date +%Z")
  GMT

  $ (R "ba-cli Time.LocalTimeZone=\"/usr/share/zoneinfo/Universal\"") | sed 's|[>,]||g'
   Time.LocalTimeZone=/usr/share/zoneinfo/Universal
  ERROR: set Time.LocalTimeZone failed (10 - invalid value)
  
  $ (R "date +%Z")
  GMT

Set back default timezone:

  $ (R "ba-cli Time.LocalTimeZone=\"GMT0\"") | sed 's|[>,]||g'
   Time.LocalTimeZone=GMT0
  Time.
  Time.LocalTimeZone="GMT0"
  
  $ (R "date +%Z")
  GMT
