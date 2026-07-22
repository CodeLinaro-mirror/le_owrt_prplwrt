#!/usr/bin/env python3
"""Shared test discovery and component bucketing for the cram suite."""

from __future__ import annotations

import glob
import os
import re
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Dict, Iterable, List, Mapping, Sequence, Set, Tuple

import yaml


SCHEMA_VERSION = 1
COMPONENT_NAMES = ("lcm", "prplmesh")
RESERVED_NAMES = {"full", "prplos", "sanity", "smoke", "hw_only"}
SELECTION_COMPONENT_ORDER = ("prplmesh", "lcm", "prplos")


class BucketingError(Exception):
    """An input or bucketing invariant is invalid."""


@dataclass(frozen=True)
class SelectionBoard:
    """A DUT board available to diff-based selection."""

    name: str
    alias: str
    priority: bool


@dataclass(frozen=True)
class SelectionPath:
    """One repository path mapping in the selection matrix."""

    glob: str
    boards: Tuple[str, ...]
    component: str


@dataclass(frozen=True)
class Selection:
    """Validated diff-based selection data."""

    boards: Mapping[str, SelectionBoard]
    paths: Tuple[SelectionPath, ...]


@dataclass(frozen=True)
class Manifest:
    """Validated component manifest and its expanded file matches."""

    path: Path
    sanity_patterns: Tuple[str, ...]
    component_patterns: Mapping[str, Tuple[str, ...]]
    smoke_patterns: Tuple[str, ...]
    hw_only_patterns: Tuple[str, ...]
    selection: Selection


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


def _glob_regex(pattern: str) -> re.Pattern[str]:
    """Compile a repository glob where ``*`` never crosses a slash."""

    expression = ""
    index = 0
    while index < len(pattern):
        character = pattern[index]
        if character != "*":
            expression += re.escape(character)
            index += 1
            continue
        if pattern[index : index + 2] == "**":
            index += 2
            if index < len(pattern) and pattern[index] == "/":
                expression += "(?:.*/)?"
                index += 1
            else:
                expression += ".*"
        else:
            expression += "[^/]*"
            index += 1
    return re.compile(f"^{expression}$")


def path_matches_glob(path: str, pattern: str) -> bool:
    """Return whether a POSIX repository path matches a validated glob."""

    return bool(_glob_regex(pattern).fullmatch(path))


def _validate_selection(value: object) -> Selection:
    selection = _require_mapping(value, "selection")
    unknown = set(selection) - {"schema", "boards", "paths"}
    missing = {"schema", "boards", "paths"} - set(selection)
    if missing:
        raise BucketingError(
            f"selection is missing fields: {', '.join(sorted(missing))}"
        )
    if unknown:
        raise BucketingError(
            f"selection has unknown fields: {', '.join(sorted(unknown))}"
        )
    if selection["schema"] != SCHEMA_VERSION:
        raise BucketingError(
            f"selection.schema must be {SCHEMA_VERSION}, got "
            f"{selection['schema']!r}"
        )

    raw_boards = _require_mapping(selection["boards"], "selection.boards")
    if not raw_boards:
        raise BucketingError("selection.boards must not be empty")
    boards: Dict[str, SelectionBoard] = {}
    aliases: Set[str] = set()
    for name, raw_board in raw_boards.items():
        board = _require_mapping(raw_board, f"selection.boards.{name}")
        if set(board) != {"alias", "priority"}:
            raise BucketingError(
                f"selection.boards.{name} must contain alias and priority"
            )
        alias = board["alias"]
        priority = board["priority"]
        if not isinstance(alias, str) or not alias:
            raise BucketingError(f"selection.boards.{name}.alias must be a string")
        if alias in aliases:
            raise BucketingError(f"duplicate selection board alias: {alias}")
        if not isinstance(priority, bool):
            raise BucketingError(f"selection.boards.{name}.priority must be a boolean")
        aliases.add(alias)
        boards[name] = SelectionBoard(name, alias, priority)

    raw_paths = selection["paths"]
    if not isinstance(raw_paths, list) or not raw_paths:
        raise BucketingError("selection.paths must be a non-empty list")
    paths: List[SelectionPath] = []
    seen_globs: Set[str] = set()
    allowed_components = {"full", "prplmesh", "lcm", "prplos", "by-test", "noop"}
    for index, raw_path in enumerate(raw_paths):
        context = f"selection.paths[{index}]"
        path = _require_mapping(raw_path, context)
        if set(path) - {"glob", "boards", "component"}:
            raise BucketingError(f"{context} has unknown fields")
        if {"glob", "component"} - set(path):
            raise BucketingError(f"{context} requires glob and component")
        pattern = path["glob"]
        component = path["component"]
        if not isinstance(pattern, str) or not pattern:
            raise BucketingError(f"{context}.glob must be a non-empty string")
        posix_pattern = PurePosixPath(pattern)
        if (
            posix_pattern.is_absolute()
            or ".." in posix_pattern.parts
            or "\\" in pattern
            or any(character in pattern for character in "?[]")
        ):
            raise BucketingError(f"{context}.glob is invalid: {pattern!r}")
        _glob_regex(pattern)
        if pattern in seen_globs:
            raise BucketingError(f"duplicate selection glob: {pattern}")
        seen_globs.add(pattern)
        if component not in allowed_components:
            raise BucketingError(f"{context}.component is invalid: {component!r}")

        raw_targets = path.get("boards")
        if component == "noop":
            if raw_targets is not None:
                raise BucketingError(f"{context} noop must not name boards")
            targets: Tuple[str, ...] = ()
        elif raw_targets == "priority":
            targets = tuple(name for name, board in boards.items() if board.priority)
            if not targets:
                raise BucketingError(f"{context} priority selects no boards")
        elif isinstance(raw_targets, list) and raw_targets:
            if any(not isinstance(target, str) for target in raw_targets):
                raise BucketingError(f"{context}.boards must contain strings")
            targets = tuple(raw_targets)
            if len(targets) != len(set(targets)):
                raise BucketingError(f"{context}.boards contains duplicates")
            missing_targets = set(targets) - set(boards)
            if missing_targets:
                raise BucketingError(
                    f"{context}.boards names unknown boards: "
                    f"{', '.join(sorted(missing_targets))}"
                )
        else:
            raise BucketingError(f"{context}.boards must be priority or a list")
        paths.append(SelectionPath(pattern, targets, component))

    return Selection(boards=boards, paths=tuple(paths))


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
    expected_top_level = {
        "version",
        "sanity",
        "components",
        "smoke",
        "hw_only",
        "selection",
    }
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
    smoke_patterns = _validate_include_section(document["smoke"], "smoke", {"include"})
    hw_only_patterns = _validate_include_section(
        document["hw_only"], "hw_only", {"include"}
    )
    selection = _validate_selection(document["selection"])

    return Manifest(
        path=path,
        sanity_patterns=sanity_patterns,
        component_patterns=component_patterns,
        smoke_patterns=smoke_patterns,
        hw_only_patterns=hw_only_patterns,
        selection=selection,
    )


def _relative_test_path(test_root: Path, path: Path) -> str:
    try:
        return path.relative_to(test_root).as_posix()
    except ValueError as error:
        raise BucketingError(
            f"test is outside test root {test_root}: {path}"
        ) from error


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
        raise BucketingError("tests match more than one partition bucket:\n" + rendered)
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
    return sanity + [
        path for path in full if path in selected and path not in sanity_set
    ]


def classify_changed_test(manifest: Manifest, repository_path: str) -> str | None:
    """Classify one changed cram test path for automatic selection."""

    prefix = ".gitlab/tests/cram/"
    if not repository_path.startswith(prefix):
        raise BucketingError(f"not a cram test path: {repository_path}")
    relative = repository_path[len(prefix) :]
    if not relative.endswith(".t"):
        return None
    if relative.startswith("post/") or any(
        path_matches_glob(relative, pattern) for pattern in manifest.sanity_patterns
    ):
        return "prplos"
    explicit = [
        component
        for component, patterns in manifest.component_patterns.items()
        if any(path_matches_glob(relative, pattern) for pattern in patterns)
    ]
    if len(explicit) > 1:
        raise BucketingError(
            f"changed test matches multiple components: {repository_path}: "
            f"{', '.join(explicit)}"
        )
    return explicit[0] if explicit else "prplos"


def select_changed_components(
    manifest: Manifest, board: str, changed_paths: Sequence[str]
) -> tuple[str, bool]:
    """Resolve changed paths to one board's ordered component selection."""

    if board not in manifest.selection.boards:
        raise BucketingError(f"unknown selection board: {board}")
    selected: Set[str] = set()
    matched_for_board = False
    for changed_path in changed_paths:
        for mapping in manifest.selection.paths:
            if not path_matches_glob(changed_path, mapping.glob):
                continue
            if board not in mapping.boards:
                continue
            matched_for_board = True
            component = mapping.component
            if component == "by-test":
                component = classify_changed_test(manifest, changed_path)
                if component is None:
                    continue
            if component == "full":
                return "full", False
            if component != "noop":
                selected.add(component)

    if set(SELECTION_COMPONENT_ORDER).issubset(selected):
        return "full", False
    ordered = [name for name in SELECTION_COMPONENT_ORDER if name in selected]
    return ",".join(ordered), matched_for_board and not ordered


def render_test_paths(paths: Sequence[Path]) -> str:
    """Render ordered test paths for cram's command-line arguments."""

    if not paths:
        return ""
    return "".join(f"{os.path.normpath(_path_text(path))}\n" for path in paths)
