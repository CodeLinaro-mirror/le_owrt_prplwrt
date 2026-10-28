# SPDX-FileCopyrightText: 2026 prpl Foundation
# SPDX-License-Identifier: GPL-2.0-only
"""The cram suites of the job, unchanged, over SSH.

The suites are those of the labgrid testbed jobs: CRAM_TEST_SUITE, which
the job resolves from components.yml for its COMPONENT, with
CRAM_TEST_SUITE_EXTRA, then CRAM_TEST_SUITE_POST. The command lines and
the result files are those of .gitlab/testbed.yml, so the results can be
compared with the labgrid baseline. In the session they run after the
five other boardfarm3 tests and before the obuspa test, which restarts
obuspa: generic/obuspa-1905.t must run before any obuspa restart.
boardfarm3 powers the board off when the session ends.
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import TYPE_CHECKING

from boardfarm3_prplos.use_cases.cram import run_cram_suite

if TYPE_CHECKING:
    from boardfarm3_prplos.templates.prplos_cpe import PrplOSCPE


def _paths(*variables: str) -> list[Path]:
    return [
        Path(path) for name in variables for path in os.environ.get(name, "").split()
    ]


def test_cram_suite(board: PrplOSCPE) -> None:  # noqa: ARG001
    """The cram suite of the job passes."""
    target = os.environ["LABGRID_TARGET"]
    exit_code = run_cram_suite(
        _paths("CRAM_TEST_SUITE", "CRAM_TEST_SUITE_EXTRA"),
        Path(f"cram-result-{target}.xunit.xml"),
        timeout=float(os.environ["TEST_CUTOFF_TIMEOUT"]),
        env=os.environ,
        output_file=Path(f"cram-result-{target}.txt"),
    )
    assert exit_code == 0


def test_cram_post_suite(board: PrplOSCPE) -> None:  # noqa: ARG001
    """The cram post suite of the job passes."""
    target = os.environ["LABGRID_TARGET"]
    exit_code = run_cram_suite(
        _paths("CRAM_TEST_SUITE_POST"),
        Path(f"cram-result-post-{target}.xunit.xml"),
        timeout=None,
        env=os.environ,
        output_file=Path(f"cram-result-{target}.txt"),
    )
    assert exit_code == 0
