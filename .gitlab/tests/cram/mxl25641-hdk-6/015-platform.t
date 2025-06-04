Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that Quectel RM520N-GL is available on PCI bus and uses correct mhi-pci-generic kernel driver:

  $ R lspci -v -d 17cb:0308
  0005:01:00.0 Unassigned class [ff00]: Qualcomm Technologies, Inc Device 0308
  lspci: Unable to load libkmod resources: error -2
  \tSubsystem: Qualcomm Technologies, Inc Device 0308 (esc)
  \tFlags: bus master, fast devsel, latency 0, IRQ 362 (esc)
  \tMemory at c8000000 (64-bit, non-prefetchable) [size=4K] (esc)
  \tMemory at c8001000 (64-bit, non-prefetchable) [size=4K] (esc)
  \tCapabilities: [40] Power Management version 3 (esc)
  \tCapabilities: [50] MSI: Enable+ Count=1/32 Maskable+ 64bit+ (esc)
  \tCapabilities: [70] Express Endpoint, MSI 00 (esc)
  \tCapabilities: [100] Advanced Error Reporting (esc)
  \tCapabilities: [148] Secondary PCI Express (esc)
  \tCapabilities: [168] Physical Layer 16.0 GT/s <?> (esc)
  \tCapabilities: [18c] Lane Margining at the Receiver <?> (esc)
  \tCapabilities: [19c] Transaction Processing Hints (esc)
  \tCapabilities: [228] Latency Tolerance Reporting (esc)
  \tCapabilities: [230] L1 PM Substates (esc)
  \tCapabilities: [240] Data Link Feature <?> (esc)
  \tKernel driver in use: mhi-pci-generic (esc)
  
Check that there is SFP+ stick present:

  $ R 'ba-cli --less --json SFPs.Cage.1.SFP.Transceiver.?' | jq -r '.[0]."SFPs.Cage.1.SFP.Transceiver." | [.VendorSN, .VendorPN, .TransceiverType, .VendorName] | sort | .[]'
  10G Base-SR
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

Check that CONFIG_WATCHDOG_SYSFS is enabled and thus watchdog available to reboot-service for reboot reasons:

  $ R "cat /sys/class/watchdog/watchdog*/timeout"
  30
