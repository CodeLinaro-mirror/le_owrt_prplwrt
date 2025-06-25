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

Enable Cellular AccessPoint (should be enabled by default):

  $ R "ba-cli -ajl 'Cellular.AccessPoint.1.Enable=1' | awk NF"
  [{"Cellular.AccessPoint.1.":{"Enable":1}}]

Enable Cellular Interface (should be enabled by default):

  $ R "ba-cli -ajl 'Cellular.Interface.1.Enable=1' | awk NF"
  [{"Cellular.Interface.1.":{"Enable":1}}]

Check Root Cellular datamodel parameters:

  $ R "echo protected\; Cellular.CellularController? | xargs ba-cli -al | grep -v '> ' | awk NF"
  mod-cellular-libmm

Check AccessPoint datamodel parameters:

  $ R "ba-cli -al Cellular.AccessPoint.1.Interface? | awk NF"
  Device.Cellular.Interface.1.

Check Interface datamodel parameters:

  $ R "ba-cli -al Cellular.Interface.1.LowerLayers? | awk NF"

  $ R "echo protected\; Cellular.Interface.1.InternalName? | xargs ba-cli -al | grep -v '> ' | awk NF"
  .*\/org\/freedesktop\/ModemManager[0-9]\/Modem\/[0-9]+ (re)

  $ R "ba-cli -al Cellular.Interface.1.IMEI? | awk NF"
  [0-9]{15} (re)

  $ R "ba-cli -al Cellular.Interface.1.Status? | awk NF"
  Up

Check Bearer datamodel parameters:

  $ R "echo protected\; Cellular.Interface.1.Bearer.InternalName? | xargs ba-cli -al | grep -v '> ' | awk NF"
  .*\/org\/freedesktop\/ModemManager[0-9]\/Bearer\/[0-9]+ (re)

  $ R "echo protected\; Cellular.Interface.1.Bearer.IPv4.? | xargs ba-cli -ajl | grep -v '> ' | awk NF"| jq -r '.[0] | keys[0]'
  Cellular.Interface.1.Bearer.IPv4.

  $ R "echo protected\; Cellular.Interface.1.Bearer.IPv6.? | xargs ba-cli -ajl | grep -v '> ' | awk NF"| jq -r '.[0] | keys[0]'
  Cellular.Interface.1.Bearer.IPv6.

Check USIM datamodel parameters:

  $ R "ba-cli -al Cellular.Interface.1.USIM.ICCID? | awk NF"
  [0-9]{18,22} (re)

  $ R "ba-cli -al Cellular.Interface.1.USIM.IMSI? | awk NF"
  [0-9]{15} (re)

  $ R "ba-cli -al Cellular.Interface.1.USIM.Status? | awk NF"
  Valid

  $ R "echo protected\; Cellular.Interface.1.USIM.InternalName? | xargs ba-cli -al | grep -v '> ' | awk NF"
  .*\/org\/freedesktop\/ModemManager[0-9]\/SIM\/[0-9]+ (re)
