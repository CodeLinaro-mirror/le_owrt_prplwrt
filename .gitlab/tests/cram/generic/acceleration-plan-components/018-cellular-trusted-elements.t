Skip when the DUT has no cellular modem fitted:

  $ [ "${DUT_HAS_MODEM:-1}" = "1" ] || exit 80

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting with CellularManager setup 018-cellular-trusted-elements.t"

Read the IMSI value using mmcli:

  $ IMSI=$(R "mmcli -m 0 -i any | sed -n 's/.*imsi:[[:space:]]*//p'")

  $ R logger -t cram "Setting IMSI value to: $IMSI"

Verify TrustedElements already available using the IMSI value found:

  $ R "ba-cli -l -j 'TrustedElements.SIM.[IMSI==$IMSI].IMSI?' | sed '/^$/d'"
  \[\{"TrustedElements.SIM.\d+.":\{"IMSI":"\d{15}"\}\}\] (re)

Set the SIM preference list:
  $ R "ba-cli Cellular.Interface.[Name==\'wwan0\'].SIMReferenceList=\'Device.TrustedElements.SIM.1.\' | sed '/^$/d'"
  .+ Cellular.Interface.\[Name=='wwan0'\].SIMReferenceList='Device.TrustedElements.SIM.1.' (re)
  Cellular.Interface.\d+. (re)
  Cellular.Interface.\d+.SIMReferenceList="Device.TrustedElements.SIM.1." (re)

Wait for SIM registration and modem setup:

  $ sleep 30

  $ R logger -t cram "Completed with CellularManager setup 018-cellular-trusted-elements.t"
