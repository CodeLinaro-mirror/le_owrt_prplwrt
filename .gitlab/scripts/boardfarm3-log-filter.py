#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 prpl Foundation
# SPDX-License-Identifier: GPL-2.0-only
"""Show the boardfarm3 progress in the job log, keep the full log in a file.

Usage: pytest ... 2>&1 >&3 | boardfarm3-log-filter.py <log file>

The script reads the boardfarm3 and labgrid log from stdin and appends
every byte of it to the log file. To stdout, the job log, it copies:
- the INFO and higher lines of the boardfarm3-prplos plugin;
- the WARNING and higher lines of all loggers.

A plugin line "<name>: started" opens a GitLab collapsible section and the
matching "<name>: finished in ..." or "<name>: failed after ..." line
closes it, so the job page shows the duration of each phase. Console
traffic and DEBUG lines stay in the log file only, which keeps the job
log small.
"""

import re
import sys
import time

_RECORD = re.compile(
    r"^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d,\d+ (?P<level>[A-Z]+) +- "
    r"(?P<message>.*?)\s+\((?P<logger>[^:() ]+):[^()]*\)$"
)
_PHASE = re.compile(
    r"^(?P<name>.+): (?P<event>started|finished in .*|failed after .*)$"
)
_PLUGIN = "boardfarm3_prplos"
_SHOWN = {"INFO", "WARNING", "ERROR", "CRITICAL"}
_ALWAYS_SHOWN = {"WARNING", "ERROR", "CRITICAL"}


def _section_start(section: str, header: str) -> str:
    return f"\x1b[0Ksection_start:{int(time.time())}:{section}\r\x1b[0K{header}"


def _section_end(section: str) -> str:
    return f"\x1b[0Ksection_end:{int(time.time())}:{section}\r\x1b[0K"


def main() -> int:
    """Copy stdin to the log file, and the progress lines to stdout.

    :return: exit code
    """
    if len(sys.argv) != 2:  # noqa: PLR2004
        sys.stderr.write(__doc__)
        return 2
    open_sections: list[tuple[str, str]] = []
    count = 0
    with open(sys.argv[1], "ab") as log:  # noqa: PTH123
        for raw in sys.stdin.buffer:
            log.write(raw)
            log.flush()
            line = raw.decode("utf-8", errors="replace").rstrip("\r\n")
            record = _RECORD.match(line)
            if record is None:
                continue
            level = record["level"]
            plugin = record["logger"].startswith(_PLUGIN)
            if not (level in _ALWAYS_SHOWN or (plugin and level in _SHOWN)):
                continue
            phase = _PHASE.match(record["message"]) if plugin else None
            if phase and phase["event"] == "started":
                count += 1
                section = f"boardfarm3_phase_{count}"
                open_sections.append((phase["name"], section))
                print(_section_start(section, line), flush=True)
                continue
            print(line, flush=True)
            if phase:
                for index in range(len(open_sections) - 1, -1, -1):
                    if open_sections[index][0] == phase["name"]:
                        for _, section in reversed(open_sections[index:]):
                            print(_section_end(section), flush=True)
                        del open_sections[index:]
                        break
    for _, section in reversed(open_sections):
        print(_section_end(section), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
