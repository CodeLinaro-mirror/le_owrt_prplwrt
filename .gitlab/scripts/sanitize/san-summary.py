#!/usr/bin/env python3
"""san-summary.py: one summary file (markdown) and one JUnit XML for a sanitizer run.

Inputs, all from the run's artifacts dir DIR unless a flag says otherwise:
  DIR/iter-NN/cram.xml       JUnit of each [full] iteration of the loop (run-loop.sh); a run without iter-NN
                             directories uses DIR/cram.xml. A test is judged over all iterations: it fails when
                             it fails in any of them, and the summary shows the result of each iteration.
  DIR/iter-NN/cram-post.xml  JUnit of the post tests; the collector sanitize/post/90-san-collect.t must be there
  DIR/san-metrics.txt        verdict of the SANRSS metrics-log check (serial-check.py)
  DIR/san-console-index.txt  SANREPORT/SANSTATS/SANDEATH index (serial-check.py console-index)
  DIR/san-findings.tsv       output of san-report.py (--findings FILE)
  DIR/san-unparsed.txt       report files that san-report.py could not parse (any line is a failure)
  DIR/san-rss-trend.md       output of san-rss-trend.py, copied into the summary
Optional:
  --lab-list FILE            lab-network-tests.txt: tests that could not run their real code path without the outside
                             network. Their results are listed apart.
  --known FILE               known findings: id-or-key <TAB> open|waived [<TAB> note]. A finding that is not
                             listed is "new", "open" is a known unfixed one (both are JUnit failures),
                             "waived" passes (kept visible in the summary).
  --baseline-musl FILE       artifacts/fail.tsv, --baseline-glibc FILE artifacts/fail.tsv (status, test, ...):
                             classify cram results as in artifacts/tests.tsv:
                               a  fails now and in the musl baseline (lab or network; does not count)
                               b  fails now and in the glibc baseline only (glibc-only)
                               c  fails now, passes in both baselines (new under the sanitizer)
                               d  passes now, failed in a baseline
  --symbolize-summary FILE   OUTDIR/symbolize-summary.tsv of san-symbolize.py (adds a symbolization row)
  --shim-regress-log FILE    sanitize-build/shim-regress.log of the build job (adds a shim-regress row: pass, fail,
                             or skip when bwrap could not run there)
Cram failures are classified: lab-network (--lab-list), config (005-build-config.t: the sanitize profile has
another build configuration), slow (the failure text mentions a time out: "slow under sanitizer") and
other. None of them is a sanitizer finding and none fails the job; the sanitizer findings and the harness
checks do.
Output (-o OUT, default DIR): OUT/san-summary.md, OUT/san-junit.xml and OUT/cram-merged.xml (the cram and
post results of all iterations, for the GitLab test report). JUnit testcases:
  suite sanitizer-findings   one per unique finding: failure = new or open
  suite sanitizer-harness    metrics-log, SAN-DEATH, report-dir, plus symbolization, shim-regress and cram-classes
                             when their inputs are given. A missing input file is a FAILURE, never a clean result.
  suite sanitizer-pm-reboots only when DIR/logread-prereboot.txt or DIR/logread-full.txt exists: one testcase
                             (class sanitizer.finding, failure type finding) per reboot that ProcessMonitor.MaxReboots
                             blocked, found by san-pmreboots.py; the markdown gets a section
                             'Blocked process-monitor reboots'. Absent files add nothing. With iteration directories
                             every iter-NN directory is scanned.
Usage: san-summary.py --artifacts DIR [--findings FILE] [--lab-list FILE] [--known FILE] [--baseline-musl FILE]
                      [--baseline-glibc FILE] [--symbolize-summary FILE] [-o OUT] [--top N] [--exit-code]
--exit-code: exit 1 if the JUnit has a failure (the CI job status); default exit 0.
"""
import argparse
import collections
import csv
import datetime
import glob
import os
import re
import sys
import xml.etree.ElementTree as ET

BAD_XML = re.compile("[^\u0009\u000a\u000d -퟿-�\U00010000-\U0010ffff]")


def clean(s):
    return BAD_XML.sub("?", s)


def read_text(path):
    try:
        with open(path, "rb") as fh:
            return fh.read().decode("utf-8", errors="replace")
    except OSError:
        return None


def parse_metrics(txt):
    """san-metrics.txt. Returns dict or None."""
    if txt is None:
        return None
    d = {"problems": [], "lines": txt.rstrip("\n").split("\n")}
    in_prob = False
    for line in d["lines"]:
        m = re.match(r"^([A-Za-z_ /]+?):\s+(.*)$", line)
        if line.startswith("  ") and in_prob:
            d["problems"].append(line.strip())
            continue
        if m:
            key = m.group(1).strip().lower()
            d[key] = m.group(2).strip()
            in_prob = key == "gaps/problems"
        else:
            in_prob = False
    return d


def parse_index(txt):
    """san-console-index.txt. Returns dict or None."""
    if txt is None:
        return None
    d = {"unmatched": [], "matched": 0, "deaths": 0, "reports": None, "distinct": None, "stats": None, "unmatched_n": None}
    for line in txt.split("\n"):
        m = re.match(r"^SANREPORT lines: (\d+) \(distinct exe\+pid: (\d+)\)", line)
        if m:
            d["reports"], d["distinct"] = int(m.group(1)), int(m.group(2))
        m = re.match(r"^SANSTATS lines: (\d+)", line)
        if m:
            d["stats"] = int(m.group(1))
        m = re.match(r"^SANDEATH lines: (\d+) \(matched (\d+), unmatched (\d+)", line)
        if m:
            d["deaths"], d["matched"], d["unmatched_n"] = int(m.group(1)), int(m.group(2)), int(m.group(3))
        m = re.match(r"^(\d+)\s+(\S+)\s+(\d+)\s+(UNMATCHED.*)$", line)
        if m:
            d["unmatched"].append((m.group(2), m.group(3), m.group(4)))
    return d


def parse_cram(path):
    """Return (suite attrs, {test path: (status, time, text)}) or (None, None)."""
    try:
        root = ET.parse(path).getroot()
    except (OSError, ET.ParseError):
        return None, None
    suite = root if root.tag == "testsuite" else (root.find("testsuite") if root.find("testsuite") is not None else root)
    res = {}
    for tc in root.iter("testcase"):
        st, text = "pass", ""
        for tag, name in (("failure", "fail"), ("error", "fail"), ("skipped", "skip")):
            e = tc.find(tag)
            if e is not None:
                st, text = name, (e.text or e.get("message") or "")
                break
        res[tc.get("classname") or tc.get("name")] = (st, float(tc.get("time") or 0), text)
    return dict(suite.attrib), res


def iteration_dirs(art):
    """The iter-NN directories of the loop driver, or the artifacts dir itself for a single run."""
    d = [x for x in sorted(glob.glob(os.path.join(art, "iter-*"))) if os.path.isdir(x)]
    return d or [art]


RANK = {"pass": 0, "skip": 1, "fail": 2}


def parse_cram_all(art, fname="cram.xml"):
    """Merge the cram JUnit of all iterations.

    Returns (suite, results, runs, missing): suite sums the attributes of the iterations, results maps a test
    to (worst status, longest time, text of the first failure), runs maps a test to its status per iteration,
    missing lists the directories without a readable file. suite is None when no file could be read."""
    suites, res, runs, missing = [], {}, {}, []
    for d in iteration_dirs(art):
        suite, one = parse_cram(os.path.join(d, fname))
        if one is None:
            missing.append(os.path.relpath(d, art) if d != art else ".")
            continue
        suites.append(suite)
        for t, (st, tm, text) in one.items():
            runs.setdefault(t, []).append(st)
            old = res.get(t)
            if old is None:
                res[t] = (st, tm, text)
            else:
                worst = st if RANK[st] > RANK[old[0]] else old[0]
                res[t] = (worst, max(tm, old[1]), old[2] if old[0] == "fail" else (text if st == "fail" else old[2]))
    if not suites:
        return None, None, {}, missing
    tot = {"tests": 0, "failures": 0, "skipped": 0, "time": 0.0}
    for su in suites:
        for k in tot:
            try:
                tot[k] += float(su.get(k, 0) or 0)
            except ValueError:
                pass
    tot["timestamp"] = min((su.get("timestamp", "") for su in suites if su.get("timestamp")), default="?")
    tot["iterations"] = len(suites)
    return {k: (str(int(v)) if k in ("tests", "failures", "skipped") else v) for k, v in tot.items()}, res, runs, missing


def write_merged_junit(art, out):
    """cram-merged.xml: every testsuite of every iteration, suites named iter-NN (GitLab test report)."""
    root = ET.Element("testsuites")
    n = 0
    for d in iteration_dirs(art):
        tag = os.path.basename(d) if d != art else "run"
        for fname in ("cram.xml", "cram-post.xml"):
            try:
                r = ET.parse(os.path.join(d, fname)).getroot()
            except (OSError, ET.ParseError):
                continue
            for su in ([r] if r.tag == "testsuite" else r.findall("testsuite")):
                su.set("name", "%s %s %s" % (tag, fname[:-4], su.get("name", "")))
                root.append(su)
                n += 1
    if n:
        ET.indent(root)
        ET.ElementTree(root).write(os.path.join(out, "cram-merged.xml"), encoding="utf-8", xml_declaration=True)
    return n


SLOW_RE = re.compile(r"(?i)timed out|time[- ]?out|did not (?:\w+ ){0,4}(?:after|within|in time)|not (?:ready|up|finished|done) (?:after|within)|after \d+ (?:attempts|tries|seconds)")


def classify_cram(test, status, text, lab):
    """lab-network | config | slow | other for a failing test; '' for a test that did not fail."""
    if status != "fail":
        return ""
    rel = test.replace(".gitlab/tests/cram/", "")
    if rel in lab:
        return "lab-network"
    if rel.endswith("/005-build-config.t"):
        return "config"
    # Only the lines of the diff that the DUT really printed ("+" lines): the context lines hold the test
    # script, which mentions timeouts as options.
    printed = "\n".join(l for l in (text or "").split("\n") if l.startswith("+") and not l.startswith("+++"))
    if SLOW_RE.search(printed):
        return "slow"
    return "other"


def read_lab_list(path):
    txt = read_text(path)
    if txt is None:
        sys.exit("san-summary: lab list not found: %s" % path)
    return [l.strip() for l in txt.split("\n") if l.strip() and not l.lstrip().startswith("#")]


def parse_baseline(path):
    """fail.tsv: status<TAB>test<TAB>... -> {test: 'fail'|'skip'}"""
    out = {}
    txt = read_text(path)
    if txt is None:
        sys.exit("san-summary: baseline not found: %s" % path)
    for line in txt.split("\n"):
        p = line.split("\t")
        if len(p) >= 2:
            out[p[1]] = "fail" if p[0] in ("failure", "error") else "skip"
    return out


def read_tsv(path):
    txt = read_text(path)
    if txt is None:
        return None
    return list(csv.DictReader(txt.split("\n"), delimiter="\t"))


def read_known(path):
    known = {}
    txt = read_text(path)
    if txt is None:
        sys.exit("san-summary: known file not found: %s" % path)
    for line in txt.split("\n"):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        p = line.split("\t")
        if len(p) >= 2:
            known[p[0].strip()] = (p[1].strip(), p[2].strip() if len(p) > 2 else "")
    return known


def load_pmreboots(art):
    """Blocked process-monitor reboots (san-pmreboots.py) of all iterations, or None when no input exists."""
    dirs = [d for d in iteration_dirs(art) if any(os.path.exists(os.path.join(d, f)) for f in ("logread-prereboot.txt", "logread-full.txt"))]
    if not dirs:
        return None
    import importlib.util
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location("san_pmreboots", os.path.join(os.path.dirname(os.path.abspath(__file__)), "san-pmreboots.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    events, sources = [], []
    for d in dirs:
        res = mod.scan(d)
        tag = os.path.basename(d) if d != art else ""
        for ev in res["events"]:
            ev["iter"] = tag
            events.append(ev)
        sources += res["sources"]
    return mod, {"events": events, "sources": sources}


def short(s, n):
    s = s.replace("\n", " ")
    return s if len(s) <= n else s[:n - 3] + "..."


def main():
    ap = argparse.ArgumentParser(prog="san-summary.py", description="Summary and JUnit of a sanitizer run.")
    ap.add_argument("--artifacts", required=True)
    ap.add_argument("--findings")
    ap.add_argument("--known")
    ap.add_argument("--lab-list")
    # --baseline-musl and --baseline-glibc: for the comparison with a local run; the CI job does not pass them
    ap.add_argument("--baseline-musl")
    ap.add_argument("--baseline-glibc")
    ap.add_argument("--symbolize-summary")
    ap.add_argument("--shim-regress-log")
    ap.add_argument("-o", "--out")
    ap.add_argument("--top", type=int, default=20, help="findings in the summary table (default 20)")
    ap.add_argument("--exit-code", action="store_true")
    a = ap.parse_args()

    art = a.artifacts
    out = a.out or art
    os.makedirs(out, exist_ok=True)
    now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    metrics = parse_metrics(read_text(os.path.join(art, "san-metrics.txt")))
    index = parse_index(read_text(os.path.join(art, "san-console-index.txt")))
    suite, cram, cram_runs, cram_missing = parse_cram_all(art)
    psuite, post, post_runs, post_missing = parse_cram_all(art, "cram-post.xml")
    lab = read_lab_list(a.lab_list) if a.lab_list else []
    trend = read_text(os.path.join(art, "san-rss-trend.md"))
    fpath = a.findings or os.path.join(art, "san-findings.tsv")
    findings = read_tsv(fpath)
    known = read_known(a.known) if a.known else {}
    symrows = read_tsv(a.symbolize_summary) if a.symbolize_summary else None
    pm = load_pmreboots(art)

    # ---- findings: new / open / waived ----
    fnd = []
    for r in findings or []:
        st, note = known.get(r["id"]) or known.get(r["key"]) or ("new", "")
        if st not in ("open", "waived"):
            st = "new"
        fnd.append((r, st, note))
    fcount = collections.Counter(s for _, s, _ in fnd)

    # ---- harness verdicts: (name, status pass|fail|skip, short message, detail text) ----
    hv = []
    if metrics is None:
        hv.append(("metrics-log", "fail", "san-metrics.txt missing: a lost metrics log is a failure", ""))
    else:
        v = metrics.get("verdict", "").split()[0].upper() if metrics.get("verdict") else ""
        msg = "%s; samples %s, last sample %s" % (v or "no verdict line", metrics.get("samples", "?"), metrics.get("last sample", "?"))
        detail = "\n".join(metrics["lines"])
        hv.append(("metrics-log", "pass" if v == "PASS" else ("skip" if v == "SKIP" else "fail"), msg, detail))
        rd = metrics.get("report dir")
        if rd is None:
            hv.append(("report-dir", "fail", "san-metrics.txt has no 'report dir' line", ""))
        else:
            hv.append(("report-dir", "pass" if rd.lower().startswith("ok") else "fail", "report dir: " + rd, ""))
    if metrics is None:
        hv.append(("report-dir", "fail", "san-metrics.txt missing: report dir state unknown", ""))
    if index is None:
        hv.append(("SAN-DEATH", "fail", "san-console-index.txt missing", ""))
    elif index["unmatched_n"] is None:
        hv.append(("SAN-DEATH", "pass" if index["deaths"] == 0 else "fail", "no 'SANDEATH lines' summary in the index", ""))
    elif index["unmatched_n"] > 0:
        detail = "\n".join("%s %s %s" % u for u in index["unmatched"][:40])
        by = collections.Counter(u[0] for u in index["unmatched"])
        hv.append(("SAN-DEATH", "fail", "%d unmatched SANDEATH (matched %d); mostly %s" % (
            index["unmatched_n"], index["matched"], ", ".join("%s x%d" % kv for kv in by.most_common(5))), detail))
    else:
        hv.append(("SAN-DEATH", "pass", "%d SANDEATH, all with a SANREPORT before them" % index["deaths"], ""))
    if a.shim_regress_log:
        lines = (read_text(a.shim_regress_log) or "").splitlines()
        skip = [ln for ln in lines if ln.startswith("shim-regress SKIPPED:")]
        res = [ln for ln in lines if re.match(r"^shim-regress: \d+ passed, \d+ failed", ln)]
        if skip:
            hv.append(("shim-regress", "skip", skip[0], ""))
        elif res:
            hv.append(("shim-regress", "pass" if ", 0 failed" in res[-1] else "fail", res[-1], ""))
        else:
            hv.append(("shim-regress", "fail", "%s has no result line" % os.path.basename(a.shim_regress_log), ""))
    if index is not None and findings is not None and index["reports"] and not findings:
        hv.append(("reports-collected", "fail", "%d SANREPORT lines on the console, but san-report.py found no report in the collected files: reports lost?" % index["reports"], ""))
    if findings is None:
        hv.append(("findings-input", "fail", "%s missing: san-report.py did not run, no findings are judged" % os.path.basename(fpath), ""))
    # A report file that holds a sanitizer report but gave no record (san-report.py: an unknown format) would pass unseen.
    unparsed = (read_text(os.path.join(art, "san-unparsed.txt")) or "").splitlines()
    if unparsed:
        hv.append(("reports-unparsed", "fail", "%d report file(s) hold a sanitizer report that san-report.py could not parse" % len(unparsed),
                   "\n".join(unparsed[:40])))
    if a.symbolize_summary and symrows is None:
        hv.append(("symbolization", "fail", "%s missing: the reports were not symbolized" % os.path.basename(a.symbolize_summary), ""))
    if symrows is not None:
        c = collections.Counter(r["status"] for r in symrows)
        # A mismatch or a missing unstripped file leaves the frames of that module unsymbolized (module+offset
        # stay in the report). That is listed, but only an error of the tool itself fails the check.
        bad = [r for r in symrows if r["status"] == "error"]
        hv.append(("symbolization", "fail" if bad else "pass",
                   "modules: %d ok, %d mismatch, %d not found, %d runtime" % (c["ok"], c["mismatch"], c["not-found"], c["runtime"]),
                   "\n".join("%s %s: %s" % (r["status"], r["module"], r["detail"]) for r in symrows if r["status"] in ("mismatch", "error", "not-found"))))

    # ---- cram ----
    classes = {}
    if cram is not None and (a.baseline_musl or a.baseline_glibc):
        bm = parse_baseline(a.baseline_musl) if a.baseline_musl else {}
        bg = parse_baseline(a.baseline_glibc) if a.baseline_glibc else {}
        for t, (st, _, _) in cram.items():
            if st == "fail":
                classes[t] = "a" if bm.get(t) == "fail" else ("b" if bg.get(t) == "fail" else "c")
            elif bm.get(t) == "fail" or bg.get(t) == "fail":
                classes[t] = "d"
        cc = collections.Counter(classes.values())
        bc = [t for t, c in classes.items() if c in ("b", "c")]
        hv.append(("cram-classes", "fail" if bc else "pass",
                   "failing tests not explained by the baselines (b+c): %d; a %d, b %d, c %d, d %d" % (len(bc), cc["a"], cc["b"], cc["c"], cc["d"]),
                   "\n".join("%s %s" % (classes[t], t) for t in sorted(bc))))
    if cram is None:
        hv.append(("cram-run", "fail", "no cram.xml found or readable (%s)" % ", ".join(cram_missing), ""))
    elif cram_missing:
        hv.append(("cram-run", "fail", "no cram.xml in: " + ", ".join(cram_missing), ""))
    else:
        hv.append(("cram-run", "pass", "%d iteration(s) with a cram.xml" % int(suite.get("iterations", 1)), ""))
    # The collector copies the reports, the sampler log and the syslog of the DUT; without it the run has no evidence.
    coll = {}
    for t, runs in post_runs.items():
        if t.endswith("90-san-collect.t"):
            coll = {"runs": runs}
    n_iter = len(iteration_dirs(art))
    if not coll:
        hv.append(("collector", "fail", "post test 90-san-collect.t did not run (no cram-post.xml entry)", ""))
    elif len(coll["runs"]) != n_iter or any(r != "pass" for r in coll["runs"]):
        hv.append(("collector", "fail", "90-san-collect.t result per iteration: " + ",".join(coll["runs"]) + " of %d" % n_iter, ""))
    else:
        hv.append(("collector", "pass", "90-san-collect.t passed in %d iteration(s)" % n_iter, ""))

    # ---- JUnit ----
    root = ET.Element("testsuites")
    s1 = ET.SubElement(root, "testsuite", name="sanitizer-findings", tests=str(len(fnd)),
                       failures=str(fcount["new"] + fcount["open"]), errors="0", skipped="0", timestamp=now)
    for r, st, note in fnd:
        top = r.get("top_frame", "")
        tc = ET.SubElement(s1, "testcase", classname="sanitizer." + r["kind"], name=clean("%s: %s [%s]" % (r["type"], short(top, 90), r["id"])), time="0")
        body = "\n".join([
            "status: %s%s" % (st, (" (%s)" % note) if note else ""),
            "count: %s in %s file(s); exes: %s; pids: %s" % (r["count"], r["files"], r["exes"], r["pids"]),
            "first file: %s" % r["first_file"],
            "key: %s" % r["key"],
            "stack: %s" % r["stack"].replace(" | ", "\n       ")])
        if st in ("new", "open"):
            f = ET.SubElement(tc, "failure", message=clean("%s %s %s, %s occurrence(s)" % (st, r["kind"], r["type"], r["count"])), type=st)
            f.text = clean(body)
        else:
            ET.SubElement(tc, "system-out").text = clean(body)
    s2 = ET.SubElement(root, "testsuite", name="sanitizer-harness", tests=str(len(hv)),
                       failures=str(sum(1 for h in hv if h[1] == "fail")), errors="0", skipped=str(sum(1 for h in hv if h[1] == "skip")), timestamp=now)
    for name, st, msg, detail in hv:
        tc = ET.SubElement(s2, "testcase", classname="sanitizer.harness", name=name, time="0")
        if st == "fail":
            ET.SubElement(tc, "failure", message=clean(msg), type="harness").text = clean(detail or msg)
        elif st == "skip":
            ET.SubElement(tc, "skipped", message=clean(msg))
        else:
            ET.SubElement(tc, "system-out").text = clean(msg)
    npm = 0

    def pml(ev):
        return ("%s: " % ev["iter"] if ev.get("iter") else "") + pm[0].format_line(ev)

    if pm and pm[1]["events"]:
        pmod, pres = pm
        npm = len(pres["events"])
        s3 = ET.SubElement(root, "testsuite", name="sanitizer-pm-reboots", tests=str(npm), failures=str(npm), errors="0", skipped="0", timestamp=now)
        for i, ev in enumerate(pres["events"], 1):
            tc = ET.SubElement(s3, "testcase", classname="sanitizer.finding", time="0",
                               name=clean("PM-REBOOT-BLOCKED #%d: %s [%s]" % (i, pmod.test_field(ev), ev["time_s"])))
            ET.SubElement(tc, "failure", message=clean(pml(ev)), type="finding").text = clean(
                "\n".join([pml(ev), "source: %s" % ev["source"], "test derived from: %s" % ev["how"], "cram: %s" % ev["cram_note"], "log: %s" % ev["raw"]] + ev["notes"]))
    root.set("tests", str(len(fnd) + len(hv) + npm))
    root.set("failures", str(int(s1.get("failures")) + int(s2.get("failures")) + npm))
    ET.indent(root)
    ET.ElementTree(root).write(os.path.join(out, "san-junit.xml"), encoding="utf-8", xml_declaration=True)
    nfail = int(root.get("failures"))

    # ---- summary markdown ----
    md = ["# Sanitizer run summary", "",
          "Generated %s from `%s`." % (now, art), ""]
    if suite:
        md.append("Cram run: %s iteration(s) of the [full] selection, started %s, %.0f s of test time; %s testcases, %s failures, %s skipped." % (
            suite.get("iterations", "1"), suite.get("timestamp", "?"), float(suite.get("time", 0) or 0), suite.get("tests", "?"), suite.get("failures", "?"), suite.get("skipped", "?")))
        md.append("")
    md += ["**Overall: %s** (%d JUnit failures of %s testcases)" % ("FAIL" if nfail else "PASS", nfail, root.get("tests")), "",
           "## Verdicts", "", "| check | result | detail |", "|---|---|---|"]
    for name, st, msg, _ in hv:
        md.append("| %s | %s | %s |" % (name, st.upper(), short(msg, 200).replace("|", "\\|")))
    md.append("| sanitizer findings | %s | %d unique: %d new, %d open, %d waived |" % (
        "FAIL" if (fcount["new"] + fcount["open"]) else ("PASS" if findings is not None else "FAIL"), len(fnd), fcount["new"], fcount["open"], fcount["waived"]))
    if pm:
        md.append("| blocked PM reboots | %s | %d (see section below) |" % ("FAIL" if npm else "PASS", npm))
    if findings is None:
        md.append("")
        md.append("`%s` is missing: run san-report.py first. No findings are judged." % fpath)
    md.append("")

    if index:
        md += ["## Console counters", "",
               "- SANREPORT lines: %s (distinct exe+pid: %s)" % (index["reports"], index["distinct"]),
               "- SANSTATS lines: %s" % index["stats"],
               "- SANDEATH lines: %s (matched %s, unmatched %s)" % (index["deaths"], index["matched"], index["unmatched_n"]), ""]
    if metrics:
        keep = ("boots", "samples", "seq first/last", "last sample", "extfree_kb", "report dir", "verdict")
        md += ["## Metrics log (san-metrics.txt)", ""]
        md += ["- %s: %s" % (k, metrics[k]) for k in keep if k in metrics]
        md += ["- problems: " + ("; ".join(metrics["problems"]) if metrics["problems"] else "none"), ""]

    if fnd:
        md += ["## Sanitizer findings (top %d of %d by count)" % (min(a.top, len(fnd)), len(fnd)), "",
               "| status | kind | type | count | exes | top frame | id |", "|---|---|---|---|---|---|---|"]
        for r, st, _ in sorted(fnd, key=lambda x: -int(x[0]["count"]))[:a.top]:
            md.append("| %s | %s | %s | %s | %s | %s | %s |" % (
                st, r["kind"], short(r["type"], 30), r["count"], short(r["exes"], 36), short(r.get("top_frame", ""), 90).replace("|", "\\|"), r["id"]))
        md += ["", "Full list: `%s`." % fpath, ""]

    if pm:
        md += ["## Blocked process-monitor reboots", ""]
        if pm[1]["events"]:
            md += ["%d reboot(s) blocked by ProcessMonitor.MaxReboots; details in `san-pmreboots.md` (san-pmreboots.py):" % npm, "", "```"]
            md += [pml(ev) for ev in pm[1]["events"]] + ["```", ""]
        else:
            md += ["None found in " + ", ".join("`%s`" % f for _, f, _ in pm[1]["sources"]) + ".", ""]

    if cram:
        fails = {t: v for t, v in cram.items() if v[0] == "fail"}
        md += ["## Cram", "", "%d tests: %d pass, %d fail, %d skip." % (
            len(cram), sum(1 for v in cram.values() if v[0] == "pass"), len(fails), sum(1 for v in cram.values() if v[0] == "skip")), ""]
        if classes:
            cc = collections.Counter(classes.values())
            md += ["Classes (a: also fails on musl, b: glibc-only, c: new under the sanitizer, d: fixed since a baseline): "
                   "a %d, b %d, c %d, d %d." % (cc["a"], cc["b"], cc["c"], cc["d"]), "",
                   "| class | test | result | time s |", "|---|---|---|---|"]
            for t in sorted(classes, key=lambda x: (classes[x], x)):
                if classes[t] != "a":
                    md.append("| %s | %s | %s | %.0f |" % (classes[t], t.replace(".gitlab/tests/cram/", ""), cram[t][0], cram[t][1]))
            md += ["", "Class a (not counted): " + ", ".join(sorted(os.path.basename(t) for t, c in classes.items() if c == "a")), ""]
        else:
            cls = {t: classify_cram(t, v[0], v[2], lab) for t, v in cram.items()}
            cc = collections.Counter(c for c in cls.values() if c)
            md += ["Failing tests by class (none of them is a sanitizer finding, none fails the job): "
                   "lab-network %d, slow under sanitizer %d, build configuration %d, other %d." % (
                       cc["lab-network"], cc["slow"], cc["config"], cc["other"]), ""]
            for key, title, note in (
                    ("other", "Other cram failures", "Not explained by the network, a time out or the build configuration. Look at them first."),
                    ("slow", "Slow under sanitizer", "The failure text mentions a time out. The tests are unchanged and only the job time out was raised, so these are reported apart from the findings."),
                    ("config", "Build configuration", "005-build-config.t compares /etc/build.config: the sanitize profile has another configuration than the default one.")):
                rows = sorted(t for t, c in cls.items() if c == key)
                if rows:
                    md += ["### " + title, "", note, "", "| test | iterations | time s |", "|---|---|---|"]
                    for t in rows:
                        md.append("| %s | %s | %.0f |" % (t.replace(".gitlab/tests/cram/", ""), ",".join(cram_runs.get(t, [])), cram[t][1]))
                    md.append("")
        if lab:
            byname = {t.replace(".gitlab/tests/cram/", ""): t for t in cram}
            md += ["## Lab-network tests", "",
                   "These %d tests need the outside network (LCM InstallDU from registry.gitlab.com, "
                   "NTP, WAN DNS and HTTPS). The CI job has network, so they run their real code path under the sanitizer. Result per iteration:" % len(lab), "",
                   "| test | result | iterations | time s |", "|---|---|---|---|"]
            for name in lab:
                t = byname.get(name)
                if t is None:
                    md.append("| %s | not run | - | - |" % name)
                else:
                    md.append("| %s | %s | %s | %.0f |" % (name, cram[t][0], ",".join(cram_runs.get(t, [])), cram[t][1]))
            md.append("")

    if symrows is not None:
        c = collections.Counter(r["status"] for r in symrows)
        md += ["## Symbolization", "", "%d ok, %d mismatch, %d not found, %d runtime, %d unknown modules." % (
            c["ok"], c["mismatch"], c["not-found"], c["runtime"], c["unknown"]), ""]
        for r in symrows:
            if r["status"] in ("mismatch", "error", "not-found"):
                md.append("- %s %s: %s" % (r["status"], r["module"], r["detail"]))
        md.append("")

    if trend:
        md += [trend.rstrip("\n"), ""]
    nmerged = write_merged_junit(art, out)
    md += ["Cram and post results of all iterations: `cram-merged.xml` (%d testsuites)." % nmerged, ""]

    with open(os.path.join(out, "san-summary.md"), "w") as fh:
        fh.write("\n".join(md) + "\n")
    sys.stderr.write("san-summary: %s; %d testcases, %d failures; %s, %s\n" % (
        "FAIL" if nfail else "PASS", len(fnd) + len(hv), nfail, os.path.join(out, "san-summary.md"), os.path.join(out, "san-junit.xml")))
    if a.exit_code and nfail:
        sys.exit(1)


if __name__ == "__main__":
    main()
