Setup the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Run the tests only on OSPv2 board (PCF-1209, PCF-1356):

  $ [ "$DUT_BOARD" = "mxl25641-hdk-6" ] || exit 80

Check /lcm is running on expected ext4 filesystem:

  $ R "df -PkT /lcm" | awk '{print $2}'
  Type
  ext4
