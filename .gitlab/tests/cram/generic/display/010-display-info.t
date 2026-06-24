Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Run the tests only on OSPv2 board with display capability:

  $ [ "$DUT_BOARD" = "mxl25641-hdk-6" ] || exit 80
  $ R "[ -e /etc/init.d/tr181-display ]" || exit 80

Get display information:

  $ R "ba-cli "Display.?" | grep -v \>"
  Display.
  Display.ScreenNumberOfEntries=1
  Display.SessionNumberOfEntries=0
  Display.Screen.1.
  Display.Screen.1.Alias="SPI-1"
  Display.Screen.1.Height=240
  Display.Screen.1.PhysicalHeight=36
  Display.Screen.1.PhysicalWidth=49
  Display.Screen.1.PixelFormat=875713112
  Display.Screen.1.PosX=0
  Display.Screen.1.PosY=0
  Display.Screen.1.RefreshDuration=66666666
  Display.Screen.1.Type="LCD"
  Display.Screen.1.Width=320
