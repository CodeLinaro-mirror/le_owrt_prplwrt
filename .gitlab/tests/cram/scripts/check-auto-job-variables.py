#!/usr/bin/env python3
"""Check that automatic CRAM jobs preserve board-specific variables."""

from __future__ import annotations

import argparse
import copy
import sys
from pathlib import Path
from typing import Mapping, Sequence

import yaml


BOARDS = {
    "Omnia": "turris-omnia",
    "Haze": "prpl-haze",
    "OSPv2": "mxl25641-hdk-6",
    "Freedom": "wnc-freedom",
    "Mozart": "arcadyan-mozart",
    "Valyrian": "nokia-valyrian",
}


def _yaml_value(loader: yaml.SafeLoader, node: yaml.Node) -> object:
    if isinstance(node, yaml.SequenceNode):
        return loader.construct_sequence(node)
    if isinstance(node, yaml.MappingNode):
        return loader.construct_mapping(node)
    return loader.construct_scalar(node)


class _GitLabLoader(yaml.SafeLoader):
    pass


_GitLabLoader.add_multi_constructor(
    "!", lambda loader, _tag, node: _yaml_value(loader, node)
)


def _load(path: Path) -> Mapping[str, object]:
    try:
        loaded = yaml.load(path.read_text(encoding="utf-8"), Loader=_GitLabLoader)
    except (OSError, UnicodeError, yaml.YAMLError) as error:
        raise ValueError(f"cannot load {path}: {error}") from error
    if not isinstance(loaded, dict):
        raise ValueError(f"{path} must contain a YAML mapping")
    return loaded


def _deep_merge(
    base: Mapping[str, object], overlay: Mapping[str, object]
) -> dict[str, object]:
    merged = copy.deepcopy(dict(base))
    for key, value in overlay.items():
        if isinstance(value, dict) and isinstance(merged.get(key), dict):
            merged[key] = _deep_merge(merged[key], value)
        else:
            merged[key] = copy.deepcopy(value)
    return merged


def _parents(definition: Mapping[str, object], name: str) -> list[str]:
    parents = definition.get("extends", [])
    if isinstance(parents, str):
        return [parents]
    if not isinstance(parents, list) or any(
        not isinstance(parent, str) for parent in parents
    ):
        raise ValueError(f"{name} has invalid extends")
    return parents


def _resolve(
    definitions: Mapping[str, object],
    name: str,
    cache: dict[str, dict[str, object]],
    stack: tuple[str, ...] = (),
) -> dict[str, object]:
    if name in cache:
        return copy.deepcopy(cache[name])
    if name in stack:
        raise ValueError(f"extends cycle: {' -> '.join((*stack, name))}")
    raw = definitions.get(name)
    if not isinstance(raw, dict):
        raise ValueError(f"missing YAML definition {name}")

    resolved: dict[str, object] = {}
    for parent in _parents(raw, name):
        resolved = _deep_merge(
            resolved, _resolve(definitions, parent, cache, (*stack, name))
        )
    resolved = _deep_merge(
        resolved, {key: value for key, value in raw.items() if key != "extends"}
    )
    cache[name] = resolved
    return copy.deepcopy(resolved)


def _variables(definition: Mapping[str, object], name: str) -> dict[str, object]:
    variables = definition.get("variables", {})
    if not isinstance(variables, dict):
        raise ValueError(f"{name} has invalid variables")
    return {
        key: value
        for key, value in variables.items()
        if key != "COMPONENT"
    }


def _wip_tag_override_allowed(
    definitions: Mapping[str, object],
    alias: str,
    actual: object,
    expected: object,
) -> bool:
    if alias != "Freedom":
        return False
    build = definitions.get(
        "build test qca_ipq95xx prpl cellular security thread", {}
    )
    script = build.get("script", []) if isinstance(build, dict) else []
    script_text = "\n".join(str(command) for command in script)
    return (
        "jobs/15472255004/artifacts" in script_text
        and actual == ["dut-wnc-freedom-sfl-prio"]
        and expected == ["dut-wnc-freedom-sfl"]
    )


def check_repository(repository: Path) -> None:
    paths = [
        repository / ".gitlab-ci.yml",
        repository / ".gitlab/testbed.yml",
        *(
            repository / f".gitlab/testbed/{board}.yml"
            for board in BOARDS.values()
        ),
    ]
    definitions: dict[str, object] = {}
    for path in paths:
        definitions.update(_load(path))

    cache: dict[str, dict[str, object]] = {}
    failures = []
    for alias in BOARDS:
        auto_name = f"cram {alias} [auto]"
        full_name = f"cram {alias} [full]"
        auto = _resolve(definitions, auto_name, cache)
        full = _resolve(definitions, full_name, cache)
        actual = _variables(auto, auto_name)
        expected = _variables(full, full_name)
        if actual != expected:
            missing = sorted(set(expected) - set(actual))
            extra = sorted(set(actual) - set(expected))
            changed = sorted(
                key
                for key in set(actual) & set(expected)
                if actual[key] != expected[key]
            )
            failures.append(
                f"{alias}: variable mismatch "
                f"(missing={missing}, extra={extra}, changed={changed})"
            )

        actual_tags = auto.get("tags")
        expected_tags = full.get("tags")
        if actual_tags != expected_tags and not _wip_tag_override_allowed(
            definitions, alias, actual_tags, expected_tags
        ):
            failures.append(
                f"{alias}: tags differ: {actual_tags!r} != {expected_tags!r}"
            )

    if failures:
        raise ValueError("\n".join(failures))


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repository",
        type=Path,
        default=Path(__file__).resolve().parents[4],
        help="prplos repository root",
    )
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        check_repository(args.repository.resolve())
    except ValueError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    print("auto job variables: all six boards match their full bucket")
    return 0


if __name__ == "__main__":
    sys.exit(main())
