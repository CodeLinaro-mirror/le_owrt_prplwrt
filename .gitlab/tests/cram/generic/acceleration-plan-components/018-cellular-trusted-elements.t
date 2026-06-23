Skip on Freedom until PCF-2663 is resolved (5G modem not enumerated on PCIe):

  $ [ "$DUT_BOARD" = "wnc-freedom" ] && exit 80
  [1]

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting with CellularManager setup 018-cellular-trusted-elements.t"

Read the IMSI value using mmcli:

  $ IMSI=$(R "mmcli -m 0 -i any | sed -n 's/.*imsi:[[:space:]]*//p'")

  $ R logger -t cram "Setting IMSI value to: $IMSI"

Add SIM to TrustedElements using the IMSI value found:

  $ R "ba-cli -l -j 'TrustedElements.SIM+{IMSI=$IMSI}' | sed '/^$/d'"
  \{"TrustedElements.SIM.\d+.":\{"IMSI":"\d{15}","Alias":".+"\}\} (re)

Set the SIM preference list:
  $ R "ba-cli Cellular.Interface.[Name==\'wwan0\'].SIMReferenceList=\'Device.TrustedElements.SIM.1.\' | sed '/^$/d'"
  .+ Cellular.Interface.\[Name=='wwan0'\].SIMReferenceList='Device.TrustedElements.SIM.1.' (re)
  Cellular.Interface.\d+. (re)
  Cellular.Interface.\d+.SIMReferenceList="Device.TrustedElements.SIM.1." (re)

Wait for SIM registration and modem setup:

  $ sleep 30

  $ R logger -t cram "Completed with CellularManager setup 018-cellular-trusted-elements.t"
