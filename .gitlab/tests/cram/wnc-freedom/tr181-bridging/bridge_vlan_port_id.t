Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Add a VLAN with unique ID:

  $ R ba-cli Bridging.Bridge.lan.VLAN.+{VLANID=100, Enable=1}? | grep -Ev '^(>|$)'
  Bridging.Bridge.1.VLAN.1.
  Bridging.Bridge.1.VLAN.1.Alias="cpe-VLAN-1"

Add a VLAN with duplicate ID:

  $ R "ba-cli 'Bridging.Bridge.lan.VLAN.+{VLANID=100, Enable=1}?'" | grep -Ev '^(>|$)'
  ERROR: add Bridging.Bridge.lan.VLAN. failed (13 - duplicate)

Cleanup:

  $ R "ba-cli Bridging.Bridge.lan.VLAN.[VLANID==100].-" | grep -Ev '^(>|$)'
  Bridging.Bridge.1.VLAN.1.
