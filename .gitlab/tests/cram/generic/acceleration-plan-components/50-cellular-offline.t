Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Skip when the DUT has no cellular modem fitted:

  $ [ "${DUT_HAS_MODEM:-1}" = "1" ] || exit 80

Make sure Cellular is registered in the Datamodel:

  $ R "ba-cli -ajl Cellular.?1"| jq -r '.[0] | keys[0]'
  Cellular.

Make sure a Modem is found:

  $ R "mmcli -L | head -n 1"
  .*\/org\/freedesktop\/ModemManager[0-9]\/Modem\/[0-9]+.+ (re)

Check datamodel parameters that should be set when no SIM is detected:

  $ R "ubus-cli -al Cellular.AccessPoint.1.Interface? | awk NF"
  Device.Cellular.Interface.1.

  $ R "ubus-cli -al Cellular.Interface.1.LowerLayers? | awk NF"

  $ R "echo protected\; Cellular.Interface.1.InternalName? | xargs ba-cli -al | grep -v '> ' | awk NF"
  .*\/org\/freedesktop\/ModemManager[0-9]\/Modem\/[0-9]+ (re)
