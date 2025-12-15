Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Enable DHCPv4/DHCPv6 entry:

  $ R "ba-cli ConMon.Entry.cpe-wan.Enable = 1" > /dev/null;
  $ R "ba-cli ConMon.Entry.cpe-wan6.Enable = 1" > /dev/null;
  $ sleep 5

Check that DHCPv4 entry Status is Enabled and number of failures is 0:

  $ R "ba-cli -j -l ConMon.Entry.cpe-wan.? | jsonfilter -e @[0]'[*].Status' -e @[0]'[*].ARPNSErrorsSent' -e @[0]'[*].ARPNSTotalFail' -e @[0]'[*].TotalDHCPRestarts' | sort"
  0
  0
  0
  Enabled
