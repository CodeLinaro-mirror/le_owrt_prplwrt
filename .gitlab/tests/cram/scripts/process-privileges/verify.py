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

    actual_children_by_name: dict[str, list[ActualProcess]] = {}
    for child in actual.children:
        actual_children_by_name.setdefault(child.name, []).append(child)

    for child_spec in spec.children:
        actual_matches = actual_children_by_name.get(child_spec.name, [])
        if not actual_matches:
            if not child_spec.optional:
                errors.append(f"{path}: missing required child process '{child_spec.name}'")
        else:
            for actual_child in actual_matches:
                verify_process(child_spec, actual_child, f"{path} > {child_spec.name}", errors)

    if not spec.ignore_child:
        spec_children_by_name: dict[str, ProcessSpec] = {c.name: c for c in spec.children}
        for actual_child in actual.children:
            if actual_child.name not in spec_children_by_name:
                errors.append(
                    f"{path}: unexpected child process '{actual_child.name}' "
                    f"(id={actual_child.id}, caps={actual_child.caps})"
                )


def verify_all(
    specs: dict[str, ProcessSpec],
    roots: list[ActualProcess],
    errors: list[str],
) -> None:
    actual_by_name: dict[str, list[ActualProcess]] = {}
    for proc in roots:
        actual_by_name.setdefault(proc.name, []).append(proc)

    for spec_name, spec in specs.items():
        actual_matches = actual_by_name.get(spec_name, [])
        if not actual_matches:
            if not spec.optional:
                errors.append(f"missing required process '{spec_name}'")
        else:
            for actual_proc in actual_matches:
                verify_process(spec, actual_proc, spec_name, errors)

    for proc in roots:
        if proc.name not in specs:
            errors.append(
                f"unexpected root process '{proc.name}' "
                f"(id={proc.id}, caps={proc.caps})"
            )


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
