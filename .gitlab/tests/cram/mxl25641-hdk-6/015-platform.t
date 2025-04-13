Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

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