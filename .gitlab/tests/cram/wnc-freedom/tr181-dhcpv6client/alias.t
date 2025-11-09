Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"


Check Alias with maximal range:

  $ R "ba-cli Device.DHCPv6.Client.1.Alias=$(yes b | tr -d '\n' | head -c 64)" | grep -v '^>'
  Device.DHCPv6.Client.1.
  Device.DHCPv6.Client.1.Alias="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  

Check Alias with range overflow:

  $ R "ba-cli Device.DHCPv6.Client.1.Alias=$(yes b | tr -d '\n' | head -c 65)" | grep -v '^>'
  ERROR: set Device.DHCPv6.Client.1.Alias failed (10 - invalid value)
  

