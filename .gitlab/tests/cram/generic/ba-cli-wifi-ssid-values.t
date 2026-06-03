Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that ba-cli automated stdin handles SSID values that cross the input
buffer boundary:

  $ R "sh -s" <<'EOF'
  > set -eu
  > restore_ssid() {
  >     printf '%s\n' 'Device.WiFi.SSID.1.SSID="prplOS"' | ba-cli -a >/dev/null 2>&1 || true
  > }
  > set_and_check_ssid() {
  >     value="$1"
  >     expected="$2"
  >     out=$(
  >         printf '%s\n' \
  >             "Device.WiFi.SSID.1.SSID=\"${value}\"" \
  >             'Device.WiFi.SSID.1.SSID?' |
  >             ba-cli -a 2>&1
  >     )
  >     if printf '%s\n' "$out" | grep -q 'ERROR:'; then
  >         printf '%s\n' "$out"
  >         exit 1
  >     fi
  >     if ! printf '%s\n' "$out" | grep -F "$expected" >/dev/null; then
  >         printf '%s\n' "$out"
  >         exit 1
  >     fi
  > }
  > set_and_check_ssid_split_write() {
  >     expected="$1"
  >     out=$(
  >         {
  >             printf '%s' 'Device.WiFi.SSID.1.SSID="PPW197'
  >             sleep 1
  >             printf '%s\n' '1"' 'Device.WiFi.SSID.1.SSID?'
  >         } | ba-cli -a 2>&1
  >     )
  >     if printf '%s\n' "$out" | grep -q 'ERROR:'; then
  >         printf '%s\n' "$out"
  >         exit 1
  >     fi
  >     if ! printf '%s\n' "$out" | grep -F "$expected" >/dev/null; then
  >         printf '%s\n' "$out"
  >         exit 1
  >     fi
  > }
  > trap restore_ssid EXIT
  > set_and_check_ssid_split_write 'SSID="PPW1971"'
  > printf '%s\n' 'ssid-seven-byte-ok'
  > set_and_check_ssid 'ATTqMGd8\CK' 'SSID="ATTqMGd8\\CK"'
  > printf '%s\n' 'ssid-single-backslash-ok'
  > set_and_check_ssid ' ' 'SSID=" "'
  > set_and_check_ssid '  ' 'SSID="  "'
  > set_and_check_ssid ' AN' 'SSID=" AN"'
  > set_and_check_ssid 'AN ' 'SSID="AN "'
  > set_and_check_ssid 'AN  ' 'SSID="AN  "'
  > set_and_check_ssid 'A  N' 'SSID="A  N"'
  > printf '%s\n' 'ssid-whitespace-ok'
  > EOF
  ssid-seven-byte-ok
  ssid-single-backslash-ok
  ssid-whitespace-ok
