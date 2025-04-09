Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check InterfaceNumberOfEntries:

  $ nb_intf=$(R "ba-cli 'Device.Ethernet.InterfaceNumberOfEntries?' | grep '=' | sed 's/.*=//'")
  $ echo "$nb_intf"
  [1-9]+ (re)

Check Energy Efficiency Ethernet (EEE) support in Ethernet datamodel:

  $ if [ "$nb_intf" -gt 0 ]; then
  >  R "ba-cli 'Ethernet.Interface."$nb_intf"._list()' | grep 'EEE' | sed 's/[\", ]//g'"
  > fi
  EEECapability
  EEEEnable
  EEEStatus

Check Energy Detect Power Down (EDPD) support in Ethernet datamodel:

  $ if [ "$nb_intf" -gt 0 ]; then
  >  R "ba-cli 'Ethernet.Interface."$nb_intf"._list()' | grep 'EDPD' | sed 's/[\", ]//g'"
  > fi
  EDPDCapability
  EDPDEnable
  EDPDStatus
