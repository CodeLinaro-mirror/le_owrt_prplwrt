Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Skip when the firmware has no cellular support:
  $ [ "${DUT_HAS_CELLULAR:-1}" = "1" ] || exit 80

Check that ubus has expected Cellular datamodels available:

  $ R "ubus list | grep -e '^Cellular' -e 'Device.Cellular' -e 'Device.SessionManagement' -e 'Device.TrustedElements' -e '^SessionManagement' -e '^TrustedElements' |  grep -v -e '\.[[:digit:]]'"
  Cellular
  Cellular.AccessPoint
  Cellular.Interface
  Device.Cellular
  Device.SessionManagement
  Device.TrustedElements
  SessionManagement
  SessionManagement.PDN
  SessionManagement.PDP
  SessionManagement.PDU
  SessionManagement.Session
  TrustedElements
  TrustedElements.SIM
