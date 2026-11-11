#!/usr/bin/env python3
from __future__ import annotations

import sys
import yaml
from dataclasses import dataclass, field


@dataclass
class ProcessSpec:
    name: str
    id: str
    caps: str
    optional: bool = False
    ignore_child: bool = False
    children: list["ProcessSpec"] = field(default_factory=list)


@dataclass
class ActualProcess:
    pid: int
    ppid: int
    name: str
    id: str
    caps: str
    children: list["ActualProcess"] = field(default_factory=list)


def parse_yaml_spec(yaml_path: str) -> dict[str, ProcessSpec]:
    with open(yaml_path) as f:
        data = yaml.safe_load(f)

    def parse_entry(entry: dict) -> ProcessSpec:
        return ProcessSpec(
            name=entry["cmd"],
            id=entry.get("id", ""),
            caps=entry.get("caps", ""),
            optional=entry.get("optional", False),
            ignore_child=entry.get("ignore_child", False),
            children=[parse_entry(c) for c in (entry.get("child") or [])],
        )

    specs = {}
    for entry in data:
        spec = parse_entry(entry)
        specs[spec.name] = spec
    return specs


def parse_process_list(lines: list[str]) -> dict[int, ActualProcess]:
    procs: dict[int, ActualProcess] = {}
    for line in lines:
        line = line.strip()
        if not line:
            continue
        parts = line.split()
        if len(parts) < 5:
            continue
        pid = int(parts[0])
        ppid = int(parts[1])
        name = parts[2]
        id_ = parts[3]
        caps = parts[4]
        procs[pid] = ActualProcess(pid=pid, ppid=ppid, name=name, id=id_, caps=caps)

    for proc in procs.values():
        parent = procs.get(proc.ppid)
        if parent and parent.pid != proc.pid:
            parent.children.append(proc)

    return procs


def find_root_processes(procs: dict[int, ActualProcess]) -> list[ActualProcess]:
    roots = []
    for proc in procs.values():
        if proc.ppid not in procs or proc.ppid == proc.pid:
            roots.append(proc)
    return roots


def find_spec(name: str, specs: dict[str, ProcessSpec]) -> ProcessSpec | None:
    """Return the spec for a process name.

    Interpreter processes are named "<interpreter>:<script>" (e.g. "sh:prplmesh_utils"). A rule
    for the exact name wins; otherwise the rule for the bare interpreter ("sh") applies, so a
    specific script can get its own rule without affecting every other script.
    """
    spec = specs.get(name)
    if spec is None and ":" in name:
        spec = specs.get(name.split(":", 1)[0])
    return spec


def normalize_caps(caps: str) -> set[str]:
    if caps == "full":
        return {"full"}
    if caps == "none":
        return set()
    return set(c.strip() for c in caps.split(",") if c.strip())


def verify_process(
    spec: ProcessSpec,
    actual: ActualProcess,
    path: str,
    errors: list[str],
) -> None:
    if spec.id != actual.id:
        errors.append(f"{path}: expected id '{spec.id}', got '{actual.id}'")

    if normalize_caps(spec.caps) != normalize_caps(actual.caps):
        errors.append(f"{path}: expected caps '{spec.caps}', got '{actual.caps}'")

    spec_children_by_name: dict[str, ProcessSpec] = {c.name: c for c in spec.children}
    matched_specs: set[str] = set()
    for actual_child in actual.children:
        child_spec = find_spec(actual_child.name, spec_children_by_name)
        if child_spec is not None:
            matched_specs.add(child_spec.name)
            verify_process(child_spec, actual_child, f"{path} > {actual_child.name}", errors)
        elif not spec.ignore_child:
            errors.append(
                f"{path}: unexpected child process '{actual_child.name}' "
                f"(id={actual_child.id}, caps={actual_child.caps})"
            )

    for child_spec in spec.children:
        if child_spec.name not in matched_specs and not child_spec.optional:
            errors.append(f"{path}: missing required child process '{child_spec.name}'")


def verify_all(
    specs: dict[str, ProcessSpec],
    roots: list[ActualProcess],
    errors: list[str],
) -> None:
    matched_specs: set[str] = set()
    for proc in roots:
        spec = find_spec(proc.name, specs)
        if spec is not None:
            matched_specs.add(spec.name)
            verify_process(spec, proc, proc.name, errors)
        else:
            errors.append(
                f"unexpected root process '{proc.name}' "
                f"(id={proc.id}, caps={proc.caps})"
            )

    for spec_name, spec in specs.items():
        if spec_name not in matched_specs and not spec.optional:
            errors.append(f"missing required process '{spec_name}'")


def main():
    if len(sys.argv) < 2:
        print("Usage: verify-process-privileges.py <expected.yml>", file=sys.stderr)
        sys.exit(1)

    yaml_path = sys.argv[1]
    specs = parse_yaml_spec(yaml_path)

    lines = sys.stdin.read().splitlines()
    procs = parse_process_list(lines)
    roots = find_root_processes(procs)

    errors: list[str] = []
    verify_all(specs, roots, errors)

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
    else:
        print("OK: All process privileges match expected configuration")
        sys.exit(0)


if __name__ == "__main__":
    main()
