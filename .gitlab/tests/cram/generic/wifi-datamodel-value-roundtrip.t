Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check WiFi datamodel SSID and credential values round-trip through control-plane frontends:

  $ R sh -s <<'EOF'
  > set -eu
  > hex() {
  >     hexdump -v -e '1/1 "%02x"'
  > }
  > value_for() {
  >     field=$1
  >     value_case=$2
  >     case "$field:$value_case" in
  >         SSID:empty) printf '' ;;
  >         SSID:one-space) printf ' ' ;;
  >         SSID:two-spaces) printf '  ' ;;
  >         SSID:leading-space) printf ' Test' ;;
  >         SSID:trailing-space) printf 'Test ' ;;
  >         SSID:repeated-space) printf 'Te  st' ;;
  >         SSID:backslash) printf 'Test\\ing' ;;
  >         SSID:quote) printf 'Test"ing' ;;
  >         SSID:tab) printf 'Test\ting' ;;
  >         KeyPassphrase:empty) printf '' ;;
  >         KeyPassphrase:one-space) printf ' ' ;;
  >         KeyPassphrase:two-spaces) printf '  ' ;;
  >         KeyPassphrase:leading-space) printf ' pass1234' ;;
  >         KeyPassphrase:trailing-space) printf 'pass1234 ' ;;
  >         KeyPassphrase:repeated-space) printf 'pass  1234' ;;
  >         KeyPassphrase:backslash) printf 'pass\\word' ;;
  >         KeyPassphrase:quote) printf 'pass"word' ;;
  >         KeyPassphrase:tab) printf 'pass\tword' ;;
  >         SAEPassphrase:empty) printf '' ;;
  >         SAEPassphrase:one-space) printf ' ' ;;
  >         SAEPassphrase:two-spaces) printf '  ' ;;
  >         SAEPassphrase:leading-space) printf ' pass1234' ;;
  >         SAEPassphrase:trailing-space) printf 'pass1234 ' ;;
  >         SAEPassphrase:repeated-space) printf 'pass  1234' ;;
  >         SAEPassphrase:backslash) printf 'pass\\word' ;;
  >         SAEPassphrase:quote) printf 'pass"word' ;;
  >         SAEPassphrase:tab) printf 'pass\tword' ;;
  >         PreSharedKey:empty) printf '' ;;
  >         PreSharedKey:one-space) printf ' ' ;;
  >         PreSharedKey:two-spaces) printf '  ' ;;
  >         PreSharedKey:psk) printf '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' ;;
  >         PreSharedKey:backslash) printf 'pass\\word' ;;
  >         PreSharedKey:quote) printf 'pass"word' ;;
  >         PreSharedKey:tab) printf 'pass\tword' ;;
  >         *) echo "unknown value case: $field $value_case" >&2; exit 1 ;;
  >     esac
  > }
  > amx_literal_for() {
  >     field=$1
  >     value_case=$2
  >     case "$field:$value_case" in
  >         SSID:empty|KeyPassphrase:empty|SAEPassphrase:empty|PreSharedKey:empty) printf '""' ;;
  >         SSID:one-space|KeyPassphrase:one-space|SAEPassphrase:one-space|PreSharedKey:one-space) printf '" "' ;;
  >         SSID:two-spaces|KeyPassphrase:two-spaces|SAEPassphrase:two-spaces|PreSharedKey:two-spaces) printf '"  "' ;;
  >         SSID:leading-space) printf '" Test"' ;;
  >         SSID:trailing-space) printf '"Test "' ;;
  >         SSID:repeated-space) printf '"Te  st"' ;;
  >         SSID:backslash) printf '"Test\\\\ing"' ;;
  >         SSID:quote) printf '"Test\\"ing"' ;;
  >         SSID:tab) printf '"Test\ting"' ;;
  >         KeyPassphrase:leading-space|SAEPassphrase:leading-space) printf '" pass1234"' ;;
  >         KeyPassphrase:trailing-space|SAEPassphrase:trailing-space) printf '"pass1234 "' ;;
  >         KeyPassphrase:repeated-space|SAEPassphrase:repeated-space) printf '"pass  1234"' ;;
  >         KeyPassphrase:backslash|SAEPassphrase:backslash) printf '"pass\\\\word"' ;;
  >         KeyPassphrase:quote|SAEPassphrase:quote) printf '"pass\\"word"' ;;
  >         KeyPassphrase:tab|SAEPassphrase:tab) printf '"pass\tword"' ;;
  >         PreSharedKey:psk) printf '"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"' ;;
  >         PreSharedKey:backslash) printf '"pass\\\\word"' ;;
  >         PreSharedKey:quote) printf '"pass\\"word"' ;;
  >         PreSharedKey:tab) printf '"pass\tword"' ;;
  >         *) echo "unknown AMX literal case: $field $value_case" >&2; exit 1 ;;
  >     esac
  > }
  > ba_path_for() {
  >     case "$1" in
  >         SSID) printf 'Device.WiFi.SSID.1.SSID' ;;
  >         KeyPassphrase) printf 'Device.WiFi.AccessPoint.1.Security.KeyPassphrase' ;;
  >         SAEPassphrase) printf 'Device.WiFi.AccessPoint.1.Security.SAEPassphrase' ;;
  >         PreSharedKey) printf 'Device.WiFi.AccessPoint.1.Security.PreSharedKey' ;;
  >         *) echo "unknown field: $1" >&2; exit 1 ;;
  >     esac
  > }
  > raw_object_for() {
  >     case "$1" in
  >         SSID) printf 'WiFi.SSID.1' ;;
  >         KeyPassphrase|SAEPassphrase|PreSharedKey) printf 'WiFi.AccessPoint.1.Security' ;;
  >         *) echo "unknown field: $1" >&2; exit 1 ;;
  >     esac
  > }
  > raw_param_for() {
  >     case "$1" in
  >         SSID) printf 'SSID' ;;
  >         KeyPassphrase) printf 'KeyPassPhrase' ;;
  >         SAEPassphrase) printf 'SAEPassphrase' ;;
  >         PreSharedKey) printf 'PreSharedKey' ;;
  >         *) echo "unknown field: $1" >&2; exit 1 ;;
  >     esac
  > }
  > read_value() {
  >     reader=$1
  >     field=$2
  >     ba_path=$(ba_path_for "$field")
  >     obj=${ba_path%.*}
  >     param=${ba_path##*.}
  >     raw_obj=$(raw_object_for "$field")
  >     raw_param=$(raw_param_for "$field")
  >     case "$reader" in
  >         ba-cli)
  >             ba-cli -j -l "$ba_path?" |
  >                 jsonfilter -e "@[0].*.$param"
  >             ;;
  >         ubus)
  >             ubus -S call "$raw_obj" _get \
  >                 "{\"parameters\":[\"$raw_param\"]}" |
  >                 jsonfilter -e "@.*.$raw_param"
  >             ;;
  >         usp-cli)
  >             usp-cli -j -l "$ba_path?" |
  >                 jsonfilter -e "@[0].*.$param"
  >             ;;
  >         obuspa)
  >             obuspa -f /etc/obuspa.db -c get "$obj.$param" |
  >                 sed -n 's/^.* => //p'
  >             ;;
  >         *) echo "unknown reader: $reader" >&2; exit 1 ;;
  >     esac
  > }
  > is_expected_valid() {
  >     field=$1
  >     value_case=$2
  >     case "$field:$value_case" in
  >         SSID:empty) return 1 ;;
  >         KeyPassphrase:empty|KeyPassphrase:one-space|KeyPassphrase:two-spaces|KeyPassphrase:tab) return 1 ;;
  >         SAEPassphrase:one-space|SAEPassphrase:two-spaces|SAEPassphrase:tab) return 1 ;;
  >         PreSharedKey:one-space|PreSharedKey:two-spaces|PreSharedKey:backslash|PreSharedKey:quote|PreSharedKey:tab) return 1 ;;
  >         *) return 0 ;;
  >     esac
  > }
  > assert_reader() {
  >     reader=$1
  >     field=$2
  >     value_case=$3
  >     expected_hex=$(value_for "$field" "$value_case" | hex)
  >     actual=$(read_value "$reader" "$field")
  >     actual_hex=$(printf '%s' "$actual" | hex)
  >     if [ "$actual_hex" != "$expected_hex" ]; then
  >         {
  >             echo "value mismatch"
  >             echo "reader=$reader field=$field case=$value_case"
  >             echo "expected=$expected_hex actual=$actual_hex"
  >         } >&2
  >         exit 1
  >     fi
  > }
  > test_value() {
  >     field=$1
  >     value_case=$2
  >     ba_path=$(ba_path_for "$field")
  >     output=$(ba-cli -l "$ba_path=$(amx_literal_for "$field" "$value_case")" 2>&1 || true)
  >     if is_expected_valid "$field" "$value_case"; then
  >         if printf '%s\n' "$output" | grep -q 'ERROR:'; then
  >             {
  >                 echo "unexpected validator rejection"
  >                 echo "field=$field case=$value_case"
  >                 printf '%s\n' "$output"
  >             } >&2
  >             exit 1
  >         fi
  >         for reader in ba-cli ubus usp-cli obuspa; do
  >             assert_reader "$reader" "$field" "$value_case"
  >         done
  >     else
  >         if printf '%s\n' "$output" | grep -q 'ERROR:'; then
  >             echo "$field $value_case validator-rejected-ok"
  >         else
  >             {
  >                 echo "validator accepted an expected-invalid value"
  >                 echo "field=$field case=$value_case"
  >                 printf '%s\n' "$output"
  >             } >&2
  >             exit 1
  >         fi
  >     fi
  > }
  > restore_defaults() {
  >     ba-cli -l 'Device.WiFi.SSID.1.SSID="prplOS"' >/dev/null 2>&1 || true
  >     ba-cli -l 'Device.WiFi.AccessPoint.1.Security.KeyPassphrase="password"' >/dev/null 2>&1 || true
  >     ba-cli -l 'Device.WiFi.AccessPoint.1.Security.SAEPassphrase=""' >/dev/null 2>&1 || true
  >     ba-cli -l 'Device.WiFi.AccessPoint.1.Security.PreSharedKey=""' >/dev/null 2>&1 || true
  > }
  > trap restore_defaults EXIT
  > restore_defaults
  > for value_case in empty one-space two-spaces leading-space trailing-space repeated-space backslash quote tab; do
  >     test_value SSID "$value_case"
  > done
  > for field in KeyPassphrase SAEPassphrase; do
  >     for value_case in empty one-space two-spaces leading-space trailing-space repeated-space backslash quote tab; do
  >         test_value "$field" "$value_case"
  >     done
  > done
  > for value_case in empty one-space two-spaces psk backslash quote tab; do
  >     test_value PreSharedKey "$value_case"
  > done
  > echo wifi-datamodel-value-roundtrip-ok
  > EOF
  SSID empty validator-rejected-ok
  KeyPassphrase empty validator-rejected-ok
  KeyPassphrase one-space validator-rejected-ok
  KeyPassphrase two-spaces validator-rejected-ok
  KeyPassphrase tab validator-rejected-ok
  SAEPassphrase one-space validator-rejected-ok
  SAEPassphrase two-spaces validator-rejected-ok
  SAEPassphrase tab validator-rejected-ok
  PreSharedKey one-space validator-rejected-ok
  PreSharedKey two-spaces validator-rejected-ok
  PreSharedKey backslash validator-rejected-ok
  PreSharedKey quote validator-rejected-ok
  PreSharedKey tab validator-rejected-ok
  wifi-datamodel-value-roundtrip-ok
