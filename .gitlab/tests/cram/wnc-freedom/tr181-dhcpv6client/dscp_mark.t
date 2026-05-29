Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check DSCPMark value:

  $ R "ba-cli Device.DHCPv6.Client.1.DSCPMark?" | grep -Ev '^(>|$)'
  Device.DHCPv6.Client.1.DSCPMark=48

