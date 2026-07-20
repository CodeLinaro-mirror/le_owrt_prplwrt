# Cram tests

This directory contains the cram test suites used by the testbed jobs.
Generic tests live in `generic/`; each supported device also has a board
directory. Tests under `post/` run separately after every selected main suite.

## Component buckets

[`components.yml`](components.yml) assigns tests to the component jobs:

- `sanity` contains DUT and environment checks whose failure invalidates the
  result of any component bucket.
- `lcm` contains tests matched by the explicit Lifecycle Manager globs.
- `prplmesh` contains tests matched by the explicit prplMesh and wireless
  stack globs.
- `prplos` is the computed remainder after the sanity and explicit buckets
  are removed.
- `full` preserves the complete legacy suite and its ordering.

A trimmed manifest looks like this:

```yaml
version: 1
sanity:
  include:
    # Globs are relative to the cram test root.
    - "*/005-build-config.t"
components:
  lcm:
    description: Lifecycle Manager
    include:
      - "generic/lcm/**/*.t"
  prplmesh:
    description: prplMesh + wireless stack (pwhm/mlo/apmld/wifi)
    include:
      - "**/*prplmesh*.t"
```

Every test in a split suite belongs to exactly one of `sanity`, `lcm`,
`prplmesh`, or the `prplos` remainder. Sanity matches are removed first and
must not also match an explicit component glob. A non-sanity test may match at
most one explicit component; tests that match none enter the remainder. To
reassign a test, add or adjust an `include` glob in the desired bucket. The
`prplos` remainder is recomputed automatically.

For `prplmesh`, `lcm`, and `prplos`, the resolver puts the board's ordered
sanity block before the ordered component block. Sanity checks therefore run
first in each split component job. Non-sanity tests still run once across the
three buckets. The `full` selection keeps the legacy suite byte-for-byte, and
tests under `post/` continue to run separately after every selected main
suite.

The `smoke` and `hw_only` sets are reserved for the upcoming QEMU testbed lane
(CI-5): `smoke` is the fast QEMU pre-gate set, while `hw_only` contains tests
excluded from the QEMU candidate set. The lint validates both sets; hardware
jobs do not use them.

## Scripts

- `cram_component_bucketing.py` provides the shared manifest, collection, glob
  expansion, and partition logic.
- `resolve-component-tests.py` prints the ordered test list for one board and
  component.
- `check-component-coverage.py` validates the manifest and reports sanity and
  bucket counts, newly added remainder tests, and broken test symlinks.

`cram_component_bucketing.py` uses underscores because it is an importable
module. Executable scripts follow the repository's hyphenated CLI convention.

## Resolving tests locally

The CI jobs call the resolver at runtime. Run it from the same checkout and
Python environment that will run cram so its filesystem view and PyYAML
dependency match the job:

```sh
.gitlab/tests/cram/scripts/resolve-component-tests.py \
  --test-root .gitlab/tests/cram \
  --manifest components.yml \
  --board wnc-freedom \
  --component prplos
```

The command prints the ordered test paths for cram. Valid component values are
`full`, `sanity`, `prplmesh`, `lcm`, and `prplos`. Use `sanity` to inspect the
always-run block. The `sanity` value is for inspection, not pipeline job
selection.

Run the manifest lint from that environment as well:

```sh
.gitlab/tests/cram/scripts/check-component-coverage.py \
  --test-root .gitlab/tests/cram \
  --manifest components.yml
```

By default, the lint prints the `full` and `sanity` counts, the component and
reserved-set counts, and warnings without listing the entire `prplos`
remainder. It rejects unmatched include globs, overlaps between `sanity` and
an explicit component, and overlaps between explicit components. Add
`--print-remainder` to include the sorted remainder list.

Add `--base-ref <commit>` to compare against the tests tracked by a Git
revision. `--base-list <path>` accepts a newline-separated baseline instead;
the two baseline options are mutually exclusive. The lint still succeeds when
a newly added test enters the `prplos` remainder, but prints a warning so the
assignment can be reviewed.
