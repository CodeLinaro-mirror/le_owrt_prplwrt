Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Run the test only on OSPv2 and Freedom boards:

  $ [ "$DUT_BOARD" = "mxl25641-hdk-6" ] || [ "$DUT_BOARD" = "wnc-freedom" ] || exit 80

Confirm ActiveFirmwareImage value is in valid range:

  $ R 'ba-cli -l Device.DeviceInfo.ActiveFirmwareImage?'
  
  Device.DeviceInfo.FirmwareImage.1