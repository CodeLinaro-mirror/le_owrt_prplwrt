Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that there is SFP+ stick present:

  $ R 'ba-cli --less --json SFPs.Mgmt.SFF8472.1.Transceiver.?' | jq -r '.[0]."SFPs.Mgmt.SFF8472.1.Transceiver." | [.VendorSN, .VendorPN, .VendorName] | sort | .[]'
  F\d+$ (re)
  FS
  SFP-10G-T

Check that we've WPS gpio key available:

  $ R "cat /sys/firmware/devicetree/base/gpio-keys/wps/label"
  wps\x00 (no-eol) (esc)

  $ R "hexdump -s2 -n2 -e '1/1 \"0x%02x \"' /sys/firmware/devicetree/base/gpio-keys/wps/linux,code"
  0x02 0x11  (no-eol)

Check that we've Reset gpio key available:

  $ R "cat /sys/firmware/devicetree/base/gpio-keys/reset/label"
  reset\x00 (no-eol) (esc)

  $ R "hexdump -s2 -n2 -e '1/1 \"0x%02x \"' /sys/firmware/devicetree/base/gpio-keys/reset/linux,code"
  0x01 0x98  (no-eol)

Check that expected DTS aliases are provided for ethernet interfaces:

  $ R 'cd /sys/firmware/devicetree/base
  > for eth_label in $(find -name label); do
  >   if [ "$(cat ${eth_label/label/device_type} 2>/dev/null)" != "network" ]; then
  >     continue
  >   fi
  >   eth_device="${eth_label/\/label/}"
  >   eth_intf="$(cat ${eth_label})"
  >   eth_aliases="$(cd aliases; grep -l "${eth_device/\./}" $(ls * | grep -Ev -e 'label-mac-device' -e '^ethernet[0-9]+$' | grep -E '^[-0-9a-z]+$'))"
  >   for eth_alias in $eth_aliases; do
  >      echo "intf=${eth_intf} => alias=${eth_alias}"
  >      break;
  >   done
  > done | LC_ALL=C sort'
  intf=eth0_1 => alias=10g
  intf=eth0_2 => alias=lan3
  intf=eth0_3 => alias=lan2
  intf=eth0_4 => alias=lan1
  intf=eth1 => alias=sfp

Check that ethernet-manager configuration contains expected CPE aliases based on DTS aliases:

  $ R "ba-cli -j -l Ethernet.Interface.*.Alias?" | jq -r '.[0] | to_entries[] | .value.Alias' | LC_ALL=C sort
  cpe-10g
  cpe-lan1
  cpe-lan2
  cpe-lan3
  cpe-sfp

Check altname for ethernet wan interface:

  $ R "ip link show dev eth1" | grep -o  'altname [^ ]\+' | awk '{print $2}'
  sfp0

Check IPsec acceleration readiness:

  $ R '
  > set -eu
  > fail() {
  >   echo "FAIL: $*" >&2
  >   exit 1
  > }
  > require_module() {
  >   module="$1"
  >   [ -d "/sys/module/$module" ] || fail "kernel module $module is not loaded"
  >   echo "module $module: loaded"
  > }
  > require_readable_file() {
  >   file="$1"
  >   [ -r "$file" ] || fail "firmware file $file is not readable"
  >   echo "firmware $file: readable"
  > }
  > require_crypto_driver() {
  >   algorithm="$1"
  >   expected_driver="$2"
  >   awk -v algorithm="$algorithm" -v expected_driver="$expected_driver" '\''
  >     /^name[[:space:]]*:/ {
  >       current_name = $0
  >       sub(/^[^:]*:[[:space:]]*/, "", current_name)
  >     }
  >     /^driver[[:space:]]*:/ {
  >       current_driver = $0
  >       sub(/^[^:]*:[[:space:]]*/, "", current_driver)
  >       if (current_name == algorithm && current_driver == expected_driver)
  >         found = 1
  >     }
  >     END { exit(found ? 0 : 1) }
  >   '\'' /proc/crypto || fail "crypto driver $expected_driver for $algorithm is not registered"
  >   echo "crypto $algorithm: $expected_driver"
  > }
  > require_readable_endpoint() {
  >   endpoint="$1"
  >   cat "$endpoint" >/dev/null 2>&1 || fail "debugfs endpoint $endpoint is not readable"
  >   echo "debugfs $endpoint: readable"
  > }
  > for module in crypto_safexcel esp4_offload esp6_offload mxl_vpn; do
  >   require_module "$module"
  > done
  > for file in /lib/firmware/inside-secure/ifpp.bin /lib/firmware/inside-secure/ipue.bin /lib/firmware/vpn_fw.img; do
  >   require_readable_file "$file"
  > done
  > require_crypto_driver "cbc(aes)" "safexcel-cbc-aes"
  > require_crypto_driver "hmac(sha256)" "safexcel-hmac-sha256"
  > require_crypto_driver "hmac(sha512)" "safexcel-hmac-sha512"
  > ip link show dev mxl_vpn >/dev/null 2>&1 || fail "network device mxl_vpn does not exist"
  > echo "netdev mxl_vpn: present"
  > require_readable_endpoint /sys/kernel/debug/vpn/fw_hdr
  > require_readable_endpoint /sys/kernel/debug/vpn/genconf
  > ' < /dev/null
  module crypto_safexcel: loaded
  module esp4_offload: loaded
  module esp6_offload: loaded
  module mxl_vpn: loaded
  firmware /lib/firmware/inside-secure/ifpp.bin: readable
  firmware /lib/firmware/inside-secure/ipue.bin: readable
  firmware /lib/firmware/vpn_fw.img: readable
  crypto cbc(aes): safexcel-cbc-aes
  crypto hmac(sha256): safexcel-hmac-sha256
  crypto hmac(sha512): safexcel-hmac-sha512
  netdev mxl_vpn: present
  debugfs /sys/kernel/debug/vpn/fw_hdr: readable
  debugfs /sys/kernel/debug/vpn/genconf: readable

Check GRE acceleration readiness:

  $ R '
  > set -eu
  > fail() {
  >   echo "FAIL: $*" >&2
  >   exit 1
  > }
  > require_module() {
  >   module="$1"
  >   [ -d "/sys/module/$module" ] || fail "kernel module $module is not loaded"
  >   echo "module $module: loaded"
  > }
  > for module in ip_gre ppa_drv_stack_al lgm_pp_hal_drv ppa_api; do
  >   require_module "$module"
  > done
  > ppa_sessions=/sys/kernel/debug/ppa/core/uc_session
  > cat "$ppa_sessions" >/dev/null 2>&1 || fail "debugfs endpoint $ppa_sessions is not readable"
  > echo "debugfs $ppa_sessions: readable"
  > ppacmd_help="$(ppacmd control --help 2>&1)" || true
  > for control in --enable-lan --disable-lan --enable-wan --disable-wan; do
  >   printf "%s\n" "$ppacmd_help" | grep -q -- "$control" || fail "ppacmd control --help does not expose $control"
  > done
  > echo "ppacmd LAN/WAN acceleration controls: available"
  > ' < /dev/null
  module ip_gre: loaded
  module ppa_drv_stack_al: loaded
  module lgm_pp_hal_drv: loaded
  module ppa_api: loaded
  debugfs /sys/kernel/debug/ppa/core/uc_session: readable
  ppacmd LAN/WAN acceleration controls: available
