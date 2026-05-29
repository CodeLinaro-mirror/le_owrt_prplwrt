Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check Ethernet.Interface datamodel has PowerManagement parameters:

  $ R "ba-cli 'Ethernet.Interface.*.PowerStatus?' | sort | grep '=' | head -n1" 
  Ethernet.Interface.[0-9]+.PowerStatus=".*" (re)

  $ R "ba-cli 'ubus-protected;Ethernet.Interface.*.PowerState?' | sort | grep '=' | head -n1" 
  Ethernet.Interface.[0-9]+.PowerState=".*" (re)

  $ R "ba-cli 'Ethernet.Interface.*.PowerCapability?' | sort | grep '=' | head -n1" 
  Ethernet.Interface.[0-9]+.PowerCapability=".*" (re)

Check read-only parameters:

  $ R "ba-cli 'Ethernet.Interface.1.PowerStatus="On"' | sort | grep 'ERROR'"
  ERROR: set Ethernet.Interface.1.PowerStatus failed \([0-9]+ - .*read only\) (re)

  $ R "ba-cli 'Ethernet.Interface.1.PowerCapability="On,Off"' | sort | grep 'ERROR'"
  ERROR: set Ethernet.Interface.1.PowerCapability failed \([0-9]+ - .*read only\) (re)

Check ChangePowerMode function:

  $ alias=$(R "ba-cli 'Ethernet.Interface.1.PowerCapability?' | grep -Ev '^(>|$)' | grep 'PowerCapability'| sed -E 's/.*PowerCapability=\"([^\"]+)\"/\1/'")
  $ first=${alias%%,*}
  $ R "ba-cli 'Ethernet.Interface.1.ChangePowerMode(PowerState = \"$first\")' | grep -Ev '^(>|$)'"
  Ethernet.Interface.1.ChangePowerMode() returned
  [
      ""
  ]

Check invalid value for ChangePowerMode function:

  $ R "ba-cli 'Ethernet.Interface.1.ChangePowerMode(PowerState = "InvalidState")' | grep -Ev '^(>|$)' | grep 'ERROR'"
  ERROR: call (null) failed with status 1 - unknown error

Check PowerStatus after ChangePowerMode:

  $ status=$(R "ba-cli 'Ethernet.Interface.1.PowerStatus?' | grep -Ev '^(>|$)' | sed -E 's/.*PowerStatus=\"([^\"]+)\".*/\1/'")

  $ if [ "$status" = "$first" ]; then 
  >   echo "PowerStatus has been updated successfully"
  > fi
  PowerStatus has been updated successfully
