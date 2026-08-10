Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Skip when the firmware has no cellular support:
  $ [ "${DUT_HAS_CELLULAR:-1}" = "1" ] || exit 80

Check that ubus has expected Cellular datamodels available:

  $ R "ubus list | grep -e '^Cellular' -e 'Device.Cellular' -e 'Device.SessionManagement' -e 'Device.TrustedElements' -e '^SessionManagement' -e '^TrustedElements' |  grep -v -e '\.[[:digit:]]'"
  Cellular
  Cellular.AccessPoint
  Cellular.Interface
  Cellular.Interface.SMS.Incoming
  Cellular.Interface.SMS.Message
  Cellular.Interface.SMS.Outgoing
  Cellular.Interface.SMS.Storage
  Device.Cellular
  Device.SessionManagement
  Device.TrustedElements
  SessionManagement
  SessionManagement.PDN
  SessionManagement.PDP
  SessionManagement.PDU
  SessionManagement.PDU.NetworkSlice
  SessionManagement.PDU.QoSFlow
  SessionManagement.PDU.QoSRule
  SessionManagement.PDU.QoSRule.Filter
  SessionManagement.Session
  SessionManagement.Session.IPv4Address
  SessionManagement.Session.IPv6Address
  SessionManagement.Session.PCO
  TrustedElements
  TrustedElements.SIM
  TrustedElements.SIM.Profile
