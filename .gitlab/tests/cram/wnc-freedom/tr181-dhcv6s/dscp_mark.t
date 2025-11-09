
Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check DSCPMark value:
  $ R "ba-cli Device.DHCPv6.Server.Pool.1.DSCPMark?" | grep -v '^>'
  Device.DHCPv6.Server.Pool.1.DSCPMark=48
  

