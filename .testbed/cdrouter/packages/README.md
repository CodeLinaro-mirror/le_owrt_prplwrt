# CDRouter Packages

This directory contains CDRouter package manifests in YAML format.

## Package Format (YAML)

Each package is defined in a single file `<package-name>.yaml` in this
directory:

```yaml
name: CDRouter-Top-100+mDNS
description: Optional human-readable description
includes:                          # optional
  - groups/ipv4-top-100.yaml       # relative path to included manifest
dedup_tests: true                  # optional, root-only (default: false)
tests:
  - cdrouter_nat_1
  - cdrouter_nat_2
  - dns_1
options:                           # optional pass-through package options
  maxfail: "5"
```

Required fields: `name` (must match filename), `tests`.

Forbidden fields: `config`, `device`, `config_id`, `device_id` (runtime
binding stays in CI).

## Package Options

The `options` map controls scheduler behavior for a package run. Keys below
are recognized by the converter, which compacts any key whose value matches
its default so hand-written manifests only need to set overrides.
`package_apply` rejects option keys not known to the `cdrouter` Python SDK.
Authoritative semantics live in CDRouter's API/CLI reference.

| Key | Type | Default | Meaning |
|---|---|---|---|
| `forever` | bool | `false` | Run indefinitely, ignoring `loop`/`repeat` termination. |
| `loop` | int string | `"0"` | Number of full testlist iterations. `"0"` = one pass. |
| `repeat` | int string | `"0"` | Extra repetitions of each test per pass. |
| `maxfail` | int string | `"0"` | Abort after N test failures. `"0"` = no limit. |
| `duration` | int string | `"0"` | Wall-clock budget for the package. `"0"` = unbounded. |
| `duration_units` | string | `"seconds"` | Unit for `duration` (`seconds` or `minutes`). |
| `duration_interrupt` | bool | `false` | On timeout, interrupt the running test instead of letting it finish. |
| `duration_no_error` | bool | `false` | Do not flag a duration timeout as a failure. |
| `wait` | int string | `"0"` | Seconds to pause between tests. |
| `pause` | bool | `false` | Pause between tests and wait for resume. |
| `shuffle` | bool | `false` | Randomize test order within each loop. |
| `seed` | int string | `"0"` | Seed for `shuffle`. `"0"` = random. |
| `retry` | int string | `"0"` | Retry each failing test up to N times. |
| `rdelay` | int string | `"0"` | Seconds to wait between retry attempts. |
| `sync` | bool | `false` | Synchronize state between tests for reproducibility. |

Integer-valued options are stored as strings in the CDRouter API — quote them
in YAML (e.g. `maxfail: "5"`). Booleans are unquoted (`true` / `false`). Pass
`--preserve-all-options` to the converter to keep default-valued keys in
generated manifests.

## Include Semantics

Manifests can include other manifests via `includes`:

- Includes are resolved **depth-first** in listed order.
- Tests from included manifests appear **before** the current manifest's tests.
- **Dedup** is configurable via root `dedup_tests` (default: `false`):
  - `false`: duplicates are preserved in final test order.
  - `true`: first occurrence wins, later duplicates are dropped.
- Include paths are resolved relative to the including file and must stay under
  `cdrouter/packages/`.
- Options merge: included options first, root manifest wins on conflicts.
- `name` and `description` are taken from the root manifest only.
- `dedup_tests` is taken from the root manifest only.
- Circular includes are detected and rejected.

## Shared Test Groups (Optional)

Reusable test subsets can be placed under `groups/`:

```yaml
tests:
  - cdrouter_nat_1
  - cdrouter_nat_2
```

Group files must not define `name`, `description`, or `options`. Package
manifests reference them via `includes`:

```yaml
includes:
  - groups/ipv4-top-100.yaml
```

Included manifests and group manifests must not define `dedup_tests`.

## Module-Based Packages

Some packages use CDRouter module entries instead of individual tests:

```yaml
name: CDRouter-UPnP-IPv46
tests:
  - cdrouter_ssdp_1
  - cdrouter_ssdp_2
  - MODULE_upnp.tcl    # runs all tests in the upnp module
```

## Migration from .gz Exports

Existing `.gz` package exports can be converted to YAML using:

```bash
.gitlab/scripts/cdrouter-package-convert.py \
  --input-dir .testbed/cdrouter/packages/ \
  --output-dir .testbed/cdrouter/packages/ \
  --overwrite
```

The converter reads the two-line JSON format inside `.gz` files and emits YAML
manifests. By default it compacts the `options` map by omitting keys set to
known defaults, and verifies fidelity by checking exact testlist order plus
semantic options equivalence after default expansion. Use
`--preserve-all-options` to emit the full source options map when needed.

## CI Integration

CI jobs use `package_apply` to upsert packages via the CDRouter API from YAML
manifests:

```bash
.gitlab/scripts/testbed-cdrouter.py package_apply $TEST_PACKAGE
```

This resolves `packages/$TEST_PACKAGE.yaml`, processes includes, and creates or
updates the named package on the CDRouter instance. Runtime config/device
binding remains in the `package_run` step.

To validate a manifest offline (no CDRouter connection) for pre-commit or CI
lint, use `package_validate`, which resolves includes and checks option keys
against the `cdrouter` SDK:

```bash
.gitlab/scripts/testbed-cdrouter.py package_validate $TEST_PACKAGE
```
