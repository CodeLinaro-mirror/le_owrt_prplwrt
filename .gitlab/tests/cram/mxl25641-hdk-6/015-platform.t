Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that there is SFP+ stick present:

  $ R 'ba-cli --less --json SFPs.Cage.1.SFP.Transceiver.?' | jq -r '.[0]."SFPs.Cage.1.SFP.Transceiver." | [.VendorSN, .VendorPN, .TransceiverType, .VendorName] | sort | .[]'
  10G Base-SR
  F\d+$ (re)
  FS
  SFP-10G-T

Check that expected DTS aliases are provided for ethernet interfaces:

  $ R 'cd /sys/firmware/devicetree/base
  > for eth_label in $(find -name label); do
  >   if [ "$(cat ${eth_path/device_type} 2>/dev/null)" != "network" ]; then
  >     continue
  >   fi
  >   eth_device="${eth_label/\/label/}
  >   eth_intf="$(cat ${eth_label})"
  >   eth_alias="$(cd aliases; grep -l "${eth_device/\./}" $(ls * | grep -v eth | grep -v wan))"
  >   echo "intf=${eth_intf} => alias=${eth_label}"
  > done | LC_ALL=C sort'
  intf=eth0_1 => alias=10g
  intf=eth0_2 => alias=lan3
  intf=eth0_3 => alias=lan2
  intf=eth0_4 => alias=lan1
  intf=eth0_5 => alias=
  intf=eth1 => alias=sfp

Check that ethernet-manager configuration contains expected CPE aliases based on DTS aliases:

  $ R "ba-cli -j -l Ethernet.Interface.*.Alias?" | jq -r '.[0] | to_entries[] | .value.Alias' | LC_ALL=C sort
  cpe-10g
  cpe-lan1
  cpe-lan2
  cpe-lan3
  cpe-sfp

