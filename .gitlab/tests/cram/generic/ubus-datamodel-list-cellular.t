Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

If test is running on a Mozart, Turris, OSPv1 or Haze, lets skip the test as there is no Cellular support:
  $ if echo "$CI_JOB_NAME" | grep -q -E "(Mozart|Turris|Haze|HDK-3)"; then exit 80; fi

Check that ubus has expected Cellular datamodels available:

  $ R "ubus list | grep -e '^Cellular' -e 'Device.Cellular' |  grep -v -e '\.[[:digit:]]'"
  Cellular
  Cellular.AccessPoint
  Cellular.Interface
  Cellular.Interface.Bearer.IPv4
  Cellular.Interface.Bearer.IPv6
  Cellular.Interface.Stats
  Device.Cellular
