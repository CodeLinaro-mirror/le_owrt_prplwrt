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

## Feed pin layout

The `feed_amx`, `feed_prplmesh`, and `feed_prplos` pins live in
`profiles/feed_amx.yml`, `profiles/feed_prplmesh.yml`, and
`profiles/feed_prplos.yml`. `profiles/prpl_core.yml` includes those profiles,
so builds still receive the same feeds while a feed-only bump has its own
changed path. Keep each feed pin in its dedicated profile; the selection matrix
uses those paths to distinguish full, prplMesh, and prplOS coverage.

## Scripts

- `cram_component_bucketing.py` provides the shared manifest, collection, glob
  expansion, and partition logic.
- `resolve-component-tests.py` prints the ordered test list for one board and
  component.
- `check-component-coverage.py` validates the manifest and reports sanity and
  bucket counts, newly added remainder tests, and broken test symlinks.

`cram_component_bucketing.py` uses underscores because it is an importable
module. Executable scripts follow the repository's hyphenated CLI convention.

## Diff-based selection

Merge request pipelines map changed paths to component lists for six hardware
boards. Board-specific paths select their owning board. Cross-cutting paths
select only the two priority boards, Freedom and OSPv2; the other four boards
remain available for manual runs and weekly full coverage.

| Changed path | Board scope | Selection |
|---|---|---|
| `profiles/mvebu.yml`, `ipq807x.yml`, `mtk_filogic.yml`, or `airoha_an7581.yml` | Omnia, Haze, Mozart, or Valyrian respectively | `full` |
| `profiles/qca_ipq95xx.yml` | Freedom | `full` |
| `profiles/mxl_x86_osp_tb341_v2.yml` or `mxl_wlan_hostap_ng_wav700.yml` | OSPv2 | `full` |
| `profiles/secure_boot_emmc.yml` | Freedom + OSPv2 | `full` |
| `profiles/feed_amx.yml` | Freedom + OSPv2 | `full` |
| `profiles/feed_prplmesh.yml` | Freedom + OSPv2 | `prplmesh` |
| `profiles/feed_prplos.yml` | Freedom + OSPv2 | `prplos` |
| `profiles/lcm.yml` | Freedom + OSPv2 | `lcm` |
| `profiles/prpl_core.yml`, `prpl.yml`, or `security.yml` | Freedom + OSPv2 | `full` |
| `profiles/mgmt.yml`, `cellular.yml`, or `thread.yml` | Freedom + OSPv2 | `prplos` |
| `.gitlab/tests/cram/<board>/**` | owning board | touched test's bucket |
| `.gitlab/tests/cram/generic/**` | Freedom + OSPv2 | touched test's bucket |
| `.gitlab/tests/cram/post/**` or a sanity-listed test | Freedom + OSPv2 | `prplos` |
| `.gitlab/testbed/<board>.yml` | owning board | `prplos` |
| `.gitlab/testbed.yml` | Freedom + OSPv2 | `prplos` |
| `package/**`, `target/**`, `toolchain/**`, `include/**`, `config/**`, `tools/**`, `feeds.conf.default`, `Makefile`, or `rules.mk` | Freedom + OSPv2 | `full` |

A `by-test` row asks the manifest which bucket owns each touched test. Multiple
matches form an ordered component union; a `full` match or all three split
buckets collapse to `full`. Unmatched paths, including documentation and other
CI files, do not arm a board.

Profiles without a cram build consumer are explicit no-ops:
`debug.yml`, `extender_full.yml`, `extender_minimal.yml`, `ipq40xx.yml`,
`mxl_x86.yml`, `mxl_x86_sec.yml`, `mxl_x86_osp_tb341.yml`, `mxl_wlan.yml`,
`mxl_wlan_hostap_ng.yml`, and `mxl_wlan_hostap_ng_gw.yml`. Changes to
`components.yml` and its scripts are also no-ops because lint validates them
and the author deliberately chooses any DUT run.

### Labels and precedence

The scoped labels `cram::full`, `cram::prplmesh`, `cram::lcm`, and
`cram::prplos` override the computed selection. `cram::skip` suppresses
automatic selection for the merge request. The labels share the `cram::`
scope, so GitLab keeps at most one on an MR.

Selection precedence is:

1. A set `CRAM_COMPONENTS` pipeline variable stands the `[auto]` jobs down and
   controls the existing component jobs. `CRAM_COMPONENTS=none` matches no
   component.
2. `cram::skip` stands `[auto]` jobs down; another `cram::*` label forces that
   component.
3. Otherwise, the merge request diff is resolved through the matrix above.
4. Any `full` result, or the union of all split buckets, collapses to `full`.

Labels are checked both when GitLab creates the pipeline and again when the
job starts. A label added after pipeline creation but before the build is
played therefore still controls the tests that run.

### QEMU end-state

CI-5 will add QEMU as a selection board without changing the resolver or job
template. `test:qemu:smoke` remains an unfiltered MR pre-gate,
`test:qemu:full` remains an always-full non-blocking equivalence run, and a
future `cram qemu [auto]` receives cross-cutting selections. At that point
`profiles/x86_64.yml`, currently an explicit no-op reserved for CI-5, maps to
QEMU `full`.

## Selecting pipeline jobs

Merge request pipelines contain one `cram <Board> [auto]` job for every
hardware board, alongside the four existing component jobs per board. An
`[auto]` job resolves the MR diff, labels, and variables when it starts, then
runs the resulting component union in one DUT boot.

The non-DUT `report cram selection` job is a manual, non-gating preview. Play
it before starting a build to print all six board selections and their reasons;
it reserves no hardware. The `lint cram component manifest` job and the four
named component jobs also remain manual and non-gating. Play a named component
job directly when an explicit bucket is more useful than the computed result.

To start named component jobs automatically, set the pipeline-level
`CRAM_COMPONENTS`
variable to a comma-separated list containing one or more of `full`,
`prplmesh`, `lcm`, and `prplos`. Do not add spaces around the commas. Listed
buckets start as soon as their board's build succeeds; `[auto]` jobs stand
down to avoid duplicate runs. The variable is unset by default.

For example:

```text
CRAM_COMPONENTS=prplmesh
CRAM_COMPONENTS=lcm,prplos
CRAM_COMPONENTS=full
```

Release tag pipelines (`prplware-v*`) start the `full` jobs automatically;
the other buckets stay manual there. Scheduled pipelines never create cram
jobs, because they also never create the build jobs these jobs need. The job
names have the form `cram <Board> [<component>]`, such as `cram OSPv2 [lcm]`.
The trailing component name lets GitLab group the five jobs for a board in
the pipeline UI.

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
`full`, `sanity`, `prplmesh`, `lcm`, and `prplos`. A comma-separated value such
as `prplmesh,lcm` resolves the ordered union: the sanity block is emitted once,
then each selected bucket in manifest order, so the job still uses one boot.
Repeated components and tests are de-duplicated. Selecting `full`, or selecting
all three split buckets, collapses to the legacy full-suite ordering. Do not put
spaces around the commas.

Use `sanity` to inspect the always-run block. The `sanity` value is for
inspection, not pipeline job selection.

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

The same lint validates the selection schema and its board references. Every
`profiles/*.yml` file must be categorized by exactly one effective selection
row, including explicit no-ops, so adding an uncategorized profile fails CI.
It also derives each board's coarse `rules:changes` list from the manifest and
compares it with the YAML anchors used by GitLab. This prevents pipeline
arming rules from drifting away from the runtime matrix.

Add `--base-ref <commit>` to compare against the tests tracked by a Git
revision. `--base-list <path>` accepts a newline-separated baseline instead;
the two baseline options are mutually exclusive. The lint still succeeds when
a newly added test enters the `prplos` remainder, but prints a warning so the
assignment can be reviewed.

The lint is a manual, non-gating play button in every non-scheduled pipeline.
When played in a merge request pipeline, it still receives the diff base
automatically. Other pipeline types run the same manifest checks without a
comparison baseline; scheduled pipelines skip the job.
