#!/usr/bin/env python3
#
# (!) This script is maintained at https://gitlab.com/prpl-foundation/tooling/cram-xunit-merger
#
import argparse
import sys
import typing
import xml.etree.ElementTree as ET
from pathlib import Path


def merge_xunit_files(input_files: typing.List[Path]) -> ET.ElementTree:
    """Merges multiple xUnit XML files into a single JUnit XML structure."""
    merged_root = ET.Element("testsuites")
    total_tests = 0
    total_failures = 0
    total_skipped = 0
    total_errors = 0
    total_time = 0.0
    merged_name = "unknown-suite"

    for file_path in input_files:
        try:
            tree = ET.parse(file_path)
            root = tree.getroot()

            original_name = root.get("name")
            if original_name:
                merged_name = original_name

            if root.tag == "testsuite":
                merged_root.append(root)

                total_tests += int(root.get("tests", 0))
                total_failures += int(root.get("failures", 0))
                total_skipped += int(root.get("skipped", 0))
                total_errors += int(root.get("errors", 0))
                total_time += float(root.get("time", 0.0))

            elif root.tag == "testsuites":
                for testsuite in root.findall("testsuite"):
                    merged_root.append(testsuite)

                    total_tests += int(testsuite.get("tests", 0))
                    total_failures += int(testsuite.get("failures", 0))
                    total_skipped += int(testsuite.get("skipped", 0))
                    total_errors += int(testsuite.get("errors", 0))
                    total_time += float(testsuite.get("time", 0.0))

            else:
                print(
                    f"Error: Processing file {file_path} failed - Unexpected root element '{root.tag}'",
                    file=sys.stderr,
                )
                sys.exit(1)

        except ET.ParseError as e:
            print(
                f"Error: Processing file {file_path} failed - XML Parse Error: {e}",
                file=sys.stderr,
            )
            sys.exit(1)
        except FileNotFoundError:
            print(
                f"Error: Input file {file_path} not found.",
                file=sys.stderr,
            )
            sys.exit(1)
        except Exception as e:
            print(
                f"Error: Processing file {file_path} failed - Unexpected error: {e}",
                file=sys.stderr,
            )
            sys.exit(1)

    merged_root.set("name", merged_name)
    merged_root.set("tests", str(total_tests))
    merged_root.set("failures", str(total_failures))
    merged_root.set("disabled", str(total_skipped))
    merged_root.set("errors", str(total_errors))
    merged_root.set("time", f"{total_time:.6f}")

    return ET.ElementTree(merged_root)


def main():
    parser = argparse.ArgumentParser(
        description="Merge multiple xUnit XML files into a single JUnit XML report.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "input_files",
        metavar="FILE",
        nargs="+",
        type=Path,
        help="Paths to one or more xUnit XML files to merge.",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=None,
        help="Path to the output JUnit XML file. If not specified, output to stdout.",
    )

    cleaned_argv = [arg.strip() for arg in sys.argv[1:]]
    args = parser.parse_args(cleaned_argv)
    merged_tree = merge_xunit_files(args.input_files)
    xml_declaration = '<?xml version="1.0" encoding="UTF-8"?>\n'

    if args.output:
        try:
            with open(args.output, "wb") as f:
                f.write(xml_declaration.encode("utf-8"))
                merged_tree.write(f, encoding="UTF-8", xml_declaration=False)
            print(f"Successfully merged results into {args.output}")
        except OSError as e:
            print(f"Error writing to output file {args.output}: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        sys.stdout.buffer.write(xml_declaration.encode("utf-8"))
        merged_tree.write(sys.stdout.buffer, encoding="UTF-8", xml_declaration=False)


if __name__ == "__main__":
    main()
