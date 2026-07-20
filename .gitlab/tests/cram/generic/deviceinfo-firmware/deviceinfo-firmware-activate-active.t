Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Run the test only on OSPv2 and Freedom boards:

  $ [ "$DUT_BOARD" = "mxl25641-hdk-6" ] || [ "$DUT_BOARD" = "wnc-freedom" ] || exit 80

Pick the active bank:

  $ ACTIVE=$(R "ba-cli -l 'DeviceInfo.ActiveFirmwareImage?'" | grep -oE '[0-9]+' | head -1)
  $ test -n "$ACTIVE" || exit 1

Activating the already-active bank is not honored as a fresh activation - the
active/booted image is unchanged (no switch):

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$ACTIVE.Activate(Start=0,End=10,Mode=\"Immediately\")'" 2>&1
  *DeviceInfo.FirmwareImage.*.Activate(Start=0,End=10,Mode="Immediately") (glob)
  ERROR: call (null) failed with status 18 - invalid argument
  DeviceInfo.FirmwareImage.*.Activate() returned (glob)
  [
      * (glob)
  ]
  $ R "ba-cli 'DeviceInfo.ActiveFirmwareImage?'" | grep -oE "FirmwareImage.$ACTIVE\"" | wc -l | tr -d ' '
  1

Restore the bank status (the failed self-activation marks the active bank failed):

  $ R "/etc/init.d/deviceinfo-manager restart" > /dev/null 2>&1
  $ for i in $(seq 1 15); do R "ba-cli 'DeviceInfo.FirmwareImage.$ACTIVE.Status?'" | grep -qF '="Active"' && break; sleep 2; done
  $ R "ba-cli 'DeviceInfo.FirmwareImage.$ACTIVE.Status?'"
  *DeviceInfo.FirmwareImage.*.Status? (glob)
  DeviceInfo.FirmwareImage.*.Status="Active" (glob)