#!/usr/bin/env python3
"""san-rss-trend.py: /proc memory trend of the sanitizer run, from the SANRSS console lines.

The DUT sampler (cram test sanitize/000-san-sampler.t) prints, once a minute, the 15 largest processes:
  SANRSS <seq> <uptime> <pid> <name> <kB>
Rows with pid 0 are system values (MemAvailable, ExtFree_kB, ReportDir). The lines come from serial.log
(the console of QEMU), so the trend survives a dead SSH or a lost disk.

The sampler also prints, from /proc/<pid>/smaps_rollup (older sampler: none, the PSS part is then left out):
  SANPSS <seq> <uptime> <pid> <name> <pss_kB> <anon_kB> <swap_kB>    the same top-15 processes as SANRSS
  SANPSS <seq> <uptime> 0 PssSum <pss_kB> <anon_kB> <swap_kB>        sum over ALL processes
  SANPSS <seq> <uptime> 0 PssProcs <n> 0 0                           number of processes in the sum
  SANPSS <seq> <uptime> 0 <AnonPages|Shmem|SUnreclaim> <kB> 0 0
RSS counts a shared page in every process that maps it, PSS splits it, so the sum of PSS does not double-count.
The report adds the PSS peak per process and the peak/last of PssSum next to MemAvailable (PssSum plus Shmem
and SUnreclaim is close to MemTotal minus MemAvailable; the rest is page cache and kernel memory).

One row per (boot, pid, name): first and last RSS, maximum, number of samples, the span in seconds and the
growth in kB per hour (last minus first over the span; only with at least --min-samples samples). A new
boot starts when seq or uptime goes back, or at a "Linux version" kernel line. The sampler lists only the
15 largest processes, so a process that is small for a while appears with a later first sample.

Output (-o OUT): OUT/san-rss-trend.tsv (all rows) and OUT/san-rss-trend.md (top tables, for the summary).
Usage: san-rss-trend.py SERIAL_LOG -o OUT [--top 15] [--min-samples 10]
Only the Python standard library is used.
"""
import argparse
import os
import re
import sys


def main():
    ap = argparse.ArgumentParser(prog="san-rss-trend.py", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("serial")
    ap.add_argument("-o", "--out", required=True)
    ap.add_argument("--top", type=int, default=15)
    ap.add_argument("--min-samples", type=int, default=10)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    boot = 0
    last = None            # (seq, uptime) of the previous sample line
    pending = False
    rows = {}              # (boot, pid, name) -> list of (uptime, kB)
    sysrows = {}           # (boot, name) -> list of (uptime, value)
    pss = {}               # (boot, pid, name) -> list of (uptime, pss, anon, swap)
    psys = {}              # (boot, name) -> list of (uptime, value, anon, swap); name PssSum, PssProcs, AnonPages, ...
    npss = 0
    nlines = 0
    try:
        data = open(a.serial, "rb").read().decode("utf-8", "replace").split("\n")
    except OSError as e:
        sys.exit("san-rss-trend: cannot read %s: %s" % (a.serial, e))
    for line in data:
        if "Linux version " in line and last is not None:
            pending = True
            continue
        q = line.find("SANPSS ")
        if q >= 0 and line.find("SANRSS ") < 0:
            g = line[q:].rstrip(" \t\r").split()
            if len(g) == 8 and g[1].isdigit() and re.fullmatch(r"\d+(\.\d+)?", g[2]) and g[3].isdigit() and all(re.fullmatch(r"-?\d+", x) for x in g[5:]):
                npss += 1
                # the boot of a PSS row is the boot of the SANRSS rows before it (same seq, printed first)
                if int(g[3]) == 0:
                    psys.setdefault((boot, g[4]), []).append((float(g[2]), int(g[5]), int(g[6]), int(g[7])))
                else:
                    pss.setdefault((boot, int(g[3]), g[4]), []).append((float(g[2]), int(g[5]), int(g[6]), int(g[7])))
            continue
        p = line.find("SANRSS ")
        if p < 0:
            continue
        f = line[p:].rstrip(" \t\r").split()
        if len(f) != 6 or not f[1].isdigit() or not re.fullmatch(r"\d+(\.\d+)?", f[2]) or not f[3].isdigit() or not re.fullmatch(r"-?\d+", f[5]):
            continue
        seq, up, pid, name, val = int(f[1]), float(f[2]), int(f[3]), f[4], int(f[5])
        if pending or (last is not None and (seq < last[0] or up < last[1])):
            boot += 1
            pending = False
        last = (seq, up)
        nlines += 1
        if pid == 0:
            sysrows.setdefault((boot, name), []).append((up, val))
        else:
            rows.setdefault((boot, pid, name), []).append((up, val))
    res = []
    for (b, pid, name), s in rows.items():
        span = s[-1][0] - s[0][0]
        rate = (s[-1][1] - s[0][1]) * 3600.0 / span if len(s) >= a.min_samples and span > 0 else None
        res.append({"boot": b + 1, "pid": pid, "name": name, "first": s[0][1], "last": s[-1][1], "max": max(v for _, v in s),
                    "n": len(s), "span": span, "rate": rate})
    res.sort(key=lambda r: (-r["max"], r["name"], r["pid"]))
    with open(os.path.join(a.out, "san-rss-trend.tsv"), "w") as fh:
        fh.write("boot\tpid\tname\tfirst_kB\tlast_kB\tmax_kB\tsamples\tspan_s\tgrowth_kB_per_h\n")
        for r in res:
            fh.write("%d\t%d\t%s\t%d\t%d\t%d\t%d\t%.0f\t%s\n" % (r["boot"], r["pid"], r["name"], r["first"], r["last"], r["max"], r["n"], r["span"],
                                                              "" if r["rate"] is None else "%.0f" % r["rate"]))
    md = ["## Memory trend (SANRSS, /proc VmRSS)", "",
          "%d sample lines, %d boot(s), %d (boot, pid, name) series. Full list: `san-rss-trend.tsv`." % (nlines, boot + 1 if nlines else 0, len(res)), ""]
    if not res:
        md += ["No SANRSS process rows in the console log.", ""]
    else:
        md += ["Largest processes by maximum RSS:", "", "| boot | pid | name | max MB | last MB | samples | span min |", "|---|---|---|---|---|---|---|"]
        for r in res[:a.top]:
            md.append("| %d | %d | %s | %.0f | %.0f | %d | %.0f |" % (r["boot"], r["pid"], r["name"], r["max"] / 1024, r["last"] / 1024, r["n"], r["span"] / 60))
        gr = sorted((r for r in res if r["rate"] is not None and r["rate"] > 0), key=lambda r: -r["rate"])
        md += ["", "Fastest growing (last minus first RSS per hour, series with at least %d samples):" % a.min_samples, "",
               "| boot | pid | name | MB/h | first MB | last MB | span min |", "|---|---|---|---|---|---|---|"]
        for r in gr[:a.top]:
            md.append("| %d | %d | %s | %.1f | %.0f | %.0f | %.0f |" % (r["boot"], r["pid"], r["name"], r["rate"] / 1024, r["first"] / 1024, r["last"] / 1024, r["span"] / 60))
        if not gr:
            md.append("| - | - | no growing series | - | - | - | - |")
        ma = sysrows.get((0, "MemAvailable")) or []
        if ma:
            md += ["", "MemAvailable of the first boot: first %.0f MB, minimum %.0f MB, last %.0f MB." % (
                ma[0][1] / 1024, min(v for _, v in ma) / 1024, ma[-1][1] / 1024)]
        md.append("")
    if npss:
        pres = []
        for (b, pid, name), s in pss.items():
            top = max(s, key=lambda x: x[1])
            pres.append({"boot": b + 1, "pid": pid, "name": name, "max": top[1], "up": top[0], "anon": top[2], "swap": max(x[3] for x in s),
                         "last": s[-1][1], "n": len(s)})
        pres.sort(key=lambda r: (-r["max"], r["name"], r["pid"]))
        with open(os.path.join(a.out, "san-pss-trend.tsv"), "w") as fh:
            fh.write("boot\tpid\tname\tmax_pss_kB\tuptime_at_max\tanon_kB_at_max\tmax_swap_kB\tlast_pss_kB\tsamples\n")
            for r in pres:
                fh.write("%d\t%d\t%s\t%d\t%.0f\t%d\t%d\t%d\t%d\n" % (r["boot"], r["pid"], r["name"], r["max"], r["up"], r["anon"], r["swap"], r["last"], r["n"]))
        md += ["## Memory trend (SANPSS, smaps_rollup)", "",
               "%d PSS rows. PSS splits shared pages between the processes that map them, so the sum does not double-count. "
               "Per-process rows cover the 15 largest by RSS of each sample. Full list: `san-pss-trend.tsv`." % npss, ""]
        for b in sorted({k[0] for k in psys}):
            sm = psys.get((b, "PssSum")) or []
            npc = psys.get((b, "PssProcs")) or []
            if not sm:
                continue
            pk = max(sm, key=lambda x: x[1])
            line = "Boot %d, all processes: PSS sum peak %.0f MB at uptime %.0f s (anon %.0f MB, swap %.0f MB), last %.0f MB" % (
                b + 1, pk[1] / 1024, pk[0], pk[2] / 1024, max(x[3] for x in sm) / 1024, sm[-1][1] / 1024)
            if npc:
                line += "; %d to %d processes" % (min(x[1] for x in npc), max(x[1] for x in npc))
            for k in ("Shmem", "SUnreclaim"):
                kv = psys.get((b, k))
                if kv:
                    line += "; %s peak %.0f MB" % (k, max(x[1] for x in kv) / 1024)
            ma = [x for x in (sysrows.get((b, "MemAvailable")) or [])]
            if ma:
                line += "; MemAvailable minimum %.0f MB" % (min(v for _, v in ma) / 1024)
            md.append(line + ".")
        md += ["", "Largest processes by maximum PSS:", "", "| boot | pid | name | max PSS MB | at uptime s | anon MB | last PSS MB | samples |", "|---|---|---|---|---|---|---|---|"]
        for r in pres[:a.top]:
            md.append("| %d | %d | %s | %.0f | %.0f | %.0f | %.0f | %d |" % (r["boot"], r["pid"], r["name"], r["max"] / 1024, r["up"], r["anon"] / 1024, r["last"] / 1024, r["n"]))
        md.append("")
    with open(os.path.join(a.out, "san-rss-trend.md"), "w") as fh:
        fh.write("\n".join(md) + "\n")
    sys.stderr.write("san-rss-trend: %d series from %d sample lines; %s\n" % (len(res), nlines, os.path.join(a.out, "san-rss-trend.md")))


if __name__ == "__main__":
    main()
