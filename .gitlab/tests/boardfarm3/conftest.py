# SPDX-FileCopyrightText: 2026 prpl Foundation
"""Report failed tests to the board.

When a test fails, the board dumps its system state and tries to recover
SSH on its serial console before boardfarm3 powers it off.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

import pytest
from boardfarm3_prplos.devices.prplos_board import PrplOSBoard

if TYPE_CHECKING:
    from collections.abc import Generator

    from boardfarm3.lib.device_manager import DeviceManager

_failed_tests: list[str] = []


@pytest.hookimpl(wrapper=True)
def pytest_runtest_makereport(item: pytest.Item) -> Generator[None, object, object]:
    """Remember each test that fails in its setup or call phase."""
    report = yield
    if report.failed and report.when in ("setup", "call"):  # type: ignore[attr-defined]
        _failed_tests.append(item.nodeid)
    return report


@pytest.fixture(scope="session", autouse=True)
def _report_failed_tests_to_board(device_manager: DeviceManager) -> Generator[None]:
    """After the last test, mark the board failed if a test failed."""
    yield
    if _failed_tests:
        board = device_manager.get_device_by_type(PrplOSBoard)
        board.mark_failed(f"failed tests: {', '.join(_failed_tests)}")
