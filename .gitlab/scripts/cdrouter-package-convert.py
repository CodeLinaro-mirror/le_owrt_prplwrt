#!/usr/bin/env python3
"""Convert CDRouter .gz package exports to YAML manifests."""

import argparse
import fnmatch
import gzip
import json
import logging
import os
import sys

import yaml

OPTION_DEFAULTS = {
    "forever": False,
    "loop": "0",
    "repeat": "0",
    "maxfail": "0",
    "duration": "0",
    "duration_units": "seconds",
    "duration_interrupt": False,
    "duration_no_error": False,
    "wait": "0",
    "pause": False,
    "shuffle": False,
    "seed": "0",
    "retry": "0",
    "rdelay": "0",
    "sync": False,
}

FORBIDDEN_KEYS = {"config", "device", "config_id", "device_id"}

log = logging.getLogger("cdrouter-package-convert")


def read_gz_package(gz_path):
    """Read a CDRouter .gz export and return the package dict.

    The .gz file contains 2-3 lines:
      - Line 0: metadata header (version, names only)
      - Line 1: full data (configs, packages, devices)
      - Line 2: null-byte padding (ignored)
    """
    with gzip.open(gz_path, "rt", errors="replace") as fh:
        lines = fh.readlines()

    # Find JSON data lines (skip empty/null-padded lines)
    json_lines = []
    for line in lines:
        stripped = line.strip().strip("\x00").strip()
        if stripped:
            json_lines.append(stripped)

    if len(json_lines) < 2:
        raise ValueError(f"Expected at least 2 JSON lines, got {len(json_lines)}")

    data = json.loads(json_lines[1])
    packages = data.get("packages", [])
    if not packages:
        raise ValueError("No packages found in data line")

    return packages[0]


def normalize_options(options):
    """Return a normalized source options map."""
    if not options:
        return {}
    return dict(options)


def compact_options(options):
    """Return a compact options map with default values removed."""
    normalized = normalize_options(options)
    compact = {}
    for key, value in normalized.items():
        default = OPTION_DEFAULTS.get(key)
        if default is None or value != default:
            compact[key] = value
    return compact


def expand_options_with_defaults(options):
    """Return options expanded with defaults for semantic comparisons."""
    expanded = dict(OPTION_DEFAULTS)
    expanded.update(normalize_options(options))
    return expanded


def package_to_yaml_dict(pkg, preserve_all_options=False):
    """Convert a package dict to the output YAML schema."""
    result = {"name": pkg["name"]}

    description = pkg.get("description", "")
    if description:
        result["description"] = description

    testlist = pkg.get("testlist", [])
    result["tests"] = testlist

    if preserve_all_options:
        options = normalize_options(pkg.get("options"))
    else:
        options = compact_options(pkg.get("options"))
    if options:
        result["options"] = options

    # Verify no forbidden keys leaked through
    for key in FORBIDDEN_KEYS:
        assert key not in result, f"Forbidden key '{key}' in output"

    return result


def verify_fidelity(pkg, yaml_dict):
    """Verify round-trip fidelity between source .gz and generated YAML.

    Returns (passed, errors) tuple.
    """
    errors = []

    # Check testlist order and content
    src_tests = pkg.get("testlist", [])
    yaml_tests = yaml_dict.get("tests", [])

    if src_tests != yaml_tests:
        if len(src_tests) != len(yaml_tests):
            errors.append(
                f"testlist length mismatch: source={len(src_tests)}, "
                f"yaml={len(yaml_tests)}"
            )
        else:
            for i, (s, y) in enumerate(zip(src_tests, yaml_tests)):
                if s != y:
                    errors.append(f"testlist[{i}] mismatch: source={s!r}, yaml={y!r}")

    # Check semantic options fidelity after default expansion.
    src_options = expand_options_with_defaults(pkg.get("options"))
    yaml_options = expand_options_with_defaults(yaml_dict.get("options", {}))

    if src_options != yaml_options:
        for key in set(src_options) | set(yaml_options):
            sv = src_options.get(key)
            yv = yaml_options.get(key)
            if sv != yv:
                errors.append(f"options[{key!r}] mismatch: source={sv!r}, yaml={yv!r}")

    # Check forbidden keys
    for key in FORBIDDEN_KEYS:
        if key in yaml_dict:
            errors.append(f"forbidden key '{key}' present in output")

    return len(errors) == 0, errors


def convert_package(
    gz_path, output_dir, dry_run=False, overwrite=False, preserve_all_options=False
):
    """Convert a single .gz package to YAML. Returns (name, passed, errors)."""
    basename = os.path.splitext(os.path.basename(gz_path))[0]
    yaml_path = os.path.join(output_dir, basename + ".yaml")

    log.info("Converting %s", gz_path)

    try:
        pkg = read_gz_package(gz_path)
    except Exception as e:
        return basename, False, [f"Failed to read .gz: {e}"]

    package_name = pkg.get("name")
    if package_name != basename:
        return (
            basename,
            False,
            [
                "Package name does not match filename: "
                f"filename={basename!r}, package={package_name!r}"
            ],
        )

    yaml_dict = package_to_yaml_dict(pkg, preserve_all_options)
    passed, errors = verify_fidelity(pkg, yaml_dict)

    if not passed:
        for err in errors:
            log.error("  FIDELITY FAIL [%s]: %s", basename, err)
        return basename, False, errors

    if not overwrite and os.path.exists(yaml_path):
        log.info("  Skipping %s (already exists, use --overwrite)", yaml_path)
        return basename, True, []

    if dry_run:
        log.info("  Would write %s", yaml_path)
        content = yaml.dump(yaml_dict, default_flow_style=False, sort_keys=False)
        log.info("--- %s ---\n%s---", basename, content)
    else:
        os.makedirs(output_dir, exist_ok=True)
        with open(yaml_path, "w") as fh:
            yaml.dump(yaml_dict, fh, default_flow_style=False, sort_keys=False)
        log.info("  Wrote %s", yaml_path)

    return basename, True, []


def main():
    parser = argparse.ArgumentParser(
        description="Convert CDRouter .gz package exports to YAML manifests"
    )
    parser.add_argument(
        "--input-dir",
        default=".testbed/cdrouter/packages/",
        help="Directory containing .gz files (default: .testbed/cdrouter/packages/)",
    )
    parser.add_argument(
        "--output-dir",
        default=".testbed/cdrouter/packages/",
        help="Directory for YAML output (default: .testbed/cdrouter/packages/)",
    )
    parser.add_argument(
        "--filter",
        default=None,
        help="Glob pattern to filter which .gz files to convert",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be done without writing files",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Overwrite existing YAML files (default: skip if exists)",
    )
    parser.add_argument(
        "--preserve-all-options",
        action="store_true",
        help="Preserve full options map instead of compacting defaults",
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Enable verbose output",
    )
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(levelname)s: %(message)s",
    )

    if not os.path.isdir(args.input_dir):
        log.error("Input directory does not exist: %s", args.input_dir)
        sys.exit(1)

    gz_files = sorted(f for f in os.listdir(args.input_dir) if f.endswith(".gz"))

    if args.filter:
        gz_files = [f for f in gz_files if fnmatch.fnmatch(f, args.filter)]

    if not gz_files:
        log.warning("No .gz files found in %s", args.input_dir)
        sys.exit(0)

    log.info("Found %d .gz file(s) to convert", len(gz_files))

    results = []
    for gz_file in gz_files:
        gz_path = os.path.join(args.input_dir, gz_file)
        name, passed, errors = convert_package(
            gz_path,
            args.output_dir,
            args.dry_run,
            args.overwrite,
            args.preserve_all_options,
        )
        results.append((name, passed, errors))

    # Print fidelity report
    print()
    print("=" * 60)
    print("Fidelity Report")
    print("=" * 60)
    all_passed = True
    for name, passed, errors in results:
        status = "PASS" if passed else "FAIL"
        print(f"  {status}  {name}")
        if errors:
            for err in errors:
                print(f"         {err}")
        if not passed:
            all_passed = False
    print("=" * 60)

    total = len(results)
    passed_count = sum(1 for _, p, _ in results if p)
    print(f"  {passed_count}/{total} passed")

    if not all_passed:
        sys.exit(1)


if __name__ == "__main__":
    main()
