# SPDX-FileCopyrightText: 2026 prpl Foundation
# SPDX-License-Identifier: GPL-2.0-only
"""The bootcount register in /sys/class/registers reads and writes.

The checks are those of the cram test generic/sysregister.t. The output
of each command is compared as a whole, with its newlines. As in the cram
test, the register is set back to 0 at the end, also after a failed check.
"""

from __future__ import annotations

import os
from typing import TYPE_CHECKING

import pytest
from boardfarm3_prplos.use_cases.shell import run_command

if TYPE_CHECKING:
    from boardfarm3_prplos.templates.prplos_cpe import PrplOSCPE

_BOOTCOUNT = "/sys/class/registers/bootcount"


def _check(board: PrplOSCPE, command: str, output: str) -> None:
    result = run_command(board, command)
    assert result.output == output, command
    assert result.exit_code == 0, command


def test_bootcount_register_reads_and_writes(board: PrplOSCPE) -> None:
    """bootcount reads 0, takes 2, reads 2 and is set back to 0."""
    if os.environ.get("DUT_BOARD") not in ("mxl25641-hdk-6", "wnc-freedom"):
        pytest.skip("only on OSPv2 and Freedom boards")
    try:
        _check(board, f"cat {_BOOTCOUNT}", "0\n")
        _check(board, f"echo 2 > {_BOOTCOUNT}", "")
        _check(board, f"cat {_BOOTCOUNT}", "2\n")
    finally:
        _check(board, f"echo 0 > {_BOOTCOUNT}", "")
