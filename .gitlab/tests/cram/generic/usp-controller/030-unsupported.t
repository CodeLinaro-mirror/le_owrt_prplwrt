SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation

USP features that the DUT agent does not support. Each case has a name and
checks the error that the agent gives today. When the agent gets the feature,
this test fails and the case moves to the test of its message:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/usp-controller.sh"

Reference list index "#": the agent follows a reference with "+" (see
020-get.t), but it does not know "#", which selects one entry of a list of
references. It gives error 7026:

  $ testbed-qemu usp get 'Device.IP.Interface.[Alias=="lan"].LowerLayers'
  Device.IP.Interface.3.LowerLayers="Device.Ethernet.Link.4"
  $ testbed-qemu usp get 'Device.IP.Interface.[Alias=="lan"].LowerLayers#1+.Name'
  error: 7026 Device.IP.Interface.[Alias=="lan"].LowerLayers#1+.Name: DM_PRIV_GetNodeFromPath: Path is invalid: Device.IP.Interface.3.LowerLayers#1
  [1]

Set without allow_partial across more than one USP service: see
022-set-across-services.t (error 7005).
