Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check default value:

  $ R ba-cli Bridging.Bridge.lan.STP.BridgePriority? | grep -Ev '^(>|$)'
  Bridging.Bridge.1.STP.BridgePriority=32768

Try to set a negative value:

  $ R ba-cli Bridging.Bridge.lan.STP.BridgePriority=-1 | grep -Ev '^(>|$)'
  ERROR: set Bridging.Bridge.lan.STP.BridgePriority failed (10 - invalid value)

Try to set a value bigger than allowed:

  $ R ba-cli Bridging.Bridge.lan.STP.BridgePriority=61441 | grep -Ev '^(>|$)'
  ERROR: set Bridging.Bridge.lan.STP.BridgePriority failed (10 - invalid value)

Try to set the maximal allowed value:

  $ R ba-cli Bridging.Bridge.lan.STP.BridgePriority=61440 | grep -Ev '^(>|$)'
  Bridging.Bridge.1.STP.
  Bridging.Bridge.1.STP.BridgePriority=61440

Restore:

  $ R ba-cli Bridging.Bridge.lan.STP.BridgePriority=32768 | grep -Ev '^(>|$)'
  Bridging.Bridge.1.STP.
  Bridging.Bridge.1.STP.BridgePriority=32768
