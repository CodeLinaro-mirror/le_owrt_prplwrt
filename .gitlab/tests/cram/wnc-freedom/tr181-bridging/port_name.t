Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Add an entry with a unique name:

  $ R ba-cli 'Device.Bridging.Bridge.lan.Port.+{Name="eth100"}' | grep -Ev '^(>|$)'
  Device\.Bridging\.Bridge\.1\.Port\.\d+\. (re)
  Device\.Bridging\.Bridge\.1\.Port\.\d+\.Alias="cpe-Port-\d+" (re)

Add an entry with a duplicate name:

  $ R ba-cli 'Device.Bridging.Bridge.lan.Port.+{Name="eth100"}' | grep -Ev '^(>|$)'
  ERROR: add Device.Bridging.Bridge.lan.Port. failed (13 - duplicate)

Restore:

  $ R "ba-cli 'Device.Bridging.Bridge.lan.Port.[Name==\"eth100\"].-'" | grep -Ev '^(>|$)'
  Device\.Bridging\.Bridge\.1\.Port\.\d+\. (re)
  Device\.Bridging\.Bridge\.1\.Port\.\d+\.Stats\. (re)
