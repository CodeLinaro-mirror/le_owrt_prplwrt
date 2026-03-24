# OBUSPA Fixtures

This directory stores the checked-in datamodel fixtures used by the
generic OBUSPA cram tests:

- `obuspa.expected` for [`../obuspa.t`](../obuspa.t)
- `obuspa-cellular.expected` for [`../obuspa-cellular.t`](../obuspa-cellular.t)

The tests keep the full datamodel comparison intact, but they no longer
embed the expected snapshots inline in the `.t` files. Instead they:

1. capture the current datamodel on the DUT,
2. copy it back to the host,
3. compare it against the matching fixture in this directory.

On mismatch, the helper script writes generated files next to the
fixture:

- `*.actual` contains the captured DUT snapshot
- `*.diff` contains the `diff -u` output against the fixture

Those generated files are ignored by `.gitignore` so they can be kept as
local debugging artifacts or uploaded by CI without being committed by
accident.

When intentionally refreshing a fixture, review the generated
`*.actual`/`*.diff` files first and then replace the expected snapshot
deliberately.
