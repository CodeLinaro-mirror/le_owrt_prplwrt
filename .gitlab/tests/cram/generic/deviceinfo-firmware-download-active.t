Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Run the test only on OSPv2 and Freedom boards:

  $ [ "$DUT_BOARD" = "mxl25641-hdk-6" ] || [ "$DUT_BOARD" = "wnc-freedom" ] || exit 80

Pick the active bank:

  $ ACTIVE=$(R "ba-cli -l 'DeviceInfo.ActiveFirmwareImage?'" | grep -oE '[0-9]+' | head -1)
  $ test -n "$ACTIVE" || exit 1

Download on the active bank with AutoActivate=false is rejected:

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$ACTIVE.Download(URL=\"http://127.0.0.1:1/x.swu\",AutoActivate=false)'" 2>&1
  *DeviceInfo.FirmwareImage.*.Download(URL="http://127.0.0.1:1/x.swu",AutoActivate=false) (glob)
  ERROR: call (null) failed with status 18 - invalid argument
  DeviceInfo.FirmwareImage.*.Download() returned (glob)
  [
      ""
  ]
  $ R "ba-cli 'DeviceInfo.ActiveFirmwareImage?'" | grep -oE "FirmwareImage.$ACTIVE\"" | wc -l | tr -d ' '
  1

Download on the active bank with AutoActivate=true is not supported:

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$ACTIVE.Download(URL=\"http://127.0.0.1:1/x.swu\",AutoActivate=true)'" 2>&1
  *DeviceInfo.FirmwareImage.*.Download(URL="http://127.0.0.1:1/x.swu",AutoActivate=true) (glob)
  ERROR: call (null) failed with status 24 - not supported
  DeviceInfo.FirmwareImage.*.Download() returned (glob)
  [
      * (glob)
  ]
  $ R "ba-cli 'DeviceInfo.ActiveFirmwareImage?'" | grep -oE "FirmwareImage.$ACTIVE\"" | wc -l | tr -d ' '
  1