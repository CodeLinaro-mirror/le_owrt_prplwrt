#!/usr/bin/env python3
"""san-calibrate.py: suggest per-executable quarantine sizes from a run's serial.log.

Rule: per executable (merge forked children by exe), freed bytes per second ->
suggested quarantine_size_mb = clamp(freed_rate x 60 s, 8, 128). It is a cap, not a fit: the
free-to-stale-access latency is unknown. Output: suggested <exe>.opts files as a run artifact.
Never apply them automatically. A human commits them between runs. Ignore short-lived tools; the
tier default covers them.

Input lines of serial.log (the DUT console):
  SANSTATS <exe> <pid> <freed_bytes> <uptime>        leak-check broadcast answer; uptime = system uptime (s),
                                                     freed_bytes has MiB resolution (0 = under 1 MiB)
  SANRSS <seq> <uptime> <pid> <name> <kB>            per-minute sampler; pid 0 = system rows
Process start = uptime of the first SANRSS sample that lists the pid (an upper bound: the sampler
shows only the 15 largest processes, so the true start can be earlier, and the rate is then
overstated); a pid already present in the first sample of its boot, or never listed: start at boot (0),
which understates the rate. A reboot is detected when seq or uptime goes backwards; pids are per boot.
SANSTATS repeated for a pid: the one with the largest uptime wins (freed_bytes is cumulative).
Merge by exe: rate = sum(freed of the qualifying pids) / sum(their ages) (a mean over the forks).
Skipped: a pid younger than --min-age (default 300 s, "short-lived tools"); an exe whose freed sum
is below --min-freed-mib (default 1).

Usage: san-calibrate.py SERIAL_LOG -o OUTDIR [--min-age 300] [--min-freed-mib 1] [--min-mb 8] [--max-mb 128]
                        [--window 60] [--force]
Output: OUTDIR/<exe>.opts (one line: quarantine_size_mb=N; no comment syntax exists in the flag parser)
        and OUTDIR/calibration.md (table of the suggestions and the skipped executables).

Committed overrides: two more modes keep the list in package/utils/sanitizer-opts short and honest.

  san-calibrate.py publish CALIB_DIR --opts-dir DIR --rootfs ROOT [--system-version STR] [--heavy-mb 64] [--force]
      CALIB_DIR = the OUTDIR above. Only a heavy allocator gets a file: suggested MB > --heavy-mb (default 64 =
      the 16 GB shim tier; a smaller value is already covered by the tier). Writes DIR/<exe>.opts and
      DIR/PROVENANCE (TAB separated: binary, package, package version, system version). The package comes from
      ROOT/usr/lib/opkg/info/*.list (ROOT = build_dir/target-*/root-* or an unpacked rootfs), the package
      version from ROOT/usr/lib/opkg/status, the system version from ROOT/etc/openwrt_release
      (DISTRIB_DESCRIPTION) unless --system-version is given. An executable that is no file of any package, or
      of several, fails the run (nothing is written). The package version is the staleness key; the system
      version is provenance only. The shim checks nothing.
  san-calibrate.py drift OPTS_DIR (--manifest FILE | --rootfs ROOT) [--calibration CALIB_DIR] [--heavy-mb N]
                         [--fail-on-drift]
      Compares OPTS_DIR/PROVENANCE with the package versions of a build (--manifest = bin/targets/*/*.manifest,
      lines "name - version"; or the opkg status of --rootfs). Reports STALE (version differs), MISSING (package
      not in the build), INCONSISTENT (PROVENANCE line without .opts file or the reverse) and, with
      --calibration, NEW (heavy in the newer calibration, no entry) and LIGHT (entry no longer heavy).
      Exit 0 unless --fail-on-drift is given and anything was reported (then 1).
"""
import argparse
import collections
import math
import os
import re
import sys

STATS_RE = re.compile(r"(?:^|\s)SANSTATS (\S+) (\d+) (\d+) (\d+)\s*$")
RSS_RE = re.compile(r"(?:^|\s)SANRSS (\d+) ([\d.]+) (\d+) (\S+) (\d+)\s*$")
SAFE_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._+@-]*$")
MIB = 1024 * 1024


def parse(path):
    """Return ({(boot, pid): [exe, freed, uptime]}, {(boot, pid): first-seen uptime}, boots)."""
    stats, first = {}, {}
    boot, last_seq, last_up = 0, 0, 0.0
    first_seq_of_boot = {}
    with open(path, "rb") as fh:
        data = fh.read().decode("utf-8", errors="replace")
    for line in re.split(r"[\r\n]+", data):
        r = RSS_RE.search(line)
        if r:
            seq, up, pid = int(r.group(1)), float(r.group(2)), int(r.group(3))
            if seq < last_seq or up + 1 < last_up:
                boot += 1
            last_seq, last_up = seq, up
            first_seq_of_boot.setdefault(boot, seq)
            if pid and (boot, pid) not in first:
                # present in the first sample of the boot: started before it, assume boot
                first[(boot, pid)] = 0.0 if seq == first_seq_of_boot[boot] else up
            continue
        s = STATS_RE.search(line)
        if s:
            exe, pid, freed, up = s.group(1), int(s.group(2)), int(s.group(3)), float(s.group(4))
            if up + 1 < last_up:          # uptime went backwards: a reboot
                boot += 1
                last_seq, last_up = 0, 0.0
            last_up = max(last_up, up)
            old = stats.get((boot, pid))
            if old is None or up >= old[2]:
                stats[(boot, pid)] = [exe, freed, up]
    return stats, first, boot + 1


def cmd_suggest():
    ap = argparse.ArgumentParser(prog="san-calibrate.py", description="Suggest quarantine_size_mb per executable.")
    ap.add_argument("serial_log")
    ap.add_argument("-o", "--out", required=True)
    ap.add_argument("--min-age", type=float, default=300.0)
    ap.add_argument("--min-freed-mib", type=float, default=1.0)
    ap.add_argument("--min-mb", type=int, default=8)
    ap.add_argument("--max-mb", type=int, default=128)
    ap.add_argument("--window", type=float, default=60.0, help="seconds of freed bytes the quarantine should hold (default 60)")
    ap.add_argument("--force", action="store_true", help="write into a dir that already has .opts files")
    a = ap.parse_args()

    if not os.path.isfile(a.serial_log):
        sys.exit("san-calibrate: not found: %s" % a.serial_log)
    stats, first, boots = parse(a.serial_log)
    os.makedirs(a.out, exist_ok=True)
    if not a.force and any(f.endswith(".opts") for f in os.listdir(a.out)):
        sys.exit("san-calibrate: %s already has .opts files (use a fresh dir or --force)" % a.out)

    per = collections.defaultdict(list)       # exe -> [(pid, freed, age, start_known)]
    for (boot, pid), (exe, freed, up) in sorted(stats.items()):
        start = first.get((boot, pid))
        per[exe].append((pid, freed, max(up - (start or 0.0), 0.0), start is not None, boot))

    rows, skipped = [], []
    for exe in sorted(per):
        procs = per[exe]
        good = [p for p in procs if p[2] >= a.min_age and p[2] > 0]
        if not good:
            skipped.append((exe, len(procs), "all %d process(es) younger than %d s (oldest %d s)" % (len(procs), a.min_age, max(p[2] for p in procs))))
            continue
        freed = sum(p[1] for p in good)
        age = sum(p[2] for p in good)
        if freed < a.min_freed_mib * MIB:
            skipped.append((exe, len(procs), "freed %d bytes (< %g MiB) over %d s" % (freed, a.min_freed_mib, age)))
            continue
        if not SAFE_RE.match(exe):
            skipped.append((exe, len(procs), "executable name not usable as a file name"))
            continue
        rate = freed / age                                    # bytes per second, merged
        peak = max(p[1] / p[2] for p in good)
        mb = int(min(a.max_mb, max(a.min_mb, math.ceil(rate * a.window / MIB))))
        rows.append((exe, len(good), len(procs), freed, age, rate, peak, mb, sum(1 for p in good if p[3])))

    for r in rows:
        with open(os.path.join(a.out, r[0] + ".opts"), "w") as fh:
            fh.write("quarantine_size_mb=%d\n" % r[7])

    md = ["# Quarantine calibration", "",
          "Source: %s; boots seen: %d; SANSTATS processes: %d." % (a.serial_log, boots, len(stats)), "",
          "Suggested `quarantine_size_mb` = clamp(freed rate x %g s, %d, %d) MiB, rounded up. **A cap, not a fit**: "
          "the free-to-stale-access latency is unknown. The `.opts` files in this directory are suggestions; nothing applies them "
          "automatically, a human reviews and commits them between runs. Short-lived tools stay on the tier default "
          "(a process counts only from %g s of age)." % (a.window, a.min_mb, a.max_mb, a.min_age), "",
          "Rate method: freed bytes of the process divided by its age (SANSTATS uptime minus the first SANRSS appearance of the pid, "
          "boot if unknown); forked children of one exe are merged by summing freed bytes and ages. "
          "freed_bytes has MiB resolution.", ""]
    md += ["| exe | procs used/seen | freed MiB | age s (sum) | rate MiB/min (merged) | peak pid MiB/min | suggested MB | start known |",
           "|---|---|---|---|---|---|---|---|"]
    for exe, n, nall, freed, age, rate, peak, mb, known in sorted(rows, key=lambda r: -r[7] * 1e9 - r[5]):
        md.append("| %s | %d/%d | %.1f | %.0f | %.2f | %.2f | %d | %d/%d |" % (exe, n, nall, freed / MIB, age, rate * 60 / MIB, peak * 60 / MIB, mb, known, n))
    if not rows:
        md.append("| (none) | | | | | | | |")
    md += ["", "## Skipped (%d executables)" % len(skipped), ""]
    for exe, n, why in skipped:
        md.append("- %s (%d proc): %s" % (exe, n, why))
    with open(os.path.join(a.out, "calibration.md"), "w") as fh:
        fh.write("\n".join(md) + "\n")
    sys.stderr.write("san-calibrate: %d SANSTATS processes, %d exes with a suggestion, %d skipped; written to %s\n"
                     % (len(stats), len(rows), len(skipped), a.out))

# ---- committed overrides: publish and drift -----------------------------------------------

RESERVED = {"sleep"}          # shipped by sanitizer-shim (handle_segv=0); the opts package never ships it
PROV_HEAD = ("# sanitizer-opts provenance, written by .gitlab/scripts/sanitize/san-calibrate.py publish. Not installed into the image.\n"
             "# One line per <binary>.opts, TAB separated: binary, package, package version, system version.\n"
             "# The package version is the staleness key (san-calibrate.py drift). The system version string of the\n"
             "# calibrated image is provenance only. Neither is checked by the shim.\n"
             "# Values are absolute MB of quarantine_size_mb from freed-byte churn, not from the RAM budget.\n")
OPTS_RE = re.compile(r"^\s*quarantine_size_mb=(\d+)\s*$")


def read_opts_mb(path):
    with open(path) as fh:
        for line in fh:
            m = OPTS_RE.match(line)
            if m:
                return int(m.group(1))
    return None


def calib_values(calib_dir):
    """{exe: suggested MB} from the *.opts files of a calibration dir."""
    out = {}
    for f in sorted(os.listdir(calib_dir)):
        if f.endswith(".opts"):
            mb = read_opts_mb(os.path.join(calib_dir, f))
            if mb is not None:
                out[f[:-5]] = mb
    return out


def opkg_dir(rootfs):
    d = os.path.join(rootfs, "usr", "lib", "opkg")
    if not os.path.isfile(os.path.join(d, "status")):
        sys.exit("san-calibrate: no usr/lib/opkg/status under %s (give build_dir/target-*/root-* or an unpacked rootfs)" % rootfs)
    return d


def opkg_versions(rootfs):
    """{package: version} from the opkg status file."""
    out, pkg = {}, None
    with open(os.path.join(opkg_dir(rootfs), "status"), errors="replace") as fh:
        for line in fh:
            if line.startswith("Package: "):
                pkg = line[9:].strip()
            elif line.startswith("Version: ") and pkg:
                out[pkg] = line[9:].strip()
    return out


def opkg_owners(rootfs):
    """{file basename: {packages}} from the opkg info/*.list files (regular listing, symlinks included)."""
    info = os.path.join(opkg_dir(rootfs), "info")
    out = collections.defaultdict(set)
    for f in os.listdir(info):
        if not f.endswith(".list"):
            continue
        with open(os.path.join(info, f), errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if line and not line.endswith("/"):
                    out[os.path.basename(line)].add(f[:-5])
    return out


def manifest_versions(path):
    """{package: version} from an image manifest ("name - version" lines)."""
    out = {}
    with open(path, errors="replace") as fh:
        for line in fh:
            parts = line.rstrip("\n").split(" - ", 1)
            if len(parts) == 2 and parts[0].strip():
                out[parts[0].strip()] = parts[1].strip()
    return out


def system_version(rootfs):
    try:
        with open(os.path.join(rootfs, "etc", "openwrt_release")) as fh:
            for line in fh:
                m = re.match(r"DISTRIB_DESCRIPTION=['\"]?(.*?)['\"]?\s*$", line)
                if m:
                    return m.group(1)
    except OSError:
        pass
    return None


def read_provenance(opts_dir):
    """Return ([(binary, package, pkg_version, sys_version)], {header key: value})."""
    path = os.path.join(opts_dir, "PROVENANCE")
    if not os.path.isfile(path):
        sys.exit("san-calibrate: not found: %s" % path)
    rows, meta = [], {}
    with open(path) as fh:
        for n, line in enumerate(fh, 1):
            line = line.rstrip("\n")
            m = re.match(r"# (heavy-mb): (\d+)$", line)
            if m:
                meta[m.group(1)] = int(m.group(2))
            if not line or line.startswith("#"):
                continue
            f = line.split("\t")
            if len(f) != 4 or not all(x.strip() for x in f):
                sys.exit("san-calibrate: %s:%d: want 4 TAB separated fields" % (path, n))
            rows.append(tuple(f))
    return rows, meta


def cmd_publish(argv):
    ap = argparse.ArgumentParser(prog="san-calibrate.py publish",
                                 description="Write the committed .opts files and PROVENANCE from a calibration dir.")
    ap.add_argument("calib_dir")
    ap.add_argument("--opts-dir", required=True, help="e.g. package/utils/sanitizer-opts/files/opts")
    ap.add_argument("--rootfs", required=True, help="build_dir/target-*/root-* or an unpacked rootfs of the calibrated image")
    ap.add_argument("--system-version", help="override DISTRIB_DESCRIPTION of ROOTFS/etc/openwrt_release")
    ap.add_argument("--heavy-mb", type=int, default=64, help="a file only when the suggestion is above this (default 64, the 16 GB tier)")
    ap.add_argument("--force", action="store_true", help="replace the .opts files and PROVENANCE that are already in --opts-dir")
    a = ap.parse_args(argv)

    if not os.path.isdir(a.calib_dir):
        sys.exit("san-calibrate: not a directory: %s" % a.calib_dir)
    sysver = a.system_version or system_version(a.rootfs)
    if not sysver or "\t" in sysver or "\n" in sysver:
        sys.exit("san-calibrate: no usable system version (give --system-version)")
    values = calib_values(a.calib_dir)
    heavy = {e: mb for e, mb in values.items() if mb > a.heavy_mb}
    versions, owners = opkg_versions(a.rootfs), opkg_owners(a.rootfs)

    rows, errors = [], []
    for exe in sorted(heavy):
        if exe in RESERVED:
            errors.append("%s: reserved (shipped by sanitizer-shim)" % exe)
            continue
        if not SAFE_RE.match(exe):
            errors.append("%s: not usable as a file name" % exe)
            continue
        pk = owners.get(exe, set())
        if len(pk) != 1:
            errors.append("%s: %s" % (exe, "no package ships a file of this name" if not pk else "several packages ship it: " + ", ".join(sorted(pk))))
            continue
        pkg = next(iter(pk))
        if pkg not in versions:
            errors.append("%s: package %s has no Version in the opkg status" % (exe, pkg))
            continue
        rows.append((exe, pkg, versions[pkg], sysver, heavy[exe]))
    if errors:
        sys.exit("san-calibrate: publish refused, nothing written:\n  " + "\n  ".join(errors))

    os.makedirs(a.opts_dir, exist_ok=True)
    old = [f for f in os.listdir(a.opts_dir) if f.endswith(".opts") or f == "PROVENANCE"]
    if old and not a.force:
        sys.exit("san-calibrate: %s already has %s (use --force to replace)" % (a.opts_dir, ", ".join(sorted(old)[:5])))
    for f in old:
        os.remove(os.path.join(a.opts_dir, f))
    for exe, pkg, ver, sv, mb in rows:
        with open(os.path.join(a.opts_dir, exe + ".opts"), "w") as fh:
            fh.write("quarantine_size_mb=%d\n" % mb)
    with open(os.path.join(a.opts_dir, "PROVENANCE"), "w") as fh:
        fh.write(PROV_HEAD)
        fh.write("# heavy-mb: %d\n" % a.heavy_mb)
        for exe, pkg, ver, sv, mb in rows:
            fh.write("\t".join((exe, pkg, ver, sv)) + "\n")
    sys.stderr.write("san-calibrate: %d of %d calibrated executables above %d MB; %d .opts file(s) in %s\n"
                     % (len(rows), len(values), a.heavy_mb, len(rows), a.opts_dir))
    for exe, pkg, ver, sv, mb in rows:
        sys.stderr.write("  %s=%d MB  (%s %s)\n" % (exe, mb, pkg, ver))


def cmd_drift(argv):
    ap = argparse.ArgumentParser(prog="san-calibrate.py drift",
                                 description="Report committed .opts files that no longer match a build.")
    ap.add_argument("opts_dir", help="directory with PROVENANCE and the .opts files")
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--manifest", help="image manifest of the build (bin/targets/*/*.manifest)")
    g.add_argument("--rootfs", help="rootfs of the build (usr/lib/opkg/status)")
    ap.add_argument("--calibration", help="calibration dir of a newer run: report NEW and LIGHT entries")
    ap.add_argument("--heavy-mb", type=int, help="threshold for NEW/LIGHT (default: the heavy-mb header of PROVENANCE, else 64)")
    ap.add_argument("--fail-on-drift", action="store_true", help="exit 1 when anything is reported (default: always 0)")
    a = ap.parse_args(argv)

    rows, meta = read_provenance(a.opts_dir)
    thr = a.heavy_mb if a.heavy_mb is not None else meta.get("heavy-mb", 64)
    build = manifest_versions(a.manifest) if a.manifest else opkg_versions(a.rootfs)
    if not build:
        sys.exit("san-calibrate: no packages read from the build")

    out, seen = [], set()
    for exe, pkg, ver, sv in rows:
        seen.add(exe)
        if pkg not in build:
            out.append("MISSING %s package=%s calibrated=%s build=(not in the build)" % (exe, pkg, ver))
        elif build[pkg] != ver:
            out.append("STALE %s package=%s calibrated=%s build=%s (calibrated on: %s)" % (exe, pkg, ver, build[pkg], sv))
    files = {f[:-5] for f in os.listdir(a.opts_dir) if f.endswith(".opts")}
    for exe in sorted(files - seen):
        out.append("INCONSISTENT %s has an .opts file but no PROVENANCE line" % exe)
    for exe in sorted(seen - files):
        out.append("INCONSISTENT %s has a PROVENANCE line but no .opts file" % exe)
    if a.calibration:
        cal = calib_values(a.calibration)
        for exe in sorted(cal):
            if cal[exe] > thr and exe not in seen and exe not in RESERVED:
                out.append("NEW %s suggested=%d MB (> %d), no entry" % (exe, cal[exe], thr))
        for exe in sorted(seen):
            if exe in cal and cal[exe] <= thr:
                out.append("LIGHT %s suggested=%d MB (<= %d) in the newer calibration, entry could go" % (exe, cal[exe], thr))
            elif exe not in cal:
                out.append("LIGHT %s not in the newer calibration (short-lived or idle), entry could go" % exe)
    for line in out:
        print(line)
    print("drift: %d entr%s in PROVENANCE, %d finding(s)" % (len(rows), "y" if len(rows) == 1 else "ies", len(out)))
    if out and a.fail_on_drift:
        sys.exit(1)


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "publish":
        cmd_publish(sys.argv[2:])
    elif len(sys.argv) > 1 and sys.argv[1] == "drift":
        cmd_drift(sys.argv[2:])
    else:
        cmd_suggest()


if __name__ == "__main__":
    main()
