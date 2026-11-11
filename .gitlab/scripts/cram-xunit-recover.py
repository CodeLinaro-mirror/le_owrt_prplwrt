#!/usr/bin/env python3
"""Recover missing cram xUnit reports from the combined verbose results log."""

import argparse
from pathlib import Path
import re
import xml.etree.ElementTree as ET


# Cram flushes "path.t: " before running a test. On interruption the shell's
# diagnostic can follow on that same line. Diff lines start with whitespace,
# '+' or '-', so they must not be mistaken for test progress.
TEST_LINE = re.compile(r"^([^\s+-].*?\.t): (.*)$")


def read_results(log, post_paths):
    results = {"main": [], "post": []}
    try:
        source = log.open(encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return results
    with source:
        for line in source:
            match = TEST_LINE.match(line.rstrip("\n"))
            if not match:
                continue
            name, status = match.groups()
            path = Path(name)
            suite = "post" if any(
                root == path or root in path.parents for root in post_paths
            ) else "main"
            if status == "empty":
                status = "skipped"
            if status not in ("passed", "failed", "skipped"):
                status = "error"
            results[suite].append((name, status))
    return results


def write_missing(output, suite, results, log):
    if output.exists():
        return
    if not results:
        results = [(f"cram-{suite}", "error")]
        interruption = "Suite was interrupted or did not start; no test line was recorded"
    else:
        interruption = "Suite was interrupted before this test completed"
    root = ET.Element("testsuite", name=f"cram-{suite}", tests=str(len(results)))
    for status, attribute in (("failed", "failures"), ("skipped", "skipped"), ("error", "errors")):
        root.set(attribute, str(sum(result == status for _, result in results)))
    for name, status in results:
        case = ET.SubElement(root, "testcase", classname=name, name=Path(name).name)
        if status == "failed":
            ET.SubElement(case, "failure", message="cram reported failure").text = (
                f"See {log.name} for the test output and diff."
            )
        elif status == "skipped":
            ET.SubElement(case, "skipped")
        elif status == "error":
            ET.SubElement(case, "error", message=interruption).text = interruption
    # Exclusive creation also preserves a report that appeared after the check.
    try:
        with output.open("xb") as destination:
            ET.ElementTree(root).write(destination, encoding="utf-8", xml_declaration=True)
    except FileExistsError:
        return
    print(f"Recovered {output}: {len(results)} tests")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path)
    parser.add_argument("main_output", type=Path)
    parser.add_argument("post_output", type=Path)
    parser.add_argument("--post-suite", nargs="+", type=Path, required=True,
                        help="Post-suite directories or test files passed to cram")
    args = parser.parse_args()
    if args.main_output.exists() and args.post_output.exists():
        return
    results = read_results(args.log, args.post_suite)
    write_missing(args.main_output, "main", results["main"], args.log)
    write_missing(args.post_output, "post", results["post"], args.log)


if __name__ == "__main__":
    main()
