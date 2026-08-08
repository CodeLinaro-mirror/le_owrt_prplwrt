Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Find a USB port that exposes power-management controls:
  $ usb_power_port=$(R "ba-cli 'USB.Port.*.PowerCapability?' | sed -n 's/.*USB.Port\.\([0-9][0-9]*\)\.PowerCapability=.*/\1/p' | head -n1")
  $ if [ -z "$usb_power_port" ]; then exit 80; fi

Check USB.Port datamodel has PowerManagement parameters:

  $ R "ba-cli 'USB.Port.*.PowerStatus?' | sort | grep '=' | head -n1" 
  USB.Port.[0-9]+.PowerStatus=".*" (re)

  $ R "ba-cli 'ubus-protected;USB.Port.*.PowerState?' | sort | grep '=' | head -n1" 
  USB.Port.[0-9]+.PowerState=".*" (re)

  $ R "ba-cli 'USB.Port.*.PowerCapability?' | sort | grep '=' | head -n1" 
  USB.Port.[0-9]+.PowerCapability=".*" (re)

Check read-only parameters:

  $ R "ba-cli 'USB.Port.$usb_power_port.PowerStatus="On"' | sort | grep 'ERROR'"
  ERROR: set USB.Port.[0-9]+.PowerStatus failed \([0-9]+ - .*read only\) (re)

  $ R "ba-cli 'USB.Port.$usb_power_port.PowerCapability="On,Off"' | sort | grep 'ERROR'"
  ERROR: set USB.Port.[0-9]+.PowerCapability failed \([0-9]+ - .*read only\) (re)

Check ChangePowerMode function:

  $ alias=$(R "ba-cli 'USB.Port.$usb_power_port.PowerCapability?' | grep -Ev '^(>|$)' | grep 'PowerCapability'| sed -E 's/.*PowerCapability=\"([^\"]+)\"/\1/'")
  $ first=${alias%%,*}
  $ R "ba-cli 'USB.Port.$usb_power_port.ChangePowerMode(PowerState = \"$first\")' | grep -Ev '^(>|$)'"
  USB.Port.[0-9]+.ChangePowerMode\(\) returned (re)
  [
      ""
  ]

Check invalid value for ChangePowerMode function:

  $ R "ba-cli 'USB.Port.$usb_power_port.ChangePowerMode(PowerState = "InvalidState")' | grep -Ev '^(>|$)' | grep 'ERROR'"
  ERROR: call (null) failed with status 10 - invalid value

Check PowerStatus after ChangePowerMode:

  $ status=$(R "ba-cli 'USB.Port.$usb_power_port.PowerStatus?' | grep -Ev '^(>|$)' | sed -E 's/.*PowerStatus=\"([^\"]+)\".*/\1/'")

  $ if [ "$status" = "$first" ]; then 
  >   echo "PowerStatus has been updated successfully"
  > fi
  PowerStatus has been updated successfully
