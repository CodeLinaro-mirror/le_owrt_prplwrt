Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Run the test only on OSPv2 and Freedom boards:

  $ [ "$DUT_BOARD" = "mxl25641-hdk-6" ] || [ "$DUT_BOARD" = "wnc-freedom" ] || exit 80

Pick the active bank:

  $ ACTIVE=$(R "ba-cli -l 'DeviceInfo.ActiveFirmwareImage?'" | grep -oE '[0-9]+' | head -1)
  $ test -n "$ACTIVE" || exit 1

Activating the bank that is both currently active and the configured
BootFirmwareImage is rejected outright - the active/booted image is
unchanged (no switch, and no failure is marked since the rejection
happens during validation, before anything is touched):

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$ACTIVE.Activate(Start=0,End=10,Mode=\"Immediately\")'" 2>&1
  *DeviceInfo.FirmwareImage.*.Activate(Start=0,End=10,Mode="Immediately") (glob)
  ERROR: call (null) failed with status 11 - invalid action
  DeviceInfo.FirmwareImage.*.Activate() returned (glob)
  [
      ""
  ]
  $ R "ba-cli 'DeviceInfo.ActiveFirmwareImage?'" | grep -oE "FirmwareImage.$ACTIVE\"" | wc -l | tr -d ' '
  1
  $ R "ba-cli 'DeviceInfo.FirmwareImage.$ACTIVE.Status?'"
  *DeviceInfo.FirmwareImage.*.Status? (glob)
  DeviceInfo.FirmwareImage.*.Status="Active" (glob)