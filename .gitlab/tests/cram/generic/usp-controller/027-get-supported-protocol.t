SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation

USP GetSupportedProtocol from the controller to the DUT agent over MQTT. The
reply gives the USP versions that the agent supports:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ . "${TESTDIR}/usp-controller.sh"

  $ testbed-qemu usp supported-protocol
  1.0,1.1,1.2,1.3
