#!/usr/bin/env python3
"""Lint the cram component manifest and report its computed coverage."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path
from typing import Iterable, List, Sequence, Set

from cram_component_bucketing import (
    BucketingError,
    discover_tests,
    expand_manifest,
    load_manifest,
    partition_tests,
    resolve_manifest_path,
)


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--test-root",
        required=True,
        type=Path,
        help="cram test root",
    )
    parser.add_argument(
        "--manifest",
        required=True,
        type=Path,
        help="manifest path (relative paths are resolved below --test-root)",
    )
    baseline = parser.add_mutually_exclusive_group()
    baseline.add_argument(
        "--base-ref",
        help="Git ref whose tracked tests form the newly-in-remainder baseline",
    )
    baseline.add_argument(
        "--base-list",
        type=Path,
        help="newline-separated test paths for the newly-in-remainder baseline",
    )
    parser.add_argument(
        "--print-remainder",
        action="store_true",
        help="print every test in the computed prplos remainder",
    )
    return parser.parse_args(argv)


def _run_git(test_root: Path, args: Sequence[str]) -> str:
    command = ["git", "-C", os.fspath(test_root), *args]
    try:
        result = subprocess.run(
            command,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
    except FileNotFoundError as error:
        raise BucketingError("git is required for this check") from error
    except subprocess.CalledProcessError as error:
        detail = error.stderr.strip() or error.stdout.strip()
        raise BucketingError(
            f"command failed ({' '.join(command)}): {detail}"
        ) from error
    return result.stdout


def _git_context(test_root: Path) -> tuple[Path, str]:
    top = Path(_run_git(test_root, ["rev-parse", "--show-toplevel"]).strip())
    try:
        relative_root = test_root.resolve().relative_to(top.resolve()).as_posix()
    except ValueError as error:
        raise BucketingError(f"test root is outside Git worktree {top}") from error
    return top, relative_root


def _strip_test_root_prefix(path: str, test_root: Path) -> str:
    normalized = path.strip().replace("\\", "/")
    while normalized.startswith("./"):
        normalized = normalized[2:]
    if not normalized:
        return normalized

    root_text = os.path.normpath(os.fspath(test_root)).replace("\\", "/")
    while root_text.startswith("./"):
        root_text = root_text[2:]
    if normalized.startswith(root_text + "/"):
        return normalized[len(root_text) + 1 :]

    candidate = Path(path.strip())
    if candidate.is_absolute():
        try:
            return candidate.resolve().relative_to(test_root.resolve()).as_posix()
        except ValueError:
            return normalized
    return normalized


def _base_tests_from_list(path: Path, test_root: Path) -> Set[str]:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as error:
        raise BucketingError(f"cannot read base list {path}: {error}") from error
    return {
        normalized
        for line in lines
        if (normalized := _strip_test_root_prefix(line, test_root))
        and normalized.endswith(".t")
        and not normalized.startswith("post/")
    }


def _base_tests_from_ref(test_root: Path, ref: str) -> Set[str]:
    top, relative_root = _git_context(test_root)
    output = _run_git(top, ["ls-tree", "-r", "--name-only", ref, "--", relative_root])
    prefix = relative_root.rstrip("/") + "/"
    tests = set()
    for path in output.splitlines():
        if path.startswith(prefix):
            path = path[len(prefix) :]
        if path.endswith(".t") and not path.startswith("post/"):
            tests.add(path)
    return tests


def _scan_broken_symlinks(paths: Iterable[Path], test_root: Path) -> List[str]:
    broken = []
    for path in paths:
        if path.is_symlink() and not path.exists():
            broken.append(path.relative_to(test_root).as_posix())
    return sorted(broken)


def _tracked_broken_symlinks(test_root: Path, tests: Sequence[Path]) -> List[str]:
    try:
        top, relative_root = _git_context(test_root)
    except BucketingError:
        return _scan_broken_symlinks(tests, test_root)

    output = _run_git(top, ["ls-files", "-s", "--", relative_root])
    prefix = relative_root.rstrip("/") + "/"
    tracked_symlinks = set()
    for line in output.splitlines():
        metadata, separator, repo_path = line.partition("\t")
        if not separator or not metadata.startswith("120000 "):
            continue
        if repo_path.startswith(prefix):
            relative = repo_path[len(prefix) :]
            if relative.endswith(".t"):
                tracked_symlinks.add(relative)

    broken = []
    for relative in sorted(tracked_symlinks):
        path = test_root / Path(*relative.split("/"))
        if path.is_symlink() and not path.exists():
            broken.append(relative)
    return broken


def _relative_paths(paths: Iterable[Path], test_root: Path) -> Set[str]:
    return {path.relative_to(test_root).as_posix() for path in paths}


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        manifest_path = resolve_manifest_path(args.test_root, args.manifest)
        manifest = load_manifest(manifest_path)
        expanded = expand_manifest(args.test_root, manifest)
        tests = discover_tests(args.test_root)
        buckets = partition_tests(tests, args.test_root, expanded)
        current = _relative_paths(tests, args.test_root)

        if args.base_ref:
            base = _base_tests_from_ref(args.test_root, args.base_ref)
        elif args.base_list:
            base = _base_tests_from_list(args.base_list, args.test_root)
        else:
            base = None

        remainder = _relative_paths(buckets["prplos"], args.test_root)
        newly_remainder = sorted((current - base) & remainder) if base is not None else []
        broken_symlinks = _tracked_broken_symlinks(args.test_root, tests)
    except BucketingError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2

    print(f"full: {len(tests)}")
    print(f"sanity: {len(buckets['sanity'])}")
    for name in manifest.component_patterns:
        print(f"{name}: {len(buckets[name])}")
    print(f"prplos: {len(buckets['prplos'])}")
    print(f"smoke: {len(expanded.smoke_matches)}")
    print(f"hw_only: {len(expanded.hw_only_matches)}")
    if args.print_remainder:
        print("prplos remainder:")
        for path in sorted(remainder):
            print(f"  {path}")

    if newly_remainder:
        print(
            "warning: newly added tests fell into the prplos remainder:",
            file=sys.stderr,
        )
        for path in newly_remainder:
            print(f"  {path}", file=sys.stderr)

    if broken_symlinks:
        print("warning: tracked test symlinks have missing targets:", file=sys.stderr)
        for path in broken_symlinks:
            print(f"  {path}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    sys.exit(main())
