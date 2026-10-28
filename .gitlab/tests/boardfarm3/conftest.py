# SPDX-FileCopyrightText: 2026 prpl Foundation
# SPDX-License-Identifier: GPL-2.0-only
"""Fixtures of the boardfarm3 tests.

The tests reach the board only through the use cases of the
boardfarm3-prplos plugin. When a test fails, the board dumps its system
state and recovers SSH before boardfarm3 powers it off.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

import pytest
from boardfarm3_prplos.use_cases.device_getters import get_board
from boardfarm3_prplos.use_cases.system import mark_board_failed

if TYPE_CHECKING:
    from collections.abc import Generator

    from boardfarm3_prplos.templates.prplos_cpe import PrplOSCPE

_failed_tests: list[str] = []


@pytest.hookimpl(wrapper=True)
def pytest_runtest_makereport(item: pytest.Item) -> Generator[None, object, object]:
    """Remember each test that fails in its setup or call phase."""
    report = yield
    if report.failed and report.when in ("setup", "call"):  # type: ignore[attr-defined]
        _failed_tests.append(item.nodeid)
    return report


@pytest.fixture(scope="session")
def board() -> PrplOSCPE:
    """Return the prplOS board of the testbed."""
    return get_board()


@pytest.fixture(scope="session", autouse=True)
def _report_failed_tests_to_board() -> Generator[None]:
    """After the last test, mark the board failed if a test failed."""
    yield
    if _failed_tests:
        mark_board_failed(get_board(), f"failed tests: {', '.join(_failed_tests)}")
