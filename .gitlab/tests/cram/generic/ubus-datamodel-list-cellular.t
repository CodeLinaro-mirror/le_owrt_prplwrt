Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

If test is running on a Valyrian, Mozart, Turris, OSPv1 or Haze, lets skip the test as there is no Cellular support:
  $ if echo "$CI_JOB_NAME" | grep -q -E "(Valyrian|Mozart|Turris|Haze|HDK-3)"; then exit 80; fi

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
