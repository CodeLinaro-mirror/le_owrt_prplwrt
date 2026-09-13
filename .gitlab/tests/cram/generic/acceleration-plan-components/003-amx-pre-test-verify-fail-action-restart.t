SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation
Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ if [ "$DUT_BOARD" = "qemu-x86-64" ]; then exit 80; fi

Ensure ProcessMonitor.Test.i.FailAction does not have REBOOT action:

  $ R "ba-cli -l ProcessMonitor.Test.*.FailAction\? | "\
  > "grep -vE '(RESTART|NONE)' | sed '/^$/d'"
