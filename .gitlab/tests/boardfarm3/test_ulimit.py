# SPDX-FileCopyrightText: 2026 prpl Foundation
# SPDX-License-Identifier: GPL-2.0-only
"""No process has an unlimited core file size.

The check is that of the cram test generic/ulimit.t: after the same
allow-list filter, no line is left.
"""

from __future__ import annotations

import os
import re
from typing import TYPE_CHECKING

import pytest
from boardfarm3_prplos.use_cases.system import list_unlimited_core_processes

if TYPE_CHECKING:
    from boardfarm3_prplos.templates.prplos_cpe import PrplOSCPE

# grep -v -E '(netifd|udhcpc|wait_for|hostapd|wpa_supplicant)'
_ALLOWED = re.compile(r"(netifd|udhcpc|wait_for|hostapd|wpa_supplicant)")


def test_no_unlimited_core_file_size(board: PrplOSCPE) -> None:
    """No process outside the allow-list has an unlimited core file size."""
    if not os.environ.get("CI_COMMIT_TAG") and os.environ.get(
        "CI_DESIGNATED_BRANCH", ""
    ) != os.environ.get("CI_COMMIT_BRANCH", ""):
        pytest.skip("coredumps are enabled in the CI build")
    lines = list_unlimited_core_processes(board)
    assert [line for line in lines if not _ALLOWED.search(line)] == []
