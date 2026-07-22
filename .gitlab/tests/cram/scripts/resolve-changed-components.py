#!/usr/bin/env python3
"""Resolve changed repository paths to per-board cram components."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path
from typing import Sequence

from cram_component_bucketing import (
    BucketingError,
    Manifest,
    load_manifest,
    resolve_manifest_path,
    select_changed_components,
)


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--test-root", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--base-ref", required=True)
    parser.add_argument("--head-ref", default="HEAD")
    target = parser.add_mutually_exclusive_group(required=True)
    target.add_argument("--board")
    target.add_argument("--report", action="store_true")
    parser.add_argument("--cram-components", default=None)
    parser.add_argument("--labels", default="")
    return parser.parse_args(argv)


def _run_git(test_root: Path, arguments: Sequence[str]) -> str:
    command = ["git", "-C", os.fspath(test_root), *arguments]
    try:
        result = subprocess.run(
            command,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
    except FileNotFoundError as error:
        raise BucketingError("git is required for selection") from error
    except subprocess.CalledProcessError as error:
        detail = error.stderr.strip() or error.stdout.strip()
        raise BucketingError(
            f"command failed ({' '.join(command)}): {detail}"
        ) from error
    return result.stdout


def _changed_paths(test_root: Path, base_ref: str, head_ref: str) -> list[str]:
    output = _run_git(
        test_root,
        ["diff", "--name-only", "--no-renames", f"{base_ref}..{head_ref}"],
    )
    return [path for path in output.splitlines() if path]


def _label_override(labels: str) -> tuple[str | None, str | None]:
    values = [label.strip() for label in labels.split(",") if label.strip()]
    cram_labels = [label for label in values if label.startswith("cram::")]
    if len(cram_labels) > 1:
        raise BucketingError(
            "multiple cram selection labels: " + ", ".join(cram_labels)
        )
    if not cram_labels:
        return None, None
    label = cram_labels[0]
    value = label.removeprefix("cram::")
    if value == "skip":
        return "", "stand-down:label"
    if value not in {"full", "prplmesh", "lcm", "prplos"}:
        raise BucketingError(f"unknown cram selection label: {label}")
    return value, f"label:{value}"


def _resolve_board(
    manifest: Manifest,
    board: str,
    changed_paths: Sequence[str] | None,
    cram_components: str | None,
    labels: str,
) -> tuple[str, str]:
    if board not in manifest.selection.boards:
        raise BucketingError(f"unknown selection board: {board}")
    if cram_components is not None:
        return "", "stand-down:variable"
    label_selection, label_reason = _label_override(labels)
    if label_reason is not None:
        return label_selection or "", label_reason
    assert changed_paths is not None
    selection, drift = select_changed_components(manifest, board, changed_paths)
    if selection:
        return selection, "computed"
    return "", "DRIFT:coarse-match-without-component" if drift else "nothing-mapped"


def _empty_reason(alias: str, reason: str) -> str:
    return f"nothing selected for {alias}: {reason}"


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        manifest_path = resolve_manifest_path(args.test_root, args.manifest)
        manifest = load_manifest(manifest_path)
        _, label_reason = _label_override(args.labels)
        needs_diff = args.cram_components is None and label_reason is None
        changed = (
            _changed_paths(args.test_root, args.base_ref, args.head_ref)
            if needs_diff
            else None
        )
        boards = tuple(manifest.selection.boards) if args.report else (args.board,)
        results = []
        for board in boards:
            selection, reason = _resolve_board(
                manifest,
                board,
                changed,
                args.cram_components,
                args.labels,
            )
            results.append((board, selection, reason))
    except BucketingError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2

    if args.report:
        for board, selection, reason in results:
            alias = manifest.selection.boards[board].alias
            rendered = selection or "(empty)"
            print(f"{alias}: {rendered} [{reason}]")
            if not selection:
                print(_empty_reason(alias, reason), file=sys.stderr)
    else:
        board, selection, reason = results[0]
        print(selection)
        if not selection:
            alias = manifest.selection.boards[board].alias
            print(_empty_reason(alias, reason), file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
