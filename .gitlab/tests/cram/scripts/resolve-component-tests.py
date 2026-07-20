#!/usr/bin/env python3
"""Resolve the ordered cram test list for a board and component."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Sequence

from cram_component_bucketing import (
    BucketingError,
    collect_board_tests,
    expand_manifest,
    load_manifest,
    partition_tests,
    render_test_paths,
    resolve_manifest_path,
)


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--test-root",
        required=True,
        type=Path,
        help="cram test root containing generic/ and board directories",
    )
    parser.add_argument(
        "--manifest",
        required=True,
        type=Path,
        help="manifest path (relative paths are resolved below --test-root)",
    )
    parser.add_argument("--board", required=True, help="board directory name")
    parser.add_argument(
        "--component",
        required=True,
        choices=("full", "sanity", "prplmesh", "lcm", "prplos"),
    )
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        manifest_path = resolve_manifest_path(args.test_root, args.manifest)
        manifest = load_manifest(manifest_path)
        expanded = expand_manifest(args.test_root, manifest)
        full = collect_board_tests(args.test_root, args.board)
        buckets = partition_tests(full, args.test_root, expanded)
        if args.component == "full":
            selected = full
        elif args.component == "sanity":
            selected = buckets["sanity"]
        else:
            selected = buckets["sanity"] + buckets[args.component]
    except BucketingError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2

    sys.stdout.write(render_test_paths(selected))
    return 0


if __name__ == "__main__":
    sys.exit(main())
