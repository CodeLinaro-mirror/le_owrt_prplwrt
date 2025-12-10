Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check Clients connected

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.[Alias==\"lan\"].?'"
