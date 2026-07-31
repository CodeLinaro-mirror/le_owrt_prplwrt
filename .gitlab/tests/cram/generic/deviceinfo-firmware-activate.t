Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Run the test only on OSPv2 and Freedom boards:

  $ [ "$DUT_BOARD" = "mxl25641-hdk-6" ] || [ "$DUT_BOARD" = "wnc-freedom" ] || exit 80

Pick the active and inactive bank:

  $ ACTIVE=$(R "ba-cli -l 'DeviceInfo.ActiveFirmwareImage?'" | grep -oE '[0-9]+' | head -1)
  $ INACTIVE=$(R "ba-cli 'DeviceInfo.FirmwareImage.*.Status?'" | grep -oE 'FirmwareImage\.[0-9]+' | grep -oE '[0-9]+' | sort -u | grep -v "^$ACTIVE\$" | head -1)
  $ test -n "$ACTIVE" || exit 1
  $ test -n "$INACTIVE" || exit 1

A failed Download() no longer sticks at DownloadFailed/Available=0 - it
reconciles Status/Available from the controller, which on this board still
has valid firmware in the inactive bank. So the unavailable-bank precondition
below is forced directly in the data model instead of via a real Download():

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$INACTIVE.Status=\"DownloadFailed\"'" > /dev/null
  $ R "ba-cli 'DeviceInfo.FirmwareImage.$INACTIVE.Available=0'" > /dev/null

Activating an unavailable bank is rejected and does not activate it:

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$INACTIVE.Activate(Start=0,End=10,Mode=\"Immediately\")'" 2>&1
  *DeviceInfo.FirmwareImage.*.Activate(Start=0,End=10,Mode="Immediately") (glob)
  ERROR: call (null) failed with status 1 - unknown error
  DeviceInfo.FirmwareImage.*.Activate() returned (glob)
  [
      ""
  ]
  $ R "ba-cli 'DeviceInfo.FirmwareImage.$INACTIVE.Status?'"
  *DeviceInfo.FirmwareImage.*.Status? (glob)
  DeviceInfo.FirmwareImage.*.Status="DownloadFailed" (glob)
  $ R "ba-cli 'DeviceInfo.ActiveFirmwareImage?'" | grep -oE "FirmwareImage.$ACTIVE\"" | wc -l | tr -d ' '
  1

Pointing BootFirmwareImage at an unavailable bank is rejected and unchanged:

  $ R "ba-cli 'DeviceInfo.BootFirmwareImage=\"DeviceInfo.FirmwareImage.$INACTIVE\"'" 2>&1
  *DeviceInfo.BootFirmwareImage="DeviceInfo.FirmwareImage.*" (glob)
  ERROR: set DeviceInfo.BootFirmwareImage failed (10 - invalid value)
  $ R "ba-cli 'DeviceInfo.BootFirmwareImage?'" | grep -oE "FirmwareImage.$INACTIVE\"" | wc -l | tr -d ' '
  0
  $ R "ba-cli 'DeviceInfo.ActiveFirmwareImage?'" | grep -oE "FirmwareImage.$ACTIVE\"" | wc -l | tr -d ' '
  1

Restore the inactive bank to its real, reconciled state so the argument-
validation checks below exercise a bank that could otherwise be legitimately
activated, isolating the Mode/Start-End rejection from the unavailable-bank
rejection above:

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$INACTIVE.Available=1'" > /dev/null
  $ R "ba-cli 'DeviceInfo.FirmwareImage.$INACTIVE.Status=\"Available\"'" > /dev/null

Activating with an unsupported Mode is rejected:

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$INACTIVE.Activate(Start=0,End=10,Mode=\"Bogus\")'" 2>&1
  *DeviceInfo.FirmwareImage.*.Activate(Start=0,End=10,Mode="Bogus") (glob)
  ERROR: call (null) failed with status 18 - invalid argument
  DeviceInfo.FirmwareImage.*.Activate() returned (glob)
  [
      ""
  ]
  $ R "ba-cli 'DeviceInfo.FirmwareImage.$INACTIVE.Status?'"
  *DeviceInfo.FirmwareImage.*.Status? (glob)
  DeviceInfo.FirmwareImage.*.Status="Available" (glob)
  $ R "ba-cli 'DeviceInfo.ActiveFirmwareImage?'" | grep -oE "FirmwareImage.$ACTIVE\"" | wc -l | tr -d ' '
  1

Activating with Start not less than End is rejected:

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$INACTIVE.Activate(Start=100,End=10,Mode=\"Immediately\")'" 2>&1
  *DeviceInfo.FirmwareImage.*.Activate(Start=100,End=10,Mode="Immediately") (glob)
  ERROR: call (null) failed with status 18 - invalid argument
  DeviceInfo.FirmwareImage.*.Activate() returned (glob)
  [
      ""
  ]
  $ R "ba-cli 'DeviceInfo.FirmwareImage.$INACTIVE.Status?'"
  *DeviceInfo.FirmwareImage.*.Status? (glob)
  DeviceInfo.FirmwareImage.*.Status="Available" (glob)
  $ R "ba-cli 'DeviceInfo.ActiveFirmwareImage?'" | grep -oE "FirmwareImage.$ACTIVE\"" | wc -l | tr -d ' '
  1

Disabling the active bank (Available=false) is rejected and stays true:

  $ R "ba-cli 'DeviceInfo.FirmwareImage.$ACTIVE.Available=false'" 2>&1
  *DeviceInfo.FirmwareImage.*.Available=false (glob)
  ERROR: set DeviceInfo.FirmwareImage.*.Available failed (10 - invalid value) (glob)
  $ R "ba-cli 'DeviceInfo.FirmwareImage.$ACTIVE.Available?'"
  *DeviceInfo.FirmwareImage.*.Available? (glob)
  DeviceInfo.FirmwareImage.*.Available=1 (glob)