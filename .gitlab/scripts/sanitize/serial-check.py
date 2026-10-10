#!/usr/bin/env python3
"""serial-check.py: judge the console log (serial.log) of a sanitizer run after the run.

QEMU writes the DUT console into ARTIFACTS/serial.log. The DUT writes three kinds of lines there that
do not depend on SSH or on the disk, so they survive a hang of the guest:

  SANRSS <seq> <uptime> <pid> <name> <kB>   the per-minute sampler (cram test sanitize/000-san-sampler.t)
  SANPSS <seq> <uptime> <pid> <name> <pss_kB> <anon_kB> <swap_kB>   smaps_rollup rows of the same sampler pass; the
                                            metrics check ignores them (no "SANRSS " in the line), san-rss-trend.py reads them
  SANREPORT <exe> <pid> <type> <file>       one line per sanitizer report (sanitizer-shim)
  SANDEATH <exe> <pid> logdir=<rw|ro|missing> lsan_off=<0|1>   a sanitizer runtime terminated the process
  SANSTATS <exe> <pid> <freed_bytes> <uptime>   allocator statistics on the leak check signal

Commands (all take --artifacts DIR, which holds serial.log):
  metrics        fail when the SANRSS series is missing or has holes. Writes DIR/san-metrics.txt.
  console-index  SANREPORT counts, SANSTATS lines and SANDEATH matching. Writes DIR/san-console-index.txt.
  all            both; exit codes 88 (metrics failed; wins) and 89 (an unmatched SANDEATH), else 0.

Metrics rules (the verdict is FAIL, never a clean result, when the metrics log is lost):
  - no SANRSS line at all is a failure (serial.log missing too);
  - the series is split into boots: a "reboot: Restarting system" kernel line ends a boot, the sampler of the
    next boot starts again at seq 1. Every boot is judged on its own, the time between two boots is not;
  - inside a boot a missing seq, or a gap longer than 2 intervals (guest uptime), is a failure;
  - the last sample of a boot must be at most 2 intervals before the end of the boot: the reboot line (kernel
    stamp) or, for the last boot, the guest uptime that the loop driver wrote at the end (san-uptime-end.txt,
    "<iteration> <host epoch> <uptime>" per line; the last line counts);
  - a seq that goes back without a reboot or a new "Linux version" line between is a failure;
  - ExtFree_kB below 50 MB (--min-ext-free-kb) is a LOW-DISK failure;
  - a ReportDir sample of 0 is a REPORTDIR-GONE failure, samples without any ReportDir line are
    REPORTDIR-UNKNOWN.

SANDEATH matching: each SANDEATH needs a SANREPORT of the same exe and pid at most --death-window
(default 2000) serial.log lines before it; otherwise it is UNMATCHED and the run fails (exit 3 of the
console-index command). serial.log has no time stamps, so the window counts lines.

Only the Python standard library is used.
"""
import argparse
import collections
import datetime
import os
import re
import sys

WINDOW = 2000
KERNEL_STAMP = re.compile(r"\[\s*(\d+\.\d+)\]")


def utc(epoch=None):
    t = datetime.datetime.now(datetime.timezone.utc) if epoch is None else datetime.datetime.fromtimestamp(epoch, datetime.timezone.utc)
    return t.strftime("%Y-%m-%dT%H:%M:%SZ")


def read_lines(path):
    with open(path, "rb") as fh:
        data = fh.read()
    return [x.decode("utf-8", "replace") for x in data.split(b"\n")]


def fields(line, tag):
    p = line.find(tag + " ")
    if p < 0:
        return None
    return line[p:].rstrip(" \t\r").split()


# ---------------------------------------------------------------------------------------------------
# console index
# ---------------------------------------------------------------------------------------------------

def console_index(art, serial, window):
    """Write san-console-index.txt. Returns the number of unmatched SANDEATH lines."""
    out = os.path.join(art, "san-console-index.txt")
    if not os.path.isfile(serial):
        with open(out, "w") as fh:
            fh.write("san-console-index: %s not found\n" % serial)
        return 0
    lines = read_lines(serial)
    cnt = collections.OrderedDict()
    first = {}
    total = bad = nd = nm = nu = st = 0
    pids = set()
    lastrep = {}
    reptype = {}
    deaths = []
    stats = []
    sc = collections.Counter()
    sf = collections.Counter()
    ucnt = collections.Counter()
    for ln, line in enumerate(lines, 1):
        if "SANREPORT " in line:
            f = fields(line, "SANREPORT")
            if f is None or len(f) < 4 or not f[2].isdigit():
                bad += 1
                continue
            key = (f[1], f[3])
            if key not in cnt:
                first[key] = ln
                cnt[key] = 0
            cnt[key] += 1
            total += 1
            pids.add((f[1], f[2]))
            lastrep[(f[1], f[2])] = ln
            reptype[(f[1], f[2])] = f[3]
        elif "SANDEATH " in line:
            f = fields(line, "SANDEATH")
            if f is None or len(f) < 3 or not f[2].isdigit():
                bad += 1
                continue
            ld = lo = "-"
            if len(f) >= 5 and re.fullmatch(r"logdir=(rw|ro|missing)", f[3]) and re.fullmatch(r"lsan_off=[01]", f[4]):
                ld, lo = f[3][7:], f[4][9:]
            dk = (f[1], f[2])
            nd += 1
            if dk in lastrep and ln - lastrep[dk] <= window:
                nm += 1
                deaths.append("%-8d %-24s %-8s %-8s %-9s matched: SANREPORT %s at line %d (%d lines before)" % (
                    ln, f[1], f[2], ld, lo, reptype[dk], lastrep[dk], ln - lastrep[dk]))
            else:
                nu += 1
                ucnt[(ld, lo)] += 1
                if dk in lastrep:
                    why = "UNMATCHED: the last SANREPORT of this exe+pid is %d lines before (window %d lines)" % (ln - lastrep[dk], window)
                else:
                    why = "UNMATCHED: no SANREPORT of this exe+pid before it in serial.log"
                deaths.append("%-8d %-24s %-8s %-8s %-9s %s" % (ln, f[1], f[2], ld, lo, why))
        elif "SANSTATS " in line:
            f = fields(line, "SANSTATS")
            if f is None or len(f) < 5 or not f[2].isdigit() or not f[3].isdigit():
                bad += 1
                continue
            st += 1
            stats.append("%-8d %-24s %-8s %-14s %s" % (ln, f[1], f[2], f[3], f[4]))
            sc[f[1]] += 1
            sf[f[1]] += int(f[3])
    o = ["san-console-index: SANREPORT, SANSTATS and SANDEATH lines of %s (%d bytes), generated %s" % (
        os.path.basename(serial), os.path.getsize(serial), utc())]
    o.append("SANREPORT lines: %d (distinct exe+pid: %d)" % (total, len(pids)))
    o.append("%-8s %-24s %-22s %s" % ("count", "exe", "type", "first-line"))
    for (exe, typ), n in sorted(cnt.items(), key=lambda kv: (-kv[1], kv[0])):
        o.append("%-8d %-24s %-22s %d" % (n, exe, typ, first[(exe, typ)]))
    o.append("SANSTATS lines: %d" % st)
    if st:
        o.append("%-8s %-24s %-8s %-14s %s" % ("line", "exe", "pid", "freed_bytes", "uptime"))
        o += stats
        o.append("SANSTATS per exe (lines, freed_bytes in total):")
        for e, n in sorted(sc.items(), key=lambda kv: (-kv[1], kv[0])):
            o.append("  %-24s %-6d %.0f" % (e, n, sf[e]))
    o.append("SANDEATH lines: %d (matched %d, unmatched %d; window %d serial.log lines)" % (nd, nm, nu, window))
    if nd:
        o.append("%-8s %-24s %-8s %-8s %-9s %s" % ("line", "exe", "pid", "logdir", "lsan_off", "result"))
        o += deaths
    if nu:
        o.append("SANDEATH unmatched by (logdir, lsan_off) (- = old 3-field line without the fields):")
        for (ld, lo), n in sorted(ucnt.items(), key=lambda kv: (-kv[1], kv[0])):
            o.append("  logdir=%-8s lsan_off=%-2s %d" % (ld, lo, n))
    elif nd:
        o.append("SANDEATH unmatched by (logdir, lsan_off): none")
    if bad:
        o.append("malformed SANREPORT/SANSTATS/SANDEATH lines (ignored): %d" % bad)
    with open(out, "w") as fh:
        fh.write("\n".join(o) + "\n")
    if nu:
        line = "SAN-DEATH: FAIL %d unmatched SANDEATH (matched %d; report: %s)" % (nu, nm, out)
    elif nm:
        line = "SAN-DEATH: PASS %d SANDEATH, all with a SANREPORT before them (expected crashes; report: %s)" % (nm, out)
    else:
        line = "SAN-DEATH: PASS no SANDEATH line"
    sys.stderr.write(line + "\n")
    return nu


# ---------------------------------------------------------------------------------------------------
# metrics
# ---------------------------------------------------------------------------------------------------

def parse_series(lines):
    """Return (boots, extfree, reportdir).

    boots: list of dicts {samples: [(seq, uptime)], end: ('reboot', kernel stamp) | None, restart_ok, line}.
    A "reboot: Restarting system" line ends a boot, and so does a "Linux version" line (a crash reboot has
    no reboot line). The first sample after either starts a new boot, even when its seq is not lower.
    """
    boots = []
    cur = None
    ext = []
    rdir = []
    pending = False
    for ln, line in enumerate(lines, 1):
        if boots and "reboot: Restarting system" in line:
            m = KERNEL_STAMP.search(line)
            if cur is not None:
                cur["end"] = ("reboot", float(m.group(1)) if m else None)
            cur = None
            pending = True
            continue
        if boots and "Linux version " in line:
            cur = None
            pending = True
            continue
        p = line.find("SANRSS ")
        if p < 0:
            continue
        f = line[p:].rstrip(" \t\r").split()
        if len(f) < 6 or not f[1].isdigit() or not re.fullmatch(r"\d+(\.\d+)?", f[2]) or not f[3].isdigit() or not f[5].lstrip("-").isdigit():
            continue
        seq, up, pid, name, val = int(f[1]), float(f[2]), int(f[3]), f[4], int(f[5])
        if len(f) == 6 and pid == 0 and name == "ExtFree_kB":
            ext.append((seq, val))
        if len(f) == 6 and pid == 0 and name == "ReportDir" and f[5] in ("0", "1"):
            rdir.append((seq, val))
        if cur is not None and seq == cur["samples"][-1][0]:
            continue          # another line of the same sample
        if cur is not None and seq < cur["samples"][-1][0]:
            cur = None        # the seq went back without a reboot line in between
        if cur is None:
            cur = {"samples": [], "end": None, "restart_ok": pending or not boots, "line": ln}
            boots.append(cur)
            pending = False
        cur["samples"].append((seq, up))
    return boots, ext, rdir


def end_uptime(art):
    """Guest uptime of the LAST line of san-uptime-end.txt ("-" = ssh failed), or None."""
    path = os.path.join(art, "san-uptime-end.txt")
    last = None
    try:
        with open(path) as fh:
            for line in fh:
                f = line.split()
                if len(f) >= 3:
                    last = float(f[2]) if re.fullmatch(r"\d+(\.\d+)?", f[2]) else None
    except OSError:
        return None
    return last


def metrics(art, serial, interval, min_ext_kb):
    out = os.path.join(art, "san-metrics.txt")
    limit = 2 * interval
    probs = []
    boots, ext, rdir = [], [], []
    have_serial = os.path.isfile(serial)
    if have_serial:
        boots, ext, rdir = parse_series(read_lines(serial))
    else:
        probs.append("NO-SERIAL   %s not found: the metrics log is lost" % serial)
    nsamp = sum(len(b["samples"]) for b in boots)
    uend = end_uptime(art)
    verdict = "PASS"
    if have_serial and nsamp == 0:
        probs.append("NO-SAMPLES  no SANRSS line in serial.log: the sampler never ran or the console log is lost")
    for i, b in enumerate(boots, 1):
        s = b["samples"]
        if i > 1 and not b["restart_ok"]:
            probs.append("SEQ-BACK    boot %d: seq goes back to %d at serial line %d without a reboot or a new kernel line before it" % (i, s[0][0], b["line"]))
        if s[0][0] != 1 and (i == 1 or b["restart_ok"]):
            probs.append("SEQ-START   boot %d: the first sample has seq %d, not 1: the first %d sample(s) are missing" % (i, s[0][0], s[0][0] - 1))
        for (ps, pu), (qs, qu) in zip(s, s[1:]):
            if qs > ps + 1:
                probs.append("SEQ-JUMP    boot %d: seq %d -> %d, %d sample(s) missing" % (i, ps, qs, qs - ps - 1))
            if qu - pu > limit:
                probs.append("GAP         boot %d: %.0f s between seq %d (uptime %.0f) and seq %d (uptime %.0f), limit %d s" % (i, qu - pu, ps, pu, qs, qu, limit))
        lseq, lup = s[-1]
        end = b["end"]
        if end and end[0] == "reboot" and end[1] is not None:
            if end[1] - lup > limit:
                probs.append("STALE       boot %d: last sample (seq %d) is %.0f s older than the DUT reboot that ended the boot, limit %d s" % (i, lseq, end[1] - lup, limit))
        elif i == len(boots) and (end is None):
            if uend is None:
                probs.append("NO-END      boot %d: no san-uptime-end.txt, the age of the last sample (seq %d) cannot be judged" % (i, lseq))
            elif uend - lup > limit:
                probs.append("STALE       boot %d: last sample (seq %d) is %.0f s older than the end of the run, limit %d s" % (i, lseq, uend - lup, limit))
    ef_note = None
    if ext:
        mn = min(ext, key=lambda x: x[1] if x[1] >= 0 else 1 << 60)
        good = [x for x in ext if x[1] >= 0]
        if good:
            mn = min(good, key=lambda x: x[1])
            ef_note = "%d samples, minimum %d kB (seq %d), last %d kB, limit %d kB" % (len(good), mn[1], mn[0], good[-1][1], min_ext_kb)
            if mn[1] < min_ext_kb:
                probs.append("LOW-DISK    ExtFree_kB minimum %d kB (seq %d) is below the limit of %d kB" % (mn[1], mn[0], min_ext_kb))
    if ef_note is None:
        ef_note = "no sample in serial.log (df failed on the DUT); the free-space check did not run"
    zero = [x for x in rdir if x[1] == 0]
    if zero:
        probs.append("REPORTDIR-GONE  /ext/sanitizer missing or not writable in %d of %d ReportDir samples (first seq %d, last seq %d)" % (
            len(zero), len(rdir), zero[0][0], zero[-1][0]))
        rd_note = "gone since seq %d (0 in %d of %d samples, last 0 at seq %d)" % (zero[0][0], len(zero), len(rdir), zero[-1][0])
    elif rdir:
        rd_note = "ok (%d samples, all 1)" % len(rdir)
    elif nsamp:
        probs.append("REPORTDIR-UNKNOWN  %d SANRSS samples but no ReportDir line in serial.log: the report dir was not checked" % nsamp)
        rd_note = "unknown (no ReportDir line in serial.log)"
    else:
        rd_note = "not checked (no SANRSS samples)"
    if probs:
        verdict = "FAIL"
    o = ["SAN-METRICS report (SANRSS metrics-log check, serial-check.py)",
         "generated:      %s" % utc(),
         "interval:       %d s; gap and staleness limit %d s (2 intervals)" % (interval, limit),
         "boots:          %d (each boot is judged on its own; the sampler restarts at seq 1)" % len(boots),
         "samples:        %d" % nsamp]
    if nsamp:
        o.append("seq first/last: " + ", ".join("%d / %d" % (b["samples"][0][0], b["samples"][-1][0]) for b in boots[:12]) + (" ..." if len(boots) > 12 else "") + " (per boot)")
        o.append("last sample:    seq %d, guest uptime %.0f s%s" % (boots[-1]["samples"][-1][0], boots[-1]["samples"][-1][1],
                 (", %.0f s before the end of the run" % (uend - boots[-1]["samples"][-1][1])) if uend is not None and boots[-1]["end"] is None else ""))
    else:
        o += ["seq first/last: none", "last sample:    none"]
    o.append("ExtFree_kB:     " + ef_note)
    o.append("report dir:     " + rd_note)
    o.append("gaps/problems:  %d" % len(probs))
    o += ["  " + p for p in probs]
    o.append("verdict:        " + verdict)
    with open(out, "w") as fh:
        fh.write("\n".join(o) + "\n")
    if probs:
        reason = re.sub(r"\s{2,}", " ", probs[0]) + (" (+%d more)" % (len(probs) - 1) if len(probs) > 1 else "")
        sys.stderr.write("SAN-METRICS: FAIL %s; samples=%d (report: %s)\n" % (reason, nsamp, out))
    else:
        sys.stderr.write("SAN-METRICS: PASS samples=%d boots=%d (report: %s)\n" % (nsamp, len(boots), out))
    return verdict == "FAIL"


def main():
    ap = argparse.ArgumentParser(prog="serial-check.py", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("command", choices=("metrics", "console-index", "all"))
    ap.add_argument("--artifacts", required=True)
    ap.add_argument("--serial", help="console log (default ARTIFACTS/serial.log)")
    ap.add_argument("--metrics-interval", type=int, default=60)
    ap.add_argument("--min-ext-free-kb", type=int, default=51200)
    ap.add_argument("--death-window", type=int, default=WINDOW)
    a = ap.parse_args()
    if not os.path.isdir(a.artifacts):
        sys.exit("serial-check: not a directory: %s" % a.artifacts)
    serial = a.serial or os.path.join(a.artifacts, "serial.log")
    x4 = death = 0
    if a.command in ("metrics", "all"):
        x4 = 1 if metrics(a.artifacts, serial, a.metrics_interval, a.min_ext_free_kb) else 0
    if a.command in ("console-index", "all"):
        death = 1 if console_index(a.artifacts, serial, a.death_window) else 0
    if a.command == "metrics":
        sys.exit(1 if x4 else 0)
    if a.command == "console-index":
        sys.exit(3 if death else 0)
    if x4:
        if death:
            sys.stderr.write("serial-check: also: SANDEATH without a matching SANREPORT (89)\n")
        sys.exit(88)
    sys.exit(89 if death else 0)


if __name__ == "__main__":
    main()
