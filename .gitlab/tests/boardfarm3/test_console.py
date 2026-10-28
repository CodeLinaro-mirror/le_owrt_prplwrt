# SPDX-FileCopyrightText: 2026 prpl Foundation
"""Commands on the boardfarm3 serial console of the board.

The checks are those of the cram test generic/busybox.t.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

import pytest
from boardfarm3_prplos.devices.prplos_board import PrplOSBoard

if TYPE_CHECKING:
    from boardfarm3.lib.device_manager import DeviceManager


@pytest.fixture(scope="module")
def board(device_manager: DeviceManager) -> PrplOSBoard:
    """Return the board of the run."""
    return device_manager.get_device_by_type(PrplOSBoard)


def _run(board: PrplOSBoard, command: str) -> tuple[str, int]:
    output = board.console.execute_command(f"{command}; echo rc=$?")
    lines = [line.strip() for line in output.strip().splitlines()]
    status = lines.pop()
    return "\n".join(lines), int(status.removeprefix("rc="))


def test_ntpd_is_not_running(board: PrplOSBoard) -> None:
    """pgrep finds no ntpd process: no output, exit code 1."""
    assert _run(board, "pgrep -ax ntpd") == ("", 1)


def test_sleep_accepts_a_fraction(board: PrplOSBoard) -> None:
    """busybox sleep accepts a fraction of a second: no output, exit code 0."""
    assert _run(board, "sleep .05") == ("", 0)
