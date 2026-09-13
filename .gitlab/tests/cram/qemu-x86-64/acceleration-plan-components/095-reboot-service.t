SPDX-FileCopyrightText: Copyright (c) 2026 prpl Foundation
# QEMU has no watchdog bootstatus, so reboot-service reports a first boot as Warm; see CI-101

Create R alias and select the expected reboot datamodel:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ EXPECTED="${TESTDIR}/../fixtures"

Check the root datamodel settings, normalizing only a valid timestamp:

  $ R "ba-cli --json Reboot.? | sed -n '2p'" | jq --sort-keys '.[0] | .["Reboot.Reboot.1."].TimeStamp |= if test("\\A[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?Z\\z") then "<timestamp>" else error("invalid reboot timestamp") end' > reboot-initial.json
  $ diff -u "$EXPECTED/reboot-service-initial.json" reboot-initial.json

Flush counters:

  $ R "ba-cli --json 'Reboot.RemoveAllReboots()'" >/dev/null

Check that the history is cleared and the boot counters are unchanged:

  $ R "ba-cli --json Reboot.?0 | sed -n '2p'" | jq --sort-keys '.[0]' > reboot-cleared.json
  $ diff -u "$EXPECTED/reboot-service-cleared.json" reboot-cleared.json
