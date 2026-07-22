#!/usr/bin/env python3
"""Run the offline CI-9 phase-1 selection fixture battery."""

from __future__ import annotations

import importlib.util
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

SCRIPT_DIR = Path(__file__).resolve().parent
REPOSITORY = SCRIPT_DIR.parents[3]
TEST_ROOT = REPOSITORY / ".gitlab/tests/cram"
MANIFEST_PATH = TEST_ROOT / "components.yml"
FIXTURE_PATH = SCRIPT_DIR / "fixtures/selection-cases.yml"
RESOLVER = SCRIPT_DIR / "resolve-changed-components.py"
AUTO_VARIABLES_GUARD = SCRIPT_DIR / "check-auto-job-variables.py"

sys.path.insert(0, str(SCRIPT_DIR))
from cram_component_bucketing import (  # noqa: E402
    BucketingError,
    load_manifest,
    select_changed_components,
)


def check(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def run(command: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, check=True, text=True, **kwargs)


def git(repository: Path, *arguments: str) -> str:
    result = run(
        ["git", "-C", str(repository), *arguments],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return result.stdout.strip()


def commit_paths(repository: Path, paths: list[str], message: str) -> str:
    for relative in paths:
        path = repository / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(message + "\n", encoding="utf-8")
    git(repository, "add", ".")
    git(repository, "commit", "-qm", message)
    return git(repository, "rev-parse", "HEAD")


def invoke(
    repository: Path,
    base: str,
    head: str,
    *arguments: str,
    manifest: Path | None = None,
    cwd: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    test_root = repository / ".gitlab/tests/cram"
    command = [
        str(RESOLVER),
        "--test-root",
        str(test_root),
        "--manifest",
        str(manifest or test_root / "components.yml"),
        "--base-ref",
        base,
        "--head-ref",
        head,
        *arguments,
    ]
    return subprocess.run(command, cwd=cwd, text=True, capture_output=True)


def load_lint_module() -> object:
    path = SCRIPT_DIR / "check-component-coverage.py"
    spec = importlib.util.spec_from_file_location("coverage_lint", path)
    check(spec is not None and spec.loader is not None, "cannot load lint module")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    manifest = load_manifest(MANIFEST_PATH)
    fixture = yaml.safe_load(FIXTURE_PATH.read_text(encoding="utf-8"))
    check(fixture["schema"] == 1, "fixture schema")
    cases = fixture["matrix"]
    check(
        {case["glob"] for case in cases}
        == {mapping.glob for mapping in manifest.selection.paths},
        "matrix fixture does not cover every selection row",
    )
    matrix_assertions = 0
    for case in cases:
        for board in manifest.selection.boards:
            actual, _ = select_changed_components(manifest, board, [case["path"]])
            expected = case["expected"].get(board, "")
            check(actual == expected, f"matrix case {case['glob']} on {board}")
            matrix_assertions += 1
    print(f"1 matrix rows: PASS ({len(cases)} rows, {matrix_assertions} board results)")

    for case in fixture["by_test"]:
        actual, _ = select_changed_components(manifest, case["board"], [case["path"]])
        check(actual == case["expected"], f"by-test case {case['path']}")
    print(f"2 by-test: PASS ({len(fixture['by_test'])} cases)")

    selection, _ = select_changed_components(
        manifest, "wnc-freedom", ["profiles/lcm.yml", "profiles/feed_prplmesh.yml"]
    )
    check(selection == "prplmesh,lcm", "ordered union")
    reverse, _ = select_changed_components(
        manifest, "wnc-freedom", ["profiles/feed_prplmesh.yml", "profiles/lcm.yml"]
    )
    check(reverse == selection, "path order changed union")
    print("3 unions: PASS (2 path orders)")

    all_components, _ = select_changed_components(
        manifest,
        "wnc-freedom",
        ["profiles/feed_prplmesh.yml", "profiles/lcm.yml", "profiles/feed_prplos.yml"],
    )
    full_path, _ = select_changed_components(manifest, "wnc-freedom", ["Makefile"])
    check(all_components == full_path == "full", "full collapse")
    print("4 collapse: PASS (all buckets and full path)")

    with tempfile.TemporaryDirectory(prefix="ci9-phase1-", dir="/tmp") as temporary:
        repository = Path(temporary)
        (repository / ".gitlab/tests/cram").mkdir(parents=True)
        (repository / ".gitlab/tests/cram/components.yml").write_text(
            MANIFEST_PATH.read_text(encoding="utf-8"), encoding="utf-8"
        )
        git(repository, "init", "-q")
        git(repository, "config", "user.name", "CI-9 fixture")
        git(repository, "config", "user.email", "ci9@example.invalid")
        git(repository, "add", ".")
        git(repository, "commit", "-qm", "base")
        base = git(repository, "rev-parse", "HEAD")
        union_head = commit_paths(
            repository,
            ["profiles/feed_prplmesh.yml", "profiles/lcm.yml"],
            "union",
        )

        variable = invoke(
            repository,
            "bad-ref",
            union_head,
            "--board",
            "wnc-freedom",
            "--cram-components",
            "none",
        )
        variable_with_label = invoke(
            repository,
            "bad-ref",
            union_head,
            "--board",
            "wnc-freedom",
            "--cram-components",
            "lcm",
            "--labels",
            "cram::full",
        )
        skip = invoke(
            repository,
            "bad-ref",
            union_head,
            "--board",
            "wnc-freedom",
            "--labels",
            "cram::skip",
        )
        label = invoke(
            repository,
            "bad-ref",
            union_head,
            "--board",
            "wnc-freedom",
            "--labels",
            "cram::lcm",
        )
        double = invoke(
            repository,
            base,
            union_head,
            "--board",
            "wnc-freedom",
            "--labels",
            "cram::lcm,cram::skip",
        )
        check(
            variable.returncode == 0 and "stand-down:variable" in variable.stderr,
            "variable precedence",
        )
        check(
            variable_with_label.returncode == 0
            and "stand-down:variable" in variable_with_label.stderr,
            "variable must override label",
        )
        check(
            skip.returncode == 0 and "stand-down:label" in skip.stderr,
            "skip precedence",
        )
        check(label.returncode == 0 and label.stdout.strip() == "lcm", "label override")
        check(double.returncode != 0, "double label must fail")
        print(
            "5 precedence: PASS "
            "(variable, none, variable>label, skip, label, double-label)"
        )

        report = invoke(repository, base, union_head, "--report")
        check(report.returncode == 0, "report mode failed")
        check(len(report.stdout.splitlines()) == 6, "report must show six boards")
        print("5 report mode: PASS (6 boards)")

        unmapped = invoke(repository, base, union_head, "--board", "turris-omnia")
        drift_head = commit_paths(
            repository, [".gitlab/tests/cram/generic/README"], "drift"
        )
        drift = invoke(repository, union_head, drift_head, "--board", "wnc-freedom")
        check("nothing-mapped" in unmapped.stderr, "nothing-mapped reason")
        check("DRIFT:" in drift.stderr, "drift reason")
        check(
            variable.returncode
            == skip.returncode
            == unmapped.returncode
            == drift.returncode
            == 0,
            "empty exit codes",
        )
        print("6 empty reasons: PASS (variable, label, unmapped, drift; all green)")

        bad_base = invoke(repository, "bad-ref", drift_head, "--board", "wnc-freedom")
        unknown = invoke(repository, base, drift_head, "--board", "unknown")
        malformed = repository / "malformed.yml"
        malformed.write_text("version: 1\n", encoding="utf-8")
        bad_manifest = invoke(
            repository,
            base,
            drift_head,
            "--board",
            "wnc-freedom",
            manifest=malformed,
        )
        relative = subprocess.run(
            [
                str(RESOLVER),
                "--test-root",
                ".gitlab/tests/cram",
                "--manifest",
                "components.yml",
                "--base-ref",
                base,
                "--board",
                "wnc-freedom",
            ],
            cwd=repository.parent,
            text=True,
            capture_output=True,
        )
        check(
            all(
                result.returncode != 0
                for result in (bad_base, unknown, bad_manifest, relative)
            ),
            "red error paths",
        )
        print("7 errors: PASS (bad base, matrix, board, relative non-repo)")

        git(repository, "checkout", "-qb", "fork", base)
        fork_head = commit_paths(repository, ["profiles/feed_prplos.yml"], "fork")
        git(repository, "checkout", "--detach", "-q", drift_head)
        fork = invoke(repository, fork_head, drift_head, "--board", "wnc-freedom")
        detached = invoke(repository, base, "HEAD", "--board", "wnc-freedom")
        check(fork.returncode == detached.returncode == 0, "fork/detached refs")
        print("8 refs: PASS (fork-shaped base and detached HEAD)")

        lint = load_lint_module()
        (repository / "profiles/zzz-ci9-probe.yml").write_text(
            "---\n", encoding="utf-8"
        )
        try:
            lint._check_profile_completeness(repository, manifest)
        except BucketingError as error:
            check("zzz-ci9-probe.yml" in str(error), "profile lint diagnostic")
        else:
            raise AssertionError("uncategorized profile passed lint")

    print("10 lint fixture: PASS (uncategorized profile rejected)")
    run([str(AUTO_VARIABLES_GUARD), "--repository", str(REPOSITORY)])
    print("11 auto variables: PASS (six auto/full pairs match)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
