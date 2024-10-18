### Global verification of the LCM agent config ###
Setup the test configuration:
  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check Global Execution Environment and configuration:
  $ DM_API="SoftwareModules.ExecEnv.[${EXEC_ENV_FILTER}].?0"
  $ R "${CLI_JSON} \"${DM_API}\" | jsonfilter -e @[*].*.Status -e @[*].*.Enable | sort"
  1
  Up

Check internal Cthulhu.Config datamodel:
  $ DM_API="Cthulhu.Config.?0"
  $ R "${CLI_JSON} \"${DM_API}\" | jsonfilter -e @[*].*.UseOverlayFS -e @[*].*.DefaultBackend -e @[*].*.ImageLocation | sort"
  /lcm/rlyeh/images
  /usr/lib/cthulhu-lxc/cthulhu-lxc.so
  1
