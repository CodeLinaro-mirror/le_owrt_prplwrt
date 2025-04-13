Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that we've WPS gpio key available:

  $ R "cat /sys/firmware/devicetree/base/keys/wps-button/label"
  wps\x00 (no-eol) (esc)

  $ R "hexdump -s2 -n2 -e '1/1 \"0x%02x \"' /sys/firmware/devicetree/base/keys/wps-button/linux,code"
  0x02 0x11  (no-eol)

Check that we've Reset gpio key available:

  $ R "cat /sys/firmware/devicetree/base/keys/reset-button/label"
  reset\x00 (no-eol) (esc)

  $ R "hexdump -s2 -n2 -e '1/1 \"0x%02x \"' /sys/firmware/devicetree/base/keys/reset-button/linux,code"
  0x01 0x98  (no-eol)
