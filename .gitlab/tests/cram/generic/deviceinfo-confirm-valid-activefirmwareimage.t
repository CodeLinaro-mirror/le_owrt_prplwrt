Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Run the test only on OSPv2 and Freedom boards:

  $ [ "$DUT_BOARD" = "mxl25641-hdk-6" ] || [ "$DUT_BOARD" = "wnc-freedom" ] || exit 80

Confirm ActiveFirmwareImage value is in valid range:

  $ R 'ba-cli -l Device.DeviceInfo.ActiveFirmwareImage?'
  
  Device\.DeviceInfo\.FirmwareImage\.[0-9]+ (re)


  $ ACTIVE="$(R 'ba-cli -l Device.DeviceInfo.ActiveFirmwareImage?' | sed -nE 's#^Device(\.DeviceInfo|Info)\.FirmwareImage\.([0-9]+)\.?$#\2#p' | head -1)"
  $ ENTRIES="$(R 'ba-cli -l Device.DeviceInfo.FirmwareImageNumberOfEntries?' | grep -oE '[0-9]+' | head -1)"
  $ test -n "$ACTIVE" && test -n "$ENTRIES" && test "$ACTIVE" -ge 1 && test "$ACTIVE" -le "$ENTRIES" && echo OK
  OK

Confirm ActiveFirmwareImage refers to the active firmware image:

  $ R "ba-cli -l Device.DeviceInfo.FirmwareImage.$ACTIVE.Status?" | grep -qx 'Active' && echo OK
  OK
