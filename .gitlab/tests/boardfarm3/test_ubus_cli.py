# SPDX-FileCopyrightText: 2026 prpl Foundation
# SPDX-License-Identifier: GPL-2.0-only
"""DHCP server pools in the data model, read with ubus-cli.

The checks are those of the cram test generic/ubus-cli.t. As there,
ubus-cli runs on a pseudo-terminal, the output is filtered with the same
pattern and sorted, and the exit code is not checked. Each line keeps the
carriage return of the pseudo-terminal, which the cram test expects too.
"""

from __future__ import annotations

import re
from typing import TYPE_CHECKING

from boardfarm3_prplos.use_cases.datamodel import ubus_cli_get

if TYPE_CHECKING:
    from boardfarm3_prplos.templates.prplos_cpe import PrplOSCPE

# grep 'Pool\.[[:digit:]]\.Alias'
_V4_ALIAS = re.compile(r"Pool\.[0-9]\.Alias")


def test_dhcpv4_pools(board: PrplOSCPE) -> None:
    """The DHCPv4 pools are lan, guest and lcm."""
    lines = ubus_cli_get(board, "DHCPv4Server.Pool.*.Alias?")
    assert sorted(line for line in lines if _V4_ALIAS.search(line)) == [
        'DHCPv4Server.Pool.1.Alias="lan"\r',
        'DHCPv4Server.Pool.2.Alias="guest"\r',
        'DHCPv4Server.Pool.3.Alias="lcm"\r',
    ]


def test_dhcpv6_pools(board: PrplOSCPE) -> None:
    """The DHCPv6 pools are lan, guest and lcm."""
    lines = ubus_cli_get(board, "DHCPv6Server.Pool.*.Alias?1")
    assert sorted(line for line in lines if "Alias=" in line) == [
        'DHCPv6Server.Pool.1.Alias="lan"\r',
        'DHCPv6Server.Pool.2.Alias="guest"\r',
        'DHCPv6Server.Pool.3.Alias="lcm"\r',
    ]
