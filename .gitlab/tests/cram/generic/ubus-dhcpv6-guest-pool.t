SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation
The guest bridge has only Wi-Fi ports, and dhcpv6s-manager enables a pool
once its interface has a link-local address. The simulated radios of the QEMU
testbed never get a channel, so br-guest has no carrier there and whether it
holds a link-local address differs from boot to boot:

  $ if [ "$DUT_BOARD" = "qemu-x86-64" ]; then exit 80; fi

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that the guest DHCPv6 pool is enabled:

  $ R "ubus call DHCPv6Server.Pool _get \"{'rel_path':''}\"" | jq -r '.[] | objects | select(.Alias == "guest") | "\(.Alias) \(.Status)"'
  guest Enabled
