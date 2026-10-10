#!/usr/bin/env python3
"""san-pmreboots.py: report every reboot that ProcessMonitor.MaxReboots=0 blocked, with the test name.

The sanitize profile sets ProcessMonitor.MaxReboots=0, so amx-processmonitor (v0.8.2, src/test.c,
pm_execute_action_reboot) refuses every REBOOT fail action and logs, at ERROR level (sahtrace zone
processmonitor, rendered as "[x]" in syslog):
  The test failure should trigger a reboot, but this test has caused too many reboots! (NUM >= MAX)
The message does not name the test and the action is dropped without touching NumFailActions. This
tool finds each such line and names the test.

Inputs, from the artifacts dir DIR (files that are missing are skipped):
  DIR/logread-prereboot.txt   `logread` of boot 1, saved by sanitize/010-san-broadcast.t (boot 1 syslog is
                              lost at the reboot test)
  DIR/logread-full.txt        `logread` of boot 2 (post collector sanitize/post/90-san-collect.t); scanned too
  DIR/pm-tests-prereboot.json `ba-cli --json 'ProcessMonitor.Test.?'` before the reboot (candidates)
  DIR/run.log, cram.xml, manifest.json   map the syslog time to the cram test that was running (best effort)

How the test name is derived, in this order:
  1. log: pm_check_test logs "Test '<name>' failed too often|for too long, executing action" (WARNING) right
     before pm_execute_action, which runs synchronously on the same thread; the nearest such line in front of
     the blocked line (same source tag, at most 12 such lines back and 5 s earlier) names the test. A
     "Stopping the service: /etc/init.d/<name> stop" line in between is used as a cross-check.
  2. candidates: no such line (log level, truncated log): every test of pm-tests-prereboot.json with
     FailAction REBOOT that is failing (Health Bad, or FailedSince set, not 0001-01-01) and that did not start
     failing after the blocked line. The snapshot is taken later than the log line, so this is a heuristic.
  3. otherwise test=?
How the cram test is derived: run start = timestamp of cram.xml minus the offset of the run.log line
"cram: running N tests" (fallback: manifest.json finished_epoch minus the last run.log offset). A run.log line
"[+Ns] cmd | <test>.t: passed|failed|skipped" ends a test; the test that was running at the syslog time is the one
whose end follows it (the first one starts at the "cram: running" line). Assumes the DUT clock is UTC and in
step with the host (QEMU), so the result can be one test off near a boundary. cram=? when unmapped.

Output: one line per blocked reboot on stdout
  PM-REBOOT-BLOCKED <syslog time> test=<name|candidates:a,b|?> cram=<cram test|?> (<num>>=<max>)
and DIR/san-pmreboots.md (or OUT/). Exit 0 always: this is a finding report, not a verdict.
Usage: san-pmreboots.py DIR [-o OUT]
"""
import argparse
import datetime
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

BLOCKED = re.compile(r"The test failure should trigger a reboot, but this test has caused too many reboots! \((\d+) >= (\d+)\)")
NAMED = re.compile(r"Test '([^']+)' failed (too often|for too long), executing action")
STOPSVC = re.compile(r"Stopping the service: /etc/init\.d/(\S+) stop")
PM_TAG = "amx-processmonitor"
MAX_BACK_LINES = 12
MAX_BACK_SECONDS = 5

MONTHS = {m: i for i, m in enumerate("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec".split(), 1)}
TS_SYSLOG = re.compile(r"^\s*(\d{4}) ([A-Z][a-z]{2}) +(\d{1,2}) (\d\d):(\d\d):(\d\d)\b")
TS_LOGREAD = re.compile(r"^\s*[A-Z][a-z]{2} ([A-Z][a-z]{2}) +(\d{1,2}) (\d\d):(\d\d):(\d\d) (\d{4})\b")
TS_ISO = re.compile(r"^\s*(\d{4})-(\d\d)-(\d\d)[T ](\d\d):(\d\d):(\d\d)")
UTC = datetime.timezone.utc

SOURCES = (("logread-prereboot.txt", "boot 1 (prereboot)"), ("logread-full.txt", "boot 2 (full)"))


def read_text(path):
    try:
        with open(path, "rb") as fh:
            return fh.read().decode("utf-8", errors="replace")
    except OSError:
        return None


def parse_line_time(line):
    """Syslog time of a log line as an aware datetime (the DUT clock is taken as UTC), or None."""
    try:
        m = TS_SYSLOG.match(line)
        if m and m.group(2) in MONTHS:
            return datetime.datetime(int(m.group(1)), MONTHS[m.group(2)], int(m.group(3)), int(m.group(4)), int(m.group(5)), int(m.group(6)), tzinfo=UTC)
        m = TS_LOGREAD.match(line)
        if m and m.group(1) in MONTHS:
            return datetime.datetime(int(m.group(6)), MONTHS[m.group(1)], int(m.group(2)), int(m.group(3)), int(m.group(4)), int(m.group(5)), tzinfo=UTC)
        m = TS_ISO.match(line)
        if m:
            return datetime.datetime(*[int(g) for g in m.groups()], tzinfo=UTC)
    except ValueError:
        pass
    return None


def parse_iso(s):
    """ISO time of the datamodel (2026-10-10T13:02:16Z) -> aware datetime, or None (also for 0001-01-01)."""
    if not isinstance(s, str) or not s or s.startswith("0001-01-01"):
        return None
    try:
        d = datetime.datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError:
        return None
    return d if d.tzinfo else d.replace(tzinfo=UTC)


def fmt_time(dt, raw):
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ") if dt else "?(" + raw[:24].strip() + ")"


# ---- datamodel candidates ----

def collect_tests(obj, key, out):
    if isinstance(obj, dict):
        if "FailAction" in obj and ("Name" in obj or key):
            d = dict(obj)
            d.setdefault("Name", key)
            out.append(d)
            return
        for k, v in obj.items():
            collect_tests(v, k, out)
    elif isinstance(obj, list):
        for v in obj:
            collect_tests(v, key, out)


def load_tests(path):
    """Test instances from the `ba-cli --json` output; tolerant about echoed prompt/command lines."""
    txt = read_text(path)
    if txt is None:
        return None
    docs = []
    try:
        docs.append(json.loads(txt))
    except ValueError:
        dec = json.JSONDecoder()
        for m in re.finditer(r"^[\[{]", txt, re.M):
            try:
                docs.append(dec.raw_decode(txt[m.start():])[0])
            except ValueError:
                continue
    out = []
    for d in docs:
        collect_tests(d, None, out)
    return out


def candidates(tests, t):
    """REBOOT tests that are failing, minus those that began failing after the blocked line."""
    keep, late = [], []
    for d in tests or []:
        if str(d.get("FailAction", "")).upper() != "REBOOT":
            continue
        since = parse_iso(d.get("FailedSince"))
        if not (str(d.get("Health", "")) == "Bad" or since):
            continue
        if t and since and since > t:
            late.append(d)
        else:
            keep.append(d)
    return keep, late


# ---- cram mapping ----

def load_timeline(art):
    """(run_start aware datetime or None, start_off, [(end_off, test)], note)."""
    txt = read_text(os.path.join(art, "run.log"))
    if txt is None:
        return None
    start_off, last_off, ends = None, None, []
    for line in txt.split("\n"):
        m = re.match(r"^\[\+\s*([0-9.]+)s\] (\S+) \| (.*)$", line)
        if not m:
            continue
        off, kind, rest = float(m.group(1)), m.group(2), m.group(3)
        last_off = off
        if kind != "cmd":
            continue
        if start_off is None and re.match(r"^cram: running \d+ tests?\b", rest):
            start_off = off
        mt = re.match(r"^(\S+\.t): (passed|failed|skipped)\s*$", rest)
        if mt:
            ends.append((off, mt.group(1)))
    run_start, how = None, ""
    try:
        suite = ET.parse(os.path.join(art, "cram.xml")).getroot()
        suite = suite if suite.tag == "testsuite" else suite.find("testsuite")
        ts = parse_iso(suite.get("timestamp")) if suite is not None else None
        if ts and start_off is not None:
            run_start, how = ts - datetime.timedelta(seconds=start_off), "cram.xml timestamp"
    except (OSError, ET.ParseError):
        pass
    if run_start is None and last_off is not None:
        try:
            with open(os.path.join(art, "manifest.json")) as fh:
                fe = json.load(fh).get("finished_epoch")
            if fe:
                run_start, how = datetime.datetime.fromtimestamp(float(fe), UTC) - datetime.timedelta(seconds=last_off), "manifest.json finished_epoch"
        except (OSError, ValueError, AttributeError):
            pass
    if start_off is None and ends:
        start_off = 0.0
    return run_start, start_off, ends, how


def map_cram(tl, t):
    """Return (cram test or None, note)."""
    if not tl:
        return None, "no run.log"
    run_start, start_off, ends, how = tl
    if t is None:
        return None, "no syslog time"
    if run_start is None:
        return None, "no time anchor (cram.xml/manifest.json)"
    off = (t - run_start).total_seconds()
    prev = start_off
    for end, name in ends:
        if prev - 1.0 <= off <= end + 1.0:
            return name.replace(".gitlab/tests/cram/", ""), "run offset %.0f s, anchor %s" % (off, how)
        prev = end
    return None, "run offset %.0f s is outside the test timeline (anchor %s)" % (off, how)


# ---- scan ----

def scan_log(text, label, tests, tl):
    lines = text.split("\n")
    events = []
    for i, line in enumerate(lines):
        m = BLOCKED.search(line)
        if not m:
            continue
        t = parse_line_time(line)
        ev = {"source": label, "raw": line.strip(), "time": t, "time_s": fmt_time(t, line),
              "num": int(m.group(1)), "max": int(m.group(2)), "names": [], "how": "", "cands": [], "notes": []}
        tagged = PM_TAG in line
        seen, stop_name, j = 0, None, i - 1
        while j >= 0 and seen < MAX_BACK_LINES:
            prev = lines[j]
            j -= 1
            if (PM_TAG in prev) != tagged:
                continue
            seen += 1
            if BLOCKED.search(prev):
                break
            s = STOPSVC.search(prev)
            if s and stop_name is None:
                stop_name = s.group(1)
            n = NAMED.search(prev)
            if n:
                pt = parse_line_time(prev)
                if t and pt and (t - pt).total_seconds() > MAX_BACK_SECONDS:
                    ev["notes"].append("log line for '%s' is %.0f s earlier, not used" % (n.group(1), (t - pt).total_seconds()))
                    break
                ev["names"] = [n.group(1)]
                ev["how"] = "log (%s)" % n.group(2)
                if stop_name and stop_name != n.group(1):
                    ev["notes"].append("'Stopping the service' line names %s" % stop_name)
                break
        if not ev["names"] and stop_name:
            ev["names"], ev["how"] = [stop_name], "log (Stopping the service)"
        if not ev["names"] and tests is not None:
            keep, late = candidates(tests, t)
            ev["cands"] = keep
            ev["names"] = sorted(set(str(d.get("Name")) for d in keep))
            ev["how"] = "candidates (datamodel snapshot)"
            if late:
                ev["notes"].append("not candidates, FailedSince after the log line: " + ", ".join(sorted(str(d.get("Name")) for d in late)))
            if not keep:
                ev["how"] = "none (no failing REBOOT test in the snapshot)"
        elif not ev["names"]:
            ev["how"] = "none (no naming log line, no datamodel snapshot for this log)"
        ev["cram"], ev["cram_note"] = map_cram(tl, t)
        events.append(ev)
    return events


def scan(art):
    """Return {'events': [...], 'sources': [(label, path, found)], 'tests_file': bool}."""
    tests = load_tests(os.path.join(art, "pm-tests-prereboot.json"))
    tl = load_timeline(art)
    res = {"events": [], "sources": [], "tests_file": tests is not None, "ntests": len(tests or [])}
    seen = set()
    for fname, label in SOURCES:
        txt = read_text(os.path.join(art, fname))
        if txt is None:
            continue
        # The snapshot is from boot 1, so it only names tests for the boot 1 log.
        evs = scan_log(txt, label, tests if fname == "logread-prereboot.txt" else None, tl)
        res["sources"].append((label, fname, len(evs)))
        for ev in evs:
            if ev["raw"] in seen:
                continue
            seen.add(ev["raw"])
            res["events"].append(ev)
    return res


def test_field(ev):
    if not ev["names"]:
        return "?"
    if ev["how"].startswith("candidates"):
        return "candidates:" + ",".join(ev["names"])
    return ev["names"][0]


def format_line(ev):
    return "PM-REBOOT-BLOCKED %s test=%s cram=%s (%d>=%d)" % (ev["time_s"], test_field(ev), ev["cram"] or "?", ev["num"], ev["max"])


def render_md(res, art):
    md = ["# Blocked process-monitor reboots", "",
          "ProcessMonitor.MaxReboots is 0 in the sanitize profile, so amx-processmonitor drops every REBOOT fail action "
          "and logs `too many reboots! (num >= max)` without the test name. Each such line is one test that would "
          "have rebooted the DUT.", "",
          "Scanned: " + ("; ".join("`%s` (%s): %d" % (f, lab, n) for lab, f, n in res["sources"]) or "no logread file found"),
          "Datamodel snapshot `pm-tests-prereboot.json`: " + ("%d tests" % res["ntests"] if res["tests_file"] else "missing"), ""]
    if not res["events"]:
        md += ["No blocked reboot found.", ""]
        return md
    md += ["| # | syslog time | test | how | cram test running | num>=max | source |", "|---|---|---|---|---|---|---|"]
    for i, ev in enumerate(res["events"], 1):
        md.append("| %d | %s | %s | %s | %s | %d>=%d | %s |" % (
            i, ev["time_s"], test_field(ev).replace("|", "\\|"), ev["how"], ev["cram"] or "?", ev["num"], ev["max"], ev["source"]))
    md += ["", "## Lines", "", "```"] + [format_line(ev) for ev in res["events"]] + ["```", "", "## Details", ""]
    for i, ev in enumerate(res["events"], 1):
        md.append("%d. `%s`" % (i, ev["raw"][:300]))
        md.append("   - test: %s; cram: %s" % (test_field(ev), ev["cram_note"]))
        for n in ev["notes"]:
            md.append("   - " + n)
        for d in ev["cands"]:
            md.append("   - candidate `%s`: Health=%s FailedSince=%s LastCheck=%s Subject=%s" % (
                d.get("Name"), d.get("Health"), d.get("FailedSince"), d.get("LastCheck"), d.get("Subject")))
    md += ["", "Method: the test name comes from the `Test '<name>' failed ..., executing action` log line before the "
           "blocked line when present, else from the failing REBOOT tests of the pre-reboot datamodel snapshot (heuristic, "
           "all candidates are listed). The cram test is the one running at the syslog time per run.log (best effort, "
           "DUT clock taken as UTC and in step with the host).", ""]
    return md


def main():
    ap = argparse.ArgumentParser(prog="san-pmreboots.py", description="Report reboots blocked by ProcessMonitor.MaxReboots.")
    ap.add_argument("artifacts")
    ap.add_argument("-o", "--out", help="output dir for san-pmreboots.md (default: the artifacts dir)")
    a = ap.parse_args()
    res = scan(a.artifacts)
    if not res["sources"]:
        sys.stderr.write("san-pmreboots: no logread-prereboot.txt or logread-full.txt in %s, nothing to do\n" % a.artifacts)
        return 0
    for ev in res["events"]:
        print(format_line(ev))
    out = a.out or a.artifacts
    os.makedirs(out, exist_ok=True)
    path = os.path.join(out, "san-pmreboots.md")
    with open(path, "w") as fh:
        fh.write("\n".join(render_md(res, a.artifacts)) + "\n")
    sys.stderr.write("san-pmreboots: %d blocked reboot(s); %s\n" % (len(res["events"]), path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
