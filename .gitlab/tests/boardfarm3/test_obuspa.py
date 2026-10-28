# SPDX-FileCopyrightText: 2026 prpl Foundation
# SPDX-License-Identifier: GPL-2.0-only
"""The obuspa data model stays the same across an obuspa restart.

The checks are those of the cram test generic/obuspa.t and its script
scripts/verify-obuspa-datamodel.sh in the generic mode: a snapshot before
the restart and one 20 s after it must both equal the expected file,
byte for byte, as diff compares them. As there, the dump script is
copied once and removed at the end, the restart and the second snapshot
also run when the first snapshot differs or cannot be taken, and a
failed restart ends the test. A differing snapshot and its diff are
written to the log directory.
"""

from __future__ import annotations

import difflib
import os
import re
import time
from pathlib import Path
from typing import TYPE_CHECKING

import pytest
from boardfarm3_prplos.use_cases.datamodel import (
    obuspa_datamodel_snapshot,
    obuspa_dump_script,
)
from boardfarm3_prplos.use_cases.system import restart_service

if TYPE_CHECKING:
    from boardfarm3_prplos.templates.prplos_cpe import PrplOSCPE

_CRAM = Path(__file__).resolve().parents[1] / "cram"
_DUMP_SCRIPT = _CRAM / "scripts" / "target" / "obuspa-datamodel-dump.sh"
_EXPECTED = _CRAM / "generic" / "fixtures" / "obuspa.expected"
_WAIT_AFTER_RESTART = 20


def _log_dir(request: pytest.FixtureRequest) -> Path:
    return Path(request.config.getoption("save_console_logs", None) or Path.cwd())


def _verify(snapshot: bytes, expected: bytes, name: str, log_dir: Path) -> str | None:
    """Return None when the snapshot equals the expected file, else the diff."""
    if snapshot == expected:
        return None
    diff = "".join(
        difflib.unified_diff(
            [repr(line) + "\n" for line in expected.split(b"\n")],
            [repr(line) + "\n" for line in snapshot.split(b"\n")],
            fromfile="expected",
            tofile=name,
        )
    )
    (log_dir / f"{name}.actual").write_bytes(snapshot)
    (log_dir / f"{name}.diff").write_text(diff, encoding="utf-8")
    return diff


def test_obuspa_keeps_the_data_model_across_a_restart(
    board: PrplOSCPE, request: pytest.FixtureRequest
) -> None:
    """Both snapshots equal fixtures/obuspa.expected."""
    if re.search("Valyrian", os.environ.get("CI_JOB_NAME", "")):
        pytest.skip("not on Valyrian (PCF-2669)")
    expected = _EXPECTED.read_bytes()
    log_dir = _log_dir(request)

    with obuspa_dump_script(board, _DUMP_SCRIPT):
        # As in the script, any failure of the first snapshot, a timeout
        # included, is recorded, and the test goes on with the restart.
        try:
            before = obuspa_datamodel_snapshot(board, "generic")
            before_diff = _verify(before, expected, "obuspa.before-restart", log_dir)
        except Exception as exc:  # noqa: BLE001
            before_diff = f"no snapshot: {type(exc).__name__}: {exc}"
        restart_service(board, "obuspa")
        time.sleep(_WAIT_AFTER_RESTART)
        after = obuspa_datamodel_snapshot(board, "generic")
        after_diff = _verify(after, expected, "obuspa.after-restart", log_dir)

    assert before_diff is None, f"before the restart:\n{before_diff}"
    assert after_diff is None, f"after the restart:\n{after_diff}"
