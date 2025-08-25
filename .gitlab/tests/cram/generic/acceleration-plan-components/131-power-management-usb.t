Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check USB.Port datamodel has PowerManagement parameters:

  $ R "ba-cli 'USB.Port.*.PowerStatus?' | sort | grep '=' | head -n1" 
  USB.Port.[0-9]+.PowerStatus=".*" (re)

  $ R "ba-cli 'ubus-protected;USB.Port.*.PowerState?' | sort | grep '=' | head -n1" 
  USB.Port.[0-9]+.PowerState=".*" (re)

  $ R "ba-cli 'USB.Port.*.PowerCapability?' | sort | grep '=' | head -n1" 
  USB.Port.[0-9]+.PowerCapability=".*" (re)

Check read-only parameters:

  $ R "ba-cli 'USB.Port.1.PowerStatus="On"' | sort | grep 'ERROR'"
  ERROR: set USB.Port.1.PowerStatus failed \([0-9]+ - .*read only\) (re)

  $ R "ba-cli 'USB.Port.1.PowerCapability="On,Off"' | sort | grep 'ERROR'"
  ERROR: set USB.Port.1.PowerCapability failed \([0-9]+ - .*read only\) (re)

Check ChangePowerMode function:

  $ alias=$(R "ba-cli 'USB.Port.1.PowerCapability?' | grep -v '>' | grep 'PowerCapability'| sed -E 's/.*PowerCapability=\"([^\"]+)\"/\1/'")
  $ first=${alias%%,*}
  $ R "ba-cli 'USB.Port.1.ChangePowerMode(PowerState = \"$first\")' | grep -v '>'"
  USB.Port.1.ChangePowerMode() returned
  [
      ""
  ]
  

Check invalid value for ChangePowerMode function:

  $ R "ba-cli 'USB.Port.1.ChangePowerMode(PowerState = "InvalidState")' | grep -v '>' | grep 'ERROR'"
  ERROR: call (null) failed with status 1 - unknown error

Check PowerStatus after ChangePowerMode:

  $ status=$(R "ba-cli 'USB.Port.1.PowerStatus?' | grep -v '>' | sed -E 's/.*PowerStatus=\"([^\"]+)\".*/\1/'")

  $ if [ "$status" = "$first" ]; then 
  >   echo "PowerStatus has been updated successfully"
  > fi
  PowerStatus has been updated successfully
