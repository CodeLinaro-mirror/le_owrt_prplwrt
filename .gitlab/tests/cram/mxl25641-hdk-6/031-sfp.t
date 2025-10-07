Create R alias:
  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check the SFPs datamodel is available when the plugin is installed:
  $ if ! R "which tr181-sfp"; then exit 80; fi
  /usr/bin/tr181-sfp
  $ R "ubus -S call SFPs _get"
  {"SFPs.":{"SFPsController":".*","SupportedControllers":".*","SFPCageNumberOfEntries":\d+,"SFPDatabaseNumberOfEntries":\d+}} (re)
  {}
  {"amxd-error-code":0}

Check the supported sfp types are filled in:
  $ R "ba-cli 'ubus-protected;Ethernet.Interface.[SFPReferenceList==\"SFPs.SFPCage.1\"].?' | grep SFPSupportedType"
  Ethernet.Interface.?\d+.SFPSupportedType=\".+\" (re)
