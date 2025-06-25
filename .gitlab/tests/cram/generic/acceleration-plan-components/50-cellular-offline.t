Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

If test is running on a Mozart, Turris, OSPv1 or Haze, lets skip the test as there is no USB storage device attached:

  $ if echo "$CI_JOB_NAME" | grep -q -E "(Mozart|Turris|Haze|HDK-3)"; then exit 80; fi

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
