Runtime-added EndPoint instances must expose Stats parameters (PPW-2446).

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting $TESTFILE"

Create an EndPoint instance without an SSID link:

  $ EP=$(R "ba-cli -l -j 'WiFi.EndPoint.+ {Alias=\"ep-ppw2446\"}'" | jq -er 'if type == "array" then .[0] else . end | keys[]')
  $ printf '%s\n' "$EP"
  WiFi.EndPoint.[0-9]+. (re)

Read Stats and check the required parameters:

  $ if stats=$(wifi_dm "${EP#WiFi.}Stats.?" "WiFi." "ba-cli"); then
  >   failed=0
  >   for parameter in LastDataDownlinkRate LastDataUplinkRate Retransmissions SignalStrength; do
  >     if ! printf '%s\n' "$stats" | grep -Fq ".${parameter}="; then
  >       echo "FAIL: ${EP}Stats.${parameter} is missing"
  >       failed=1
  >     fi
  >   done
  >   test "$failed" -eq 0 && echo "Stats parameters present"
  > else
  >   printf '%s\n' "$stats"
  >   false
  > fi
  Stats parameters present

Delete the test instance:

  $ R "ba-cli -l -j '${EP}-'" >/dev/null
