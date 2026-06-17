Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check non-WiFi datamodel string values round-trip through ba-cli, ubus, usp-cli and obuspa:

  $ R sh -s <<'EOF'
  > set -eu
  > alias_name=ppw1971-value-roundtrip
  > hex() {
  >     hexdump -v -e '1/1 "%02x"'
  > }
  > value_for() {
  >     case "$1" in
  >         empty) printf '' ;;
  >         one-space) printf ' ' ;;
  >         two-spaces) printf '  ' ;;
  >         leading-space) printf ' leading' ;;
  >         trailing-space) printf 'trailing ' ;;
  >         repeated-space) printf 'two  spaces' ;;
  >         backslash) printf 'one\\slash' ;;
  >         quote) printf 'one"quote' ;;
  >         tab) printf 'one\ttab' ;;
  >         *) echo "unknown value case: $1" >&2; exit 1 ;;
  >     esac
  > }
  > amx_literal_for() {
  >     case "$1" in
  >         empty) printf '""' ;;
  >         one-space) printf '" "' ;;
  >         two-spaces) printf '"  "' ;;
  >         leading-space) printf '" leading"' ;;
  >         trailing-space) printf '"trailing "' ;;
  >         repeated-space) printf '"two  spaces"' ;;
  >         backslash) printf '"one\\\\slash"' ;;
  >         quote) printf '"one\\"quote"' ;;
  >         tab) printf '"one\ttab"' ;;
  >         *) echo "unknown value case: $1" >&2; exit 1 ;;
  >     esac
  > }
  > json_literal_for() {
  >     case "$1" in
  >         empty) printf '""' ;;
  >         one-space) printf '" "' ;;
  >         two-spaces) printf '"  "' ;;
  >         leading-space) printf '" leading"' ;;
  >         trailing-space) printf '"trailing "' ;;
  >         repeated-space) printf '"two  spaces"' ;;
  >         backslash) printf '"one\\\\slash"' ;;
  >         quote) printf '"one\\"quote"' ;;
  >         tab) printf '"one\\ttab"' ;;
  >         *) echo "unknown value case: $1" >&2; exit 1 ;;
  >     esac
  > }
  > find_profile() {
  >     ba-cli "BulkData.Profile.[Alias==\"$alias_name\"].?" |
  >         sed -n 's/^BulkData\.Profile\.\([0-9][0-9]*\)\.$/\1/p' |
  >         head -1
  > }
  > cleanup() {
  >     while :; do
  >         inst=$(find_profile 2>/dev/null || true)
  >         [ -n "$inst" ] || break
  >         ba-cli "BulkData.Profile.$inst.-" >/dev/null 2>&1 || break
  >     done
  > }
  > read_value() {
  >     case "$1" in
  >         ba-cli)
  >             ba-cli -j -l "BulkData.Profile.$inst.HTTP.Username?" |
  >                 jsonfilter -e '@[0].*.Username'
  >             ;;
  >         ubus)
  >             ubus -S call "BulkData.Profile.$inst.HTTP" _get \
  >                 '{"parameters":["Username"]}' |
  >                 jsonfilter -e '@.*.Username'
  >             ;;
  >         usp-cli)
  >             usp-cli -j -l "Device.BulkData.Profile.$inst.HTTP.Username?" |
  >                 jsonfilter -e '@[0].*.Username'
  >             ;;
  >         obuspa)
  >             obuspa -f /etc/obuspa.db -c get \
  >                 "Device.BulkData.Profile.$inst.HTTP.Username" |
  >                 sed -n 's/^.* => //p'
  >             ;;
  >         *) echo "unknown reader: $1" >&2; exit 1 ;;
  >     esac
  > }
  > write_value() {
  >     writer=$1
  >     value_case=$2
  >     case "$writer" in
  >         ba-cli)
  >             ba-cli -l "BulkData.Profile.$inst.HTTP.Username=$(amx_literal_for "$value_case")" >/dev/null
  >             ;;
  >         ubus)
  >             ubus -S call "BulkData.Profile.$inst.HTTP" _set \
  >                 "{\"parameters\":{\"Username\":$(json_literal_for "$value_case")}}" >/dev/null
  >             ;;
  >         usp-cli)
  >             usp-cli -j -l "Device.BulkData.Profile.$inst.HTTP.Username=$(amx_literal_for "$value_case")" >/dev/null
  >             ;;
  >         obuspa)
  >             value=$(value_for "$value_case")
  >             obuspa -f /etc/obuspa.db -c set \
  >                 "Device.BulkData.Profile.$inst.HTTP.Username" "$value" >/dev/null
  >             ;;
  >         *) echo "unknown writer: $writer" >&2; exit 1 ;;
  >     esac
  > }
  > obuspa_writer_supports() {
  >     case "$1" in
  >         one-space|two-spaces|leading-space|trailing-space) return 1 ;;
  >         *) return 0 ;;
  >     esac
  > }
  > assert_reader() {
  >     writer=$1
  >     reader=$2
  >     value_case=$3
  >     expected_hex=$(value_for "$value_case" | hex)
  >     actual=$(read_value "$reader")
  >     actual_hex=$(printf '%s' "$actual" | hex)
  >     if [ "$actual_hex" != "$expected_hex" ]; then
  >         {
  >             echo "value mismatch"
  >             echo "writer=$writer reader=$reader case=$value_case"
  >             echo "expected=$expected_hex actual=$actual_hex"
  >         } >&2
  >         exit 1
  >     fi
  > }
  > assert_all_readers() {
  >     writer=$1
  >     value_case=$2
  >     for reader in ba-cli ubus usp-cli obuspa; do
  >         assert_reader "$writer" "$reader" "$value_case"
  >     done
  > }
  > cleanup
  > trap cleanup EXIT
  > ba-cli "BulkData.Profile.+{Alias=\"$alias_name\", EncodingType=\"JSON\", Name=\"$alias_name\", Protocol=\"HTTP\", Enable=0}" >/dev/null
  > inst=$(find_profile)
  > [ -n "$inst" ] || {
  >     echo "could not create BulkData scratch profile" >&2
  >     exit 1
  > }
  > # HTTP.Password is intentionally not used here because several frontends
  > # mask it on readback. HTTP.Username is a mutable non-WiFi string that is
  > # readable through ba-cli, raw ubus, usp-cli and obuspa.
  > cases="empty one-space two-spaces leading-space trailing-space repeated-space backslash quote tab"
  > writers="ba-cli ubus usp-cli obuspa"
  > for writer in $writers; do
  >     for value_case in $cases; do
  >         if [ "$writer" = obuspa ] && ! obuspa_writer_supports "$value_case"; then
  >             continue
  >         fi
  >         write_value "$writer" "$value_case"
  >         assert_all_readers "$writer" "$value_case"
  >     done
  > done
  > echo bulkdata-datamodel-value-roundtrip-ok
  > EOF
  bulkdata-datamodel-value-roundtrip-ok
