Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

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
  intf=lan1 => alias=lan1
  intf=lan2 => alias=lan2
  intf=lan3 => alias=lan3
  intf=lan4 => alias=lan4
  intf=wan => alias=wan

Check that ethernet-manager configuration contains expected CPE aliases based on DTS aliases:

  $ R "ba-cli -j -l Ethernet.Interface.*.Alias?" | jq -r '.[0] | to_entries[] | .value.Alias' | LC_ALL=C sort
  cpe-lan1
  cpe-lan2
  cpe-lan3
  cpe-lan4
  cpe-wan

Check that we've WPS gpio key available:

  $ R "cat /sys/firmware/devicetree/base/soc@0/gpio_keys/button@1/label"
  wps\x00 (no-eol) (esc)

  $ R "hexdump -s2 -n2 -e '1/1 \"0x%02x \"' /sys/firmware/devicetree/base/soc@0/gpio_keys/button@1/linux,code"
  0x02 0x11  (no-eol)

Check that we've Reset gpio key available:

  $ R "cat /sys/firmware/devicetree/base/soc@0/gpio_keys/button@2/label"
  reset\x00 (no-eol) (esc)

  $ R "hexdump -s2 -n2 -e '1/1 \"0x%02x \"' /sys/firmware/devicetree/base/soc@0/gpio_keys/button@2/linux,code"
  0x01 0x98  (no-eol)
