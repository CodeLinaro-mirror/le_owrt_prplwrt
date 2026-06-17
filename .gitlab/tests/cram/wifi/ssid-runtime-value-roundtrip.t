Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Skip until the pwhm SSID escaping fix is enabled:

  $ [ "${PWHM_SSID_ESCAPING_FIXED:-0}" = 1 ] || exit 80

Check the configured SSID reaches hostapd and iw as the same byte value:

  $ R sh -s <<'EOF'
  > set -eu
  > ssid='ppw1971\ssid'
  > hex() {
  >     hexdump -v -e '1/1 "%02x"'
  > }
  > assert_hex() {
  >     source=$1
  >     actual=$2
  >     expected_hex=$(printf '%s' "$ssid" | hex)
  >     actual_hex=$(printf '%s' "$actual" | hex)
  >     if [ "$actual_hex" != "$expected_hex" ]; then
  >         {
  >             echo "SSID runtime mismatch"
  >             echo "source=$source"
  >             echo "expected=$expected_hex actual=$actual_hex"
  >         } >&2
  >         exit 1
  >     fi
  > }
  > matches_expected_hex() {
  >     actual=$1
  >     expected_hex=$(printf '%s' "$ssid" | hex)
  >     actual_hex=$(printf '%s' "$actual" | hex)
  >     [ "$actual_hex" = "$expected_hex" ]
  > }
  > hex_to_string() {
  >     escaped=$(printf '%s' "$1" | sed 's/../\\x&/g')
  >     printf '%b' "$escaped"
  > }
  > decode_iw_ssid() {
  >     printf '%b' "$1"
  > }
  > restore_defaults() {
  >     ba-cli -l 'Device.WiFi.AccessPoint.1.Enable=0' >/dev/null 2>&1 || true
  >     ba-cli -l 'Device.WiFi.SSID.1.SSID="prplOS"' >/dev/null 2>&1 || true
  > }
  > get_hostapd_ssid() {
  >     iface=$1
  >     conf=/tmp/${iface%.*}_hapd.conf
  >     bssid=$(usp-cli -l "Device.WiFi.SSID.[Name=='$iface'].BSSID?" |
  >         sed '/^$/d' | awk '{print toupper($0)}')
  >     awk -v iface="$iface" -v bssid="$bssid" '
  >         BEGIN { section = "primary"; primary = 0 }
  >         /^interface=/ {
  >             split($0, a, "=")
  >             if (a[2] == iface) primary = 1
  >             next
  >         }
  >         /^bss=/ {
  >             split($0, a, "=")
  >             section = (a[2] == iface) ? "target" : "other"
  >             next
  >         }
  >         /^bssid=/ {
  >             split($0, a, "=")
  >             if (section != "target") {
  >                 section = (toupper(a[2]) == bssid) ? "target" : "other"
  >             }
  >             next
  >         }
  >         /^ssid=/ {
  >             if ((section == "primary" && primary == 1) || section == "target") {
  >                 sub(/^ssid=/, "")
  >                 print "plain:" $0
  >                 exit
  >             }
  >         }
  >         /^ssid2=/ {
  >             if ((section == "primary" && primary == 1) || section == "target") {
  >                 sub(/^ssid2=/, "")
  >                 print "hex:" $0
  >                 exit
  >             }
  >         }
  >     ' "$conf" | {
  >         IFS= read -r entry || exit 0
  >         case "$entry" in
  >         plain:*)
  >             printf '%s' "${entry#plain:}"
  >             ;;
  >         hex:*)
  >             hex_to_string "${entry#hex:}"
  >             ;;
  >         esac
  >     }
  > }
  > trap restore_defaults EXIT
  > amx_wait_for Device.WiFi.
  > ba-cli -l 'X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=0' >/dev/null 2>&1 || true
  > ba-cli -l 'Device.WiFi.AccessPoint.1.Enable=0' >/dev/null
  > timeout=30
  > while [ "$timeout" -gt 0 ]; do
  >     status=$(ba-cli -j -l 'Device.WiFi.AccessPoint.1.Status?' |
  >         jsonfilter -e '@[0].*.Status' 2>/dev/null || true)
  >     [ "$status" != Enabled ] && break
  >     timeout=$((timeout - 1))
  >     sleep 1
  > done
  > ba-cli -l 'Device.WiFi.SSID.1.SSID="ppw1971\\ssid"' >/dev/null
  > ba-cli -l 'Device.WiFi.AccessPoint.1.Enable=1' >/dev/null
  > timeout=30
  > while [ "$timeout" -gt 0 ]; do
  >     status=$(ba-cli -j -l 'Device.WiFi.AccessPoint.1.Status?' |
  >         jsonfilter -e '@[0].*.Status' 2>/dev/null || true)
  >     [ "$status" = Enabled ] && break
  >     timeout=$((timeout - 1))
  >     sleep 1
  > done
  > [ "$timeout" -gt 0 ] || {
  >     echo "AccessPoint.1 did not become Enabled" >&2
  >     exit 1
  > }
  > iface=$(usp-cli -l 'Device.WiFi.AccessPoint.1.SSIDReference+.Name?' |
  >     sed '/^$/d' | head -1)
  > [ -n "$iface" ] || {
  >     echo "could not resolve AccessPoint.1 interface" >&2
  >     exit 1
  > }
  > timeout=30
  > dm_ssid=
  > hostapd_ssid=
  > iw_ssid=
  > while [ "$timeout" -gt 0 ]; do
  >     dm_ssid=$(ba-cli -j -l 'Device.WiFi.SSID.1.SSID?' |
  >         jsonfilter -e '@[0].*.SSID' 2>/dev/null || true)
  >     hostapd_ssid=$(get_hostapd_ssid "$iface")
  >     iw_ssid_escaped=$(iw dev "$iface" info |
  >         sed -n 's/^[[:space:]]*ssid //p' |
  >         head -1)
  >     iw_ssid=$(decode_iw_ssid "$iw_ssid_escaped")
  >     matches_expected_hex "$dm_ssid" &&
  >         matches_expected_hex "$hostapd_ssid" &&
  >         matches_expected_hex "$iw_ssid" &&
  >         break
  >     timeout=$((timeout - 1))
  >     sleep 1
  > done
  > assert_hex datamodel "$dm_ssid"
  > assert_hex hostapd "$hostapd_ssid"
  > assert_hex iw "$iw_ssid"
  > echo pwhm-ssid-runtime-value-roundtrip-ok
  > EOF
  pwhm-ssid-runtime-value-roundtrip-ok
