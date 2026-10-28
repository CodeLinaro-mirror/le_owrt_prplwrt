# SPDX-FileCopyrightText: 2026 prpl Foundation
# SPDX-License-Identifier: GPL-2.0-only
"""Fixtures of the boardfarm3 tests.

The tests reach the board only through the use cases of the
boardfarm3-prplos plugin. When a test fails, the board dumps its system
state and recovers SSH before boardfarm3 powers it off.

In a CI job, a session fixture runs the steps of the labgrid DUT
lifecycle that are prplOS CI policy (.gitlab/scripts/boardfarm3-dut-glue.sh)
while the board is up. The cram suites run after the other tests, and
the obuspa test runs after them.
"""

from __future__ import annotations

import logging
import os
import subprocess
from pathlib import Path
from typing import TYPE_CHECKING

import pytest
from boardfarm3_prplos.use_cases.device_getters import get_board
from boardfarm3_prplos.use_cases.system import ensure_ssh_access, mark_board_failed

if TYPE_CHECKING:
    from collections.abc import Generator

    from boardfarm3_prplos.templates.prplos_cpe import PrplOSCPE

_LOGGER = logging.getLogger(__name__)
_GLUE = Path(__file__).resolve().parents[2] / "scripts" / "boardfarm3-dut-glue.sh"
# Modules that run after all others, in this order. The cram suites run
# generic/obuspa-1905.t, which must run before any obuspa restart, and
# test_obuspa.py restarts obuspa, as its cram original obuspa.t does.
_LAST_MODULES = ("test_cram_suites.py", "test_obuspa.py")

_failed_tests: list[str] = []


def pytest_collection_modifyitems(items: list[pytest.Item]) -> None:
    """Run the cram suites, then the obuspa test, after all other tests."""
    items.sort(
        key=lambda item: (
            _LAST_MODULES.index(item.path.name) + 1
            if item.path.name in _LAST_MODULES
            else 0
        )
    )


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


@pytest.fixture(scope="session", autouse=True)
def _ci_glue(board: PrplOSCPE) -> Generator[None]:
    """Run the CI steps before the first test and after the last one.

    After the tests, SSH is recovered when it does not answer, as the
    labgrid job does before it collects the logs. Outside a CI job the
    fixture does nothing.
    """
    if os.environ.get("CI") != "true":
        yield
        return
    subprocess.run([_GLUE, "ready"], check=True)  # noqa: S603
    yield
    subprocess.run([_GLUE, "finished"], check=False)  # noqa: S603
    if not ensure_ssh_access(board):
        _LOGGER.error("SSH to the board does not answer after the recovery")
    subprocess.run([_GLUE, "collect"], check=False)  # noqa: S603
