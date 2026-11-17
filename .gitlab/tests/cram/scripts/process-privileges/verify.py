#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import re
import shlex
import signal
import subprocess
import sys
import time
import yaml
from dataclasses import dataclass, field
from pathlib import Path


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
    exe: str = ""
    cwd: str = ""
    cmdline: str = ""
    parent: "ActualProcess | None" = field(default=None, repr=False)
    children: list["ActualProcess"] = field(default_factory=list)


@dataclass
class VerifyError:
    """A mismatch, and optionally the process to show as context in the report."""

    message: str
    process: ActualProcess | None = None

    def __str__(self) -> str:
        return f"ERROR: {self.message}"

    def report(self) -> str:
        lines = [str(self)]
        if self.process:
            lines += format_context(self.process)
        return "\n".join(lines)


CONTEXT_INDENT = "   "


def describe(proc: ActualProcess) -> str:
    return (
        f"{proc.name} (pid={proc.pid}, id={proc.id}, caps={proc.caps}, "
        f"exe={proc.exe or '-'}, cwd={proc.cwd or '-'})"
    )


def format_context(proc: ActualProcess) -> list[str]:
    """The ancestors of proc, then proc and all its descendants with their command line."""
    ancestors: list[ActualProcess] = []
    parent = proc.parent
    while parent and parent not in ancestors:
        ancestors.insert(0, parent)
        parent = parent.parent

    lines = [CONTEXT_INDENT * level + describe(a) for level, a in enumerate(ancestors)]

    def subtree(p: ActualProcess, level: int) -> None:
        indent = CONTEXT_INDENT * level
        lines.append(indent + describe(p))
        if p.cmdline:
            lines.append(f"{indent}{CONTEXT_INDENT}- cmd: {p.cmdline}")
        for child in sorted(p.children, key=lambda c: (c.name, c.pid)):
            subtree(child, level + 1)

    subtree(proc, len(ancestors))
    return lines


def parse_yaml_spec(yaml_path: str) -> dict[str, ProcessSpec]:
    with open(yaml_path) as f:
        data = yaml.safe_load(f)

    def parse_entries(entries: dict | None) -> dict[str, ProcessSpec]:
        return {name: parse_entry(name, entry or {}) for name, entry in (entries or {}).items()}

    def parse_entry(name: str, entry: dict) -> ProcessSpec:
        return ProcessSpec(
            name=name,
            id=entry.get("id", ""),
            caps=entry.get("caps", ""),
            optional=entry.get("optional", False),
            ignore_child=entry.get("ignore_child", False),
            children=list(parse_entries(entry.get("child")).values()),
        )

    return parse_entries(data)


def unescape_field(value: str) -> str:
    """Undo the octal escaping of whitespace done by the collector ("-" is empty)."""
    if value == "-":
        return ""
    return re.sub(r"\\([0-7]{3})", lambda m: chr(int(m.group(1), 8)), value)


def parse_process_list(lines: list[str]) -> dict[int, ActualProcess]:
    """Parse '--collect list' output.

    Each line is "pid ppid name user:group caps [exe cwd [cmdline...]]", where name,
    exe and cwd have their whitespace escaped, and the command line is the rest of
    the line.
    """
    procs: dict[int, ActualProcess] = {}
    for line in lines:
        parts = line.strip().split(maxsplit=7)
        if len(parts) < 5:
            continue
        parts += [""] * (8 - len(parts))
        pid, ppid = int(parts[0]), int(parts[1])
        procs[pid] = ActualProcess(
            pid=pid,
            ppid=ppid,
            name=unescape_field(parts[2]),
            id=parts[3],
            caps=parts[4],
            exe=unescape_field(parts[5]),
            cwd=unescape_field(parts[6]),
            cmdline=parts[7],
        )

    for proc in procs.values():
        parent = procs.get(proc.ppid)
        if parent and parent.pid != proc.pid:
            proc.parent = parent
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
    errors: list[VerifyError],
) -> None:
    if spec.id != actual.id:
        errors.append(VerifyError(f"{path}: expected id '{spec.id}', got '{actual.id}'"))

    if normalize_caps(spec.caps) != normalize_caps(actual.caps):
        errors.append(VerifyError(f"{path}: expected caps '{spec.caps}', got '{actual.caps}'"))

    actual_children_by_name: dict[str, list[ActualProcess]] = {}
    for child in actual.children:
        actual_children_by_name.setdefault(child.name, []).append(child)

    for child_spec in spec.children:
        actual_matches = actual_children_by_name.get(child_spec.name, [])
        if not actual_matches:
            if not child_spec.optional:
                errors.append(VerifyError(f"{path}: missing required child process '{child_spec.name}'"))
        else:
            for actual_child in actual_matches:
                verify_process(child_spec, actual_child, f"{path} > {child_spec.name}", errors)

    if not spec.ignore_child:
        spec_children_by_name: dict[str, ProcessSpec] = {c.name: c for c in spec.children}
        for actual_child in actual.children:
            if actual_child.name not in spec_children_by_name:
                errors.append(VerifyError(
                    f"{path}: unexpected child process '{actual_child.name}' "
                    f"(id={actual_child.id}, caps={actual_child.caps})",
                    actual_child,
                ))


def verify_all(
    specs: dict[str, ProcessSpec],
    roots: list[ActualProcess],
    errors: list[VerifyError],
) -> None:
    actual_by_name: dict[str, list[ActualProcess]] = {}
    for proc in roots:
        actual_by_name.setdefault(proc.name, []).append(proc)

    for spec_name, spec in specs.items():
        actual_matches = actual_by_name.get(spec_name, [])
        if not actual_matches:
            if not spec.optional:
                errors.append(VerifyError(f"missing required process '{spec_name}'"))
        else:
            for actual_proc in actual_matches:
                verify_process(spec, actual_proc, spec_name, errors)

    for proc in roots:
        if proc.name not in specs:
            errors.append(VerifyError(
                f"unexpected root process '{proc.name}' "
                f"(id={proc.id}, caps={proc.caps})"
            ))


class Remote:
    """Runs the collector on the DUT, over CRAM_REMOTE_COMMAND and CRAM_REMOTE_COPY."""

    LOCAL_SCRIPT = Path(__file__).resolve().parent / "target" / "process-privileges.lua"
    REMOTE_SCRIPT = "/tmp/process-privileges.lua"

    def __init__(self, lua_bin: str) -> None:
        self.lua_bin = lua_bin
        self.command = shlex.split(os.environ.get("CRAM_REMOTE_COMMAND") or "ssh root@192.168.1.1")
        self.copy_command = shlex.split(os.environ.get("CRAM_REMOTE_COPY") or "scp")
        self.host = os.environ.get("TARGET_LAN_IP") or ""
        if not self.host:
            match = re.search(r".*@(\S*)", " ".join(self.command))
            self.host = match.group(1) if match else ""
        if not self.host:
            raise SystemExit("TARGET_LAN_IP or a remote command naming the host is required")
        self.copied = False

    def copy(self) -> None:
        # The collector is copied rather than fed on stdin, because a
        # CRAM_REMOTE_COMMAND with "ssh -n" would deliver an empty script.
        result = subprocess.run(
            self.copy_command + [str(self.LOCAL_SCRIPT), f"root@{self.host}:{self.REMOTE_SCRIPT}"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if result.returncode != 0:
            raise CollectError(f"Failed to copy {self.LOCAL_SCRIPT} to {self.host}")
        self.copied = True

    def run(self, collect_type: str) -> subprocess.CompletedProcess:
        if not self.copied:
            self.copy()
        return subprocess.run(
            self.command + [f"{self.lua_bin} {self.REMOTE_SCRIPT} {collect_type}"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )

    def cleanup(self) -> None:
        if self.copied:
            subprocess.run(
                self.command + [f"rm -f '{self.REMOTE_SCRIPT}'"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            self.copied = False


class CollectError(Exception):
    pass


def collect_list(remote: Remote) -> list[str]:
    result = remote.run("list")
    if result.returncode != 0:
        raise CollectError(f"{result.stderr}ERROR: failed to collect the process list")
    return result.stdout.splitlines()


def verify_lines(specs: dict[str, ProcessSpec], lines: list[str]) -> list[str]:
    """Verify a process list, return one report per error: the error line followed
    by the processes involved, as found in this same snapshot."""
    procs = parse_process_list(lines)
    errors: list[VerifyError] = []
    verify_all(specs, find_root_processes(procs), errors)
    return [error.report() for error in errors]


def verify_remote(specs: dict[str, ProcessSpec], remote: Remote, timeout: int, interval: int, verbose: bool) -> list[str]:
    """Collect and verify until the tree matches or the timeout expires.

    Returns the errors of the last attempt, empty on success.
    """
    start = time.monotonic()
    attempts = 0
    while True:
        attempts += 1
        try:
            errors = verify_lines(specs, collect_list(remote))
        except CollectError as e:
            errors = [str(e)]
        if not errors:
            return []

        elapsed = int(time.monotonic() - start)
        if elapsed >= timeout:
            break
        if verbose:
            print(f"attempt {attempts} failed after {elapsed}s:", file=sys.stderr)
            print("\n".join(errors), file=sys.stderr)
        time.sleep(interval)

    if timeout > 0:
        errors.append(f"ERROR: process privileges did not match after {attempts} attempts in {elapsed}s")
    return errors


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Collect the process tree from the remote hgw and verify it against the rules, "
        "or only print it with --collect.",
        epilog="The remote hgw is selected with CRAM_REMOTE_COMMAND (default \"ssh root@192.168.1.1\"), "
        "CRAM_REMOTE_COPY (default \"scp\") and TARGET_LAN_IP, when the host cannot be derived "
        "from CRAM_REMOTE_COMMAND.",
    )
    parser.add_argument(
        "rules",
        nargs="?",
        default=str(Path(__file__).resolve().parent / "rules.yml"),
        help="expected process tree (default: rules.yml next to this script)",
    )
    parser.add_argument(
        "-c",
        "--collect",
        nargs="?",
        const="tree",
        choices=["tree", "list", "color"],
        help="only print the processes and their privileges: as a tree (default), "
        "a list with pid and ppid, or a colored tree",
    )
    parser.add_argument(
        "-I",
        "--input",
        type=argparse.FileType("r"),
        help="verify a process list collected earlier with '--collect list' ('-' for stdin) "
        "instead of collecting it from the remote hgw",
    )
    parser.add_argument(
        "-t",
        "--timeout",
        type=int,
        default=int(os.environ.get("VERIFY_TIMEOUT", 0)),
        help="retry until this many seconds have passed, to ride out short-lived processes "
        "(default: $VERIFY_TIMEOUT or 0, a single attempt)",
    )
    parser.add_argument(
        "-i",
        "--interval",
        type=int,
        default=int(os.environ.get("VERIFY_INTERVAL", 2)),
        help="seconds to wait between attempts (default: $VERIFY_INTERVAL or 2)",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="print the errors of every failed attempt, also when a later attempt succeeds",
    )
    parser.add_argument("--lua", default="lua", help="lua binary on the remote hgw (default: lua)")
    return parser.parse_args()


def main():
    args = parse_args()

    def terminate(signum, frame):
        raise SystemExit(130)

    signal.signal(signal.SIGTERM, terminate)
    signal.signal(signal.SIGHUP, terminate)

    if args.input:
        errors = verify_lines(parse_yaml_spec(args.rules), args.input.read().splitlines())
    else:
        remote = Remote(args.lua)
        try:
            if args.collect:
                try:
                    result = remote.run(args.collect)
                except CollectError as e:
                    raise SystemExit(str(e))
                sys.stdout.write(result.stdout)
                sys.stderr.write(result.stderr)
                sys.exit(result.returncode)
            errors = verify_remote(parse_yaml_spec(args.rules), remote, args.timeout, args.interval, args.verbose)
        except KeyboardInterrupt:
            sys.exit(130)
        finally:
            remote.cleanup()

    if errors:
        print("\n".join(errors), file=sys.stderr)
        sys.exit(1)
    print("OK: All process privileges match expected configuration")


if __name__ == "__main__":
    main()
