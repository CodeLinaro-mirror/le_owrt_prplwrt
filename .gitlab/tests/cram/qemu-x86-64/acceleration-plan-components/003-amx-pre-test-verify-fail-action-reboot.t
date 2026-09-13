SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation
Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

# QEMU keeps the image's REBOOT policy so a crashing service surfaces as a guest reboot; see CI-100

Ensure ProcessMonitor.Test.i.FailAction retains the six REBOOT actions:

  $ R "ba-cli -l ProcessMonitor.Test.*.FailAction\? | "\
  > "grep -vE '(RESTART|NONE)' | sed '/^$/d'"
  REBOOT
  REBOOT
  REBOOT
  REBOOT
  REBOOT
  REBOOT
