Runtime-added EndPoint instances must expose Stats parameters (PPW-2446).

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting $TESTFILE"

Create an EndPoint instance without an SSID link:

  $ EP=$(R "ba-cli -l -j 'WiFi.EndPoint.+ {Alias=\"ep-ppw2446\"}'" | jq -er 'if type == "array" then .[0] else . end | keys[]')
  $ printf '%s\n' "$EP"
  WiFi.EndPoint.[0-9]+. (re)

Read Stats and check the required parameters (wifi_dm sorts its
output, so the grep result order is deterministic):

  $ wifi_dm "${EP#WiFi.}Stats.?" "WiFi." "ba-cli" | grep -w -e LastDataDownlinkRate -e LastDataUplinkRate -e Retransmissions -e SignalStrength
  WiFi.EndPoint.[0-9]+.Stats.LastDataDownlinkRate=[0-9]+ (re)
  WiFi.EndPoint.[0-9]+.Stats.LastDataUplinkRate=[0-9]+ (re)
  WiFi.EndPoint.[0-9]+.Stats.Retransmissions=[0-9]+ (re)
  WiFi.EndPoint.[0-9]+.Stats.SignalStrength=[0-9]+ (re)

Delete the test instance:

  $ R "ba-cli -l -j '${EP}-'" >/dev/null

  $ R logger -t cram "$TESTFILE finished!"
