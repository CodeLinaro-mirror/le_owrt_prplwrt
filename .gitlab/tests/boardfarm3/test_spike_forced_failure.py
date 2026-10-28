# SPDX-FileCopyrightText: 2026 prpl Foundation
"""Forced failure after a good boot, to check the recovery path of the job.

Temporary check: it fails only when BF3_FORCE_FAILURE is 1, and it is
skipped otherwise. The board must then close the boardfarm3 console, give
the serial port back to labgrid for the dump, and power off.
"""

from __future__ import annotations

import os

import pytest


@pytest.mark.skipif(
    os.environ.get("BF3_FORCE_FAILURE") != "1",
    reason="BF3_FORCE_FAILURE is not 1",
)
def test_forced_failure() -> None:
    """Fail on purpose."""
    pytest.fail("forced failure, BF3_FORCE_FAILURE=1")
