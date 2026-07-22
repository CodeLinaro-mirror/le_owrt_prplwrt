#!/usr/bin/env python3
"""Shared test discovery and component bucketing for the cram suite."""

from __future__ import annotations

import glob
import os
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Dict, Iterable, List, Mapping, Sequence, Set, Tuple

import yaml


SCHEMA_VERSION = 1
COMPONENT_NAMES = ("lcm", "prplmesh")
RESERVED_NAMES = {"full", "prplos", "sanity", "smoke", "hw_only"}


class BucketingError(Exception):
    """An input or bucketing invariant is invalid."""


@dataclass(frozen=True)
class Manifest:
    """Validated component manifest and its expanded file matches."""

    path: Path
    sanity_patterns: Tuple[str, ...]
    component_patterns: Mapping[str, Tuple[str, ...]]
    smoke_patterns: Tuple[str, ...]
    hw_only_patterns: Tuple[str, ...]


@dataclass(frozen=True)
class ExpandedManifest:
    """Manifest globs expanded relative to a particular cram test root."""

    manifest: Manifest
    sanity_matches: Set[str]
    component_matches: Mapping[str, Set[str]]
    smoke_matches: Set[str]
    hw_only_matches: Set[str]


def _path_text(path: os.PathLike[str] | str) -> str:
    return os.fspath(path)


def resolve_manifest_path(test_root: Path, manifest: Path) -> Path:
    """Resolve a manifest path, with relative paths rooted at test_root."""

    if manifest.is_absolute():
        return manifest
    return test_root / manifest


def suite_roots(test_root: Path, board: str) -> List[Path]:
    """Return the five legacy CRAM_TEST_SUITE roots for one board."""

    board_path = PurePosixPath(board)
    if (
        not board
        or board_path.is_absolute()
        or len(board_path.parts) != 1
        or board_path.parts[0] in {".", ".."}
    ):
        raise BucketingError(f"invalid board directory name: {board!r}")

    return [
        test_root / "generic" / "acceleration-plan-components",
        test_root / board / "acceleration-plan-components",
        test_root / "generic" / "lcm",
        test_root / "generic",
        test_root / board,
    ]


def _walk_cram_directory(top: Path) -> Iterable[Path]:
    """Match cram 0.7's os.walk traversal and per-directory file ordering."""

    for root, _dirs, files in os.walk(_path_text(top)):
        root_path = Path(root)
        if root_path.name.startswith("."):
            continue
        for filename in sorted(files):
            if not filename.startswith(".") and filename.endswith(".t"):
                yield Path(os.path.normpath(os.path.join(root, filename)))


def collect_cram_tests(roots: Sequence[Path]) -> List[Path]:
    """Collect roots as cram 0.7 does, retaining the first duplicate only.

    Unlike cram 0.7's runner, this collector does not stat a selected test.
    A broken ``*.t`` symlink is therefore retained in the output.
    """

    ordered: List[Path] = []
    seen: Set[str] = set()

    for root in roots:
        if not os.path.lexists(_path_text(root)):
            raise BucketingError(f"suite root does not exist: {root}")

        candidates: Iterable[Path]
        if root.is_dir():
            candidates = _walk_cram_directory(root)
        else:
            candidates = (Path(os.path.normpath(_path_text(root))),)

        for candidate in candidates:
            identity = os.path.abspath(_path_text(candidate))
            if identity in seen:
                continue
            seen.add(identity)
            ordered.append(candidate)

    return ordered


def collect_board_tests(test_root: Path, board: str) -> List[Path]:
    """Collect the ordered legacy suite for board, failing on missing roots."""

    roots = suite_roots(test_root, board)
    missing = [root for root in roots if not root.is_dir()]
    if missing:
        rendered = "\n".join(f"  - {root}" for root in missing)
        raise BucketingError(f"required suite roots are missing:\n{rendered}")
    return collect_cram_tests(roots)


def _require_mapping(value: object, context: str) -> Mapping[str, object]:
    if not isinstance(value, dict):
        raise BucketingError(f"{context} must be a mapping")
    if any(not isinstance(key, str) for key in value):
        raise BucketingError(f"{context} keys must be strings")
    return value


def _validate_include_section(
    value: object, context: str, allowed_fields: Set[str]
) -> Tuple[str, ...]:
    section = _require_mapping(value, context)
    unknown = set(section) - allowed_fields
    if unknown:
        raise BucketingError(
            f"{context} has unknown fields: {', '.join(sorted(unknown))}"
        )

    include = section.get("include")
    if not isinstance(include, list) or not include:
        raise BucketingError(f"{context}.include must be a non-empty list")

    patterns: List[str] = []
    for index, pattern in enumerate(include):
        if not isinstance(pattern, str) or not pattern:
            raise BucketingError(
                f"{context}.include[{index}] must be a non-empty string"
            )
        posix_pattern = PurePosixPath(pattern)
        if posix_pattern.is_absolute() or ".." in posix_pattern.parts:
            raise BucketingError(
                f"{context}.include[{index}] must stay below the test root: "
                f"{pattern!r}"
            )
        patterns.append(pattern)
    return tuple(patterns)


def load_manifest(path: Path) -> Manifest:
    """Load and validate manifest structure without expanding its globs."""

    try:
        with path.open("r", encoding="utf-8") as stream:
            raw = yaml.safe_load(stream)
    except (OSError, UnicodeError) as error:
        raise BucketingError(f"cannot read manifest {path}: {error}") from error
    except yaml.YAMLError as error:
        raise BucketingError(f"cannot parse manifest {path}: {error}") from error

    document = _require_mapping(raw, "manifest")
    expected_top_level = {"version", "sanity", "components", "smoke", "hw_only"}
    missing = expected_top_level - set(document)
    unknown = set(document) - expected_top_level
    if missing:
        raise BucketingError(
            f"manifest is missing sections: {', '.join(sorted(missing))}"
        )
    if unknown:
        raise BucketingError(
            f"manifest has unknown sections: {', '.join(sorted(unknown))}"
        )
    if document["version"] != SCHEMA_VERSION:
        raise BucketingError(
            f"manifest version must be {SCHEMA_VERSION}, got "
            f"{document['version']!r}"
        )

    components = _require_mapping(document["components"], "components")
    component_names = set(components)
    if component_names != set(COMPONENT_NAMES):
        raise BucketingError(
            "components must contain exactly: " + ", ".join(COMPONENT_NAMES)
        )
    if component_names & RESERVED_NAMES:
        names = ", ".join(sorted(component_names & RESERVED_NAMES))
        raise BucketingError(f"reserved names cannot be explicit components: {names}")

    component_patterns: Dict[str, Tuple[str, ...]] = {}
    for name, value in components.items():
        component_patterns[name] = _validate_include_section(
            value,
            f"components.{name}",
            {"description", "include"},
        )
        section = _require_mapping(value, f"components.{name}")
        description = section.get("description")
        if description is not None and not isinstance(description, str):
            raise BucketingError(f"components.{name}.description must be a string")

    sanity_patterns = _validate_include_section(
        document["sanity"], "sanity", {"include"}
    )
    smoke_patterns = _validate_include_section(
        document["smoke"], "smoke", {"include"}
    )
    hw_only_patterns = _validate_include_section(
        document["hw_only"], "hw_only", {"include"}
    )

    return Manifest(
        path=path,
        sanity_patterns=sanity_patterns,
        component_patterns=component_patterns,
        smoke_patterns=smoke_patterns,
        hw_only_patterns=hw_only_patterns,
    )


def _relative_test_path(test_root: Path, path: Path) -> str:
    try:
        return path.relative_to(test_root).as_posix()
    except ValueError as error:
        raise BucketingError(f"test is outside test root {test_root}: {path}") from error


def discover_tests(test_root: Path, include_post: bool = False) -> List[Path]:
    """Discover all test paths below test_root, including broken symlinks."""

    if not test_root.is_dir():
        raise BucketingError(f"test root is not a directory: {test_root}")

    tests = list(_walk_cram_directory(test_root))
    if include_post:
        return tests
    return [
        path
        for path in tests
        if not _relative_test_path(test_root, path).startswith("post/")
    ]


def _expand_pattern(test_root: Path, pattern: str) -> Set[str]:
    native_pattern = os.path.join(_path_text(test_root), *pattern.split("/"))
    matches: Set[str] = set()
    for match in glob.iglob(native_pattern, recursive=True):
        match_path = Path(os.path.normpath(match))
        if match_path.name.startswith(".") or not match_path.name.endswith(".t"):
            continue
        if os.path.isdir(match):
            continue
        matches.add(_relative_test_path(test_root, match_path))
    return matches


def expand_manifest(test_root: Path, manifest: Manifest) -> ExpandedManifest:
    """Expand every manifest include glob and reject stale patterns."""

    stale: List[str] = []
    sanity_matches: Set[str] = set()
    for pattern in manifest.sanity_patterns:
        matches = _expand_pattern(test_root, pattern)
        if not matches:
            stale.append(f"sanity: {pattern}")
        sanity_matches.update(matches)

    component_matches: Dict[str, Set[str]] = {}
    for name, patterns in manifest.component_patterns.items():
        component_matches[name] = set()
        for pattern in patterns:
            matches = _expand_pattern(test_root, pattern)
            if not matches:
                stale.append(f"components.{name}: {pattern}")
            component_matches[name].update(matches)

    smoke_matches: Set[str] = set()
    for pattern in manifest.smoke_patterns:
        matches = _expand_pattern(test_root, pattern)
        if not matches:
            stale.append(f"smoke: {pattern}")
        smoke_matches.update(matches)

    hw_only_matches: Set[str] = set()
    for pattern in manifest.hw_only_patterns:
        matches = _expand_pattern(test_root, pattern)
        if not matches:
            stale.append(f"hw_only: {pattern}")
        hw_only_matches.update(matches)

    if stale:
        rendered = "\n".join(f"  - {item}" for item in stale)
        raise BucketingError(f"manifest include globs matched no tests:\n{rendered}")

    return ExpandedManifest(
        manifest=manifest,
        sanity_matches=sanity_matches,
        component_matches=component_matches,
        smoke_matches=smoke_matches,
        hw_only_matches=hw_only_matches,
    )


def partition_tests(
    tests: Sequence[Path], test_root: Path, expanded: ExpandedManifest
) -> Mapping[str, List[Path]]:
    """Partition ordered tests into sanity, explicit, and remainder buckets."""

    buckets: Dict[str, List[Path]] = {
        name: [] for name in expanded.manifest.component_patterns
    }
    buckets["sanity"] = []
    buckets["prplos"] = []

    overlaps: List[Tuple[str, Tuple[str, ...]]] = []
    for path in tests:
        relative = _relative_test_path(test_root, path)
        explicit = tuple(
            name
            for name, matches in expanded.component_matches.items()
            if relative in matches
        )
        is_sanity = relative in expanded.sanity_matches
        if is_sanity and explicit:
            overlaps.append((relative, ("sanity", *explicit)))
        elif len(explicit) > 1:
            overlaps.append((relative, explicit))
        elif is_sanity:
            buckets["sanity"].append(path)
        elif explicit:
            buckets[explicit[0]].append(path)
        else:
            buckets["prplos"].append(path)

    if overlaps:
        rendered = "\n".join(
            f"  - {path}: {', '.join(names)}" for path, names in overlaps
        )
        raise BucketingError(
            "tests match more than one partition bucket:\n" + rendered
        )
    return buckets


def select_component_tests(
    full: Sequence[Path],
    buckets: Mapping[str, List[Path]],
    components: Sequence[str],
) -> List[Path]:
    """Select an ordered component union with the sanity tests first."""

    allowed = {"full", "sanity", "prplmesh", "lcm", "prplos"}
    unknown = sorted(set(components) - allowed)
    if unknown:
        raise BucketingError(f"unknown components: {', '.join(unknown)}")
    if not components:
        raise BucketingError("at least one component is required")

    unique = tuple(dict.fromkeys(components))
    if "full" in unique:
        return list(full)
    if len(unique) == 1:
        component = unique[0]
        if component == "sanity":
            return list(buckets["sanity"])
        return list(buckets["sanity"] + buckets[component])

    selected = set(buckets["sanity"])
    for component in unique:
        if component != "sanity":
            selected.update(buckets[component])

    sanity = list(buckets["sanity"])
    sanity_set = set(sanity)
    return sanity + [path for path in full if path in selected and path not in sanity_set]


def render_test_paths(paths: Sequence[Path]) -> str:
    """Render ordered test paths for cram's command-line arguments."""

    if not paths:
        return ""
    return "".join(f"{os.path.normpath(_path_text(path))}\n" for path in paths)
