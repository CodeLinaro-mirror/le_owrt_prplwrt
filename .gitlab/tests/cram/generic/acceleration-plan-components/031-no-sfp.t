Create R alias:
  $ alias R="${CRAM_REMOTE_COMMAND:-}"
Check the SFPs datamodel is available when the plugin is installed:
  $ [ "$DUT_BOARD" = "mxl25641-hdk-6" ] && exit 80 
  [1]
  $ if ! R "which tr181-sfp"; then exit 80; fi
  /usr/bin/tr181-sfp
  $ R "ubus -S call SFPs _get"
  {"SFPs.":{"SFPsController":".*","SupportedControllers":".*","SFPCageNumberOfEntries":\d+,"SFPDatabaseNumberOfEntries":\d+}} (re)
  {}
  {"amxd-error-code":0}
