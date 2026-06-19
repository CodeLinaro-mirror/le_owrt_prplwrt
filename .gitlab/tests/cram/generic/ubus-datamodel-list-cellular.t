Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

If test is running on a Mozart, Turris, OSPv1 or Haze, lets skip the test as there is no Cellular support:
  $ if echo "$CI_JOB_NAME" | grep -q -E "(Mozart|Turris|Haze|HDK-3)"; then exit 80; fi

Check that ubus has expected Cellular datamodels available:

  $ R "ba-cli 'dump -r Cellular.' | cut -b 34- | grep -v '\.[[:digit:]]'; ba-cli 'dump -r Device.' | cut -b 34- | grep 'Device\.Cellular' | grep -v '\.[[:digit:]]'"
  Cellular.
  Cellular.AccessPoint.
  Cellular.Interface.
  Cellular.Interface.Bearer.IPv4.
  Cellular.Interface.Bearer.IPv6.
  Cellular.Interface.Stats.
  Device.Cellular.
