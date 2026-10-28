# SPDX-FileCopyrightText: 2026 prpl Foundation
# SPDX-License-Identifier: GPL-2.0-only
"""Device.DeviceInfo.ActiveFirmwareImage names a valid firmware image.

The check is that of the cram test
generic/deviceinfo-confirm-valid-activefirmwareimage.t. The output is
compared as a whole, with its newlines.
"""

from __future__ import annotations

import os
from typing import TYPE_CHECKING

import pytest
from boardfarm3_prplos.use_cases.shell import run_command

if TYPE_CHECKING:
    from boardfarm3_prplos.templates.prplos_cpe import PrplOSCPE


def test_active_firmware_image_is_in_the_valid_range(board: PrplOSCPE) -> None:
    """ba-cli gives an empty line, then Device.DeviceInfo.FirmwareImage.1."""
    if os.environ.get("DUT_BOARD") not in ("mxl25641-hdk-6", "wnc-freedom"):
        pytest.skip("only on OSPv2 and Freedom boards")
    result = run_command(board, "ba-cli -l Device.DeviceInfo.ActiveFirmwareImage?")
    assert result.output == "\nDevice.DeviceInfo.FirmwareImage.1\n"
    assert result.exit_code == 0
