Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"


Set unexistent interface:

  $ R "ba-cli Device.DHCPv6.Client.1.Interface=Device.IP.Interface.99" | grep -Ev '^(>|$)'
  ERROR: set Device.DHCPv6.Client.1.Interface failed (21 - invalid path)
