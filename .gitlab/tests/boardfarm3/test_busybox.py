# SPDX-FileCopyrightText: 2026 prpl Foundation
# SPDX-License-Identifier: GPL-2.0-only
"""busybox applets on the board.

The checks are those of the cram test generic/busybox.t.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from boardfarm3_prplos.use_cases.shell import run_command

if TYPE_CHECKING:
    from boardfarm3_prplos.templates.prplos_cpe import PrplOSCPE


def test_sysntpd_is_not_running(board: PrplOSCPE) -> None:
    """pgrep finds no ntpd process: no output, exit code 1."""
    result = run_command(board, "pgrep -ax ntpd")
    assert result.output == ""
    assert result.exit_code == 1


def test_sleep_supports_a_float_duration(board: PrplOSCPE) -> None:
    """sleep accepts a fraction of a second: no output, exit code 0."""
    result = run_command(board, "sleep .05")
    assert result.output == ""
    assert result.exit_code == 0
