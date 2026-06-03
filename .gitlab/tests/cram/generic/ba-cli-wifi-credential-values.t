Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that ba-cli preserves valid SSID and WPA credential values:

  $ R "sh -s" <<'EOF'
  > set -eu
  > ssid_max='12345678901234567890123456789012'
  > passphrase_max='123456789012345678901234567890123456789012345678901234567890123'
  > psk='0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
  > restore_wifi_credentials() {
  >     printf '%s\n' \
  >         'Device.WiFi.SSID.1.SSID="prplOS"' \
  >         'Device.WiFi.AccessPoint.1.Security.KeyPassPhrase="password"' \
  >         'Device.WiFi.AccessPoint.1.Security.SAEPassphrase=""' \
  >         'Device.WiFi.AccessPoint.1.Security.PreSharedKey=""' |
  >         ba-cli -a >/dev/null 2>&1 || true
  > }
  > set_and_check_value() {
  >     path="$1"
  >     value="$2"
  >     expected="$3"
  >     out=$(
  >         printf '%s\n' \
  >             "${path}=\"${value}\"" \
  >             "${path}?" |
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
  > set_and_check_credentials() {
  >     ssid="$1"
  >     passphrase="$2"
  >     expected_ssid="$3"
  >     expected_passphrase="$4"
  >     out=$(
  >         printf '%s\n' \
  >             "Device.WiFi.SSID.1.SSID=\"${ssid}\"" \
  >             "Device.WiFi.AccessPoint.1.Security.KeyPassPhrase=\"${passphrase}\"" \
  >             'Device.WiFi.SSID.1.SSID?' \
  >             'Device.WiFi.AccessPoint.1.Security.KeyPassPhrase?' |
  >             ba-cli -a 2>&1
  >     )
  >     if printf '%s\n' "$out" | grep -q 'ERROR:'; then
  >         printf '%s\n' "$out"
  >         exit 1
  >     fi
  >     if ! printf '%s\n' "$out" | grep -F "$expected_ssid" >/dev/null; then
  >         printf '%s\n' "$out"
  >         exit 1
  >     fi
  >     if ! printf '%s\n' "$out" | grep -F "$expected_passphrase" >/dev/null; then
  >         printf '%s\n' "$out"
  >         exit 1
  >     fi
  > }
  > trap restore_wifi_credentials EXIT
  > set_and_check_credentials 'A' '12345678' 'SSID="A"' 'KeyPassPhrase="12345678"'
  > set_and_check_credentials ' AN' ' pass1234' 'SSID=" AN"' 'KeyPassPhrase=" pass1234"'
  > set_and_check_credentials 'AN ' 'pass1234 ' 'SSID="AN "' 'KeyPassPhrase="pass1234 "'
  > set_and_check_credentials 'A  N' 'pass  word' 'SSID="A  N"' 'KeyPassPhrase="pass  word"'
  > set_and_check_value 'Device.WiFi.AccessPoint.1.Security.KeyPassPhrase' '        ' 'KeyPassPhrase="        "'
  > set_and_check_credentials "$ssid_max" "$passphrase_max" "SSID=\"$ssid_max\"" "KeyPassPhrase=\"$passphrase_max\""
  > set_and_check_credentials 'ATTqMGd8\CK' 'pass\word' 'SSID="ATTqMGd8\\CK"' 'KeyPassPhrase="pass\\word"'
  > set_and_check_value 'Device.WiFi.AccessPoint.1.Security.SAEPassphrase' ' sae12345' 'SAEPassphrase=" sae12345"'
  > set_and_check_value 'Device.WiFi.AccessPoint.1.Security.SAEPassphrase' 'sae12345 ' 'SAEPassphrase="sae12345 "'
  > set_and_check_value 'Device.WiFi.AccessPoint.1.Security.SAEPassphrase' 'sae  pass' 'SAEPassphrase="sae  pass"'
  > set_and_check_value 'Device.WiFi.AccessPoint.1.Security.PreSharedKey' "$psk" "PreSharedKey=\"$psk\""
  > printf '%s\n' 'wifi-credential-values-ok'
  > EOF
  wifi-credential-values-ok
