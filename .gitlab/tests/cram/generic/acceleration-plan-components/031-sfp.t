Create R alias:
  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check the SFPs datamodel is available:
  $ if ! R "ubus -S call SFPs _get" >/dev/null; then exit 80; fi

  $ R "ubus -S call SFPs _get"
  {"SFPs.":{"SFPsController":".*","SupportedControllers":".*","SFPCageNumberOfEntries":\d+,"SFPDatabaseNumberOfEntries":\d+}} (re)
  {}
  {"amxd-error-code":0}

Check the supported sfp types are filled in:
  $ R "ba-cli 'ubus-protected;Ethernet.Interface.[SFPReferenceList==\"SFPs.SFPCage.1\"].?' | grep SFPSupportedType"
  Ethernet.Interface.?\d+.SFPSupportedType=\".+\" (re)
