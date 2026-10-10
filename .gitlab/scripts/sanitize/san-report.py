#!/usr/bin/env python3
"""san-report.py: parse sanitizer reports and write one row per UNIQUE finding.

Input: one or more report directories or tarballs (sanitizer-reports.tar.gz layout, files named
report.<exe>.<pid>[.ubsan]; layout ext/sanitizer/report). Best on the output of san-symbolize.py;
unsymbolized reports work too (frames are then module+offset).

Dedup keys:
  ASan error   asan | type | top 3 frames of the ACCESS stack
  LSan leak    lsan | top 3 frames of the ALLOCATION stack (Direct and Indirect leaks with the same stack merge)
  UBSan error  ubsan | check | location (file:line, package directory without version)
  ODR          asan | odr-violation | the global's name
A frame is "func@file" when symbolized (no line number, so an edit does not make a finding new),
else "module+0xoff" (module basename). Frames of the sanitizer runtime (libasan, libubsan, ld-linux)
are skipped; "<unknown module>" frames count as "<unknown>".
Not findings, only counted: "Live Heap Allocations" memory profiles (SIGRTMIN+3 output), empty files.

Usage:
  san-report.py INPUT [INPUT...] [-o OUTDIR | --tsv FILE --md FILE] [--top N] [--depth N] [-q]
  --depth N  frames in the ASan/LSan key (default 3). Allocator wrappers such as
             CRYPTO_zalloc fill the top 3 frames of many leaks, so a larger N splits them by caller.
Output: OUTDIR/san-findings.tsv and OUTDIR/san-findings.md (the markdown goes to stdout without -o/--md).
OUTDIR/san-unparsed.txt lists the report files that hold a sanitizer report (an ERROR line, a runtime error, a
leak, a SUMMARY line) but gave no record, for example because of an unknown line format; san-summary.py fails
the run when it is not empty.
TSV columns: id (sha1 of key, 10 hex), kind (asan|lsan|ubsan), type, count (records), files, exes, pids,
  first_file, bytes (sum of leaked bytes, lsan only), top_frame, key, stack (first 8 frames, " | " separated).
"""
import argparse
import collections
import hashlib
import os
import re
import sys
import tarfile

ERR_RE = re.compile(r"^==(?:[^=]*==)?\d+==ERROR: (Address|Leak|Thread|Memory|HWAddress)Sanitizer: (.*)$")
# A report file with one of these lines but without any record was written in a format the parser does not know.
# Warnings only ("Running thread N was not suspended", "ASan is ignoring requested __asan_handle_no_return") have none.
UNPARSED_RE = re.compile(r"ERROR: \w*Sanitizer|: runtime error: |(Direct|Indirect) leak of \d+ byte|SUMMARY: \w*Sanitizer")
LEAK_RE = re.compile(r"^(Direct|Indirect) leak of (\d+) byte\(s\) in (\d+) object\(s\) allocated from:")
RTE_RE = re.compile(r"^(\S.*?): runtime error: (.*)$")
FRAME_RE = re.compile(r"^\s*#(?P<n>\d+)\s+(?P<addr>0x[0-9a-fA-F]+)\s*(?P<rest>.*)$")
MOD_RE = re.compile(r"\((?P<mod>[^()]*?)\+0x(?P<off>[0-9a-fA-F]+)\)")
RUNTIME_RE = re.compile(r"^(libasan|libubsan|liblsan|libtsan|libhwasan|ld-linux)")
NAME_RE = re.compile(r"^report\.(?P<exe>.+?)\.(?P<pid>\d+)(?P<ub>\.ubsan)?$")
VER_RE = re.compile(r"^(.*?)-(?:v?\d[0-9A-Za-z._~+-]*)$")
DEPTH = 3     # frames in the dedup key (--depth)

# message of a UBSan "runtime error" -> check name (same names as the SANREPORT types)
UBSAN_CHECKS = [
    (r"misaligned address", "misaligned-pointer-use"),
    (r"^left shift of .* cannot be represented", "invalid-shift-base"),
    (r"^shift exponent", "invalid-shift-exponent"),
    (r"^right shift of .* cannot be represented", "invalid-shift-base"),
    (r"null pointer passed as argument", "invalid-null-argument"),
    (r"null pointer returned from function", "invalid-null-return"),
    (r"applying (non-zero )?offset .*null pointer|pointer index expression", "pointer-overflow"),
    (r"(load of|store to|member (access|call) (within|on)|reference binding to) null pointer", "null-pointer-use"),
    (r"load of value .*not a valid value for type '_?[bB]ool'", "invalid-bool-value"),
    (r"load of value .*not a valid value for type", "invalid-enum-value"),
    (r"signed integer overflow", "signed-integer-overflow"),
    (r"unsigned integer overflow", "unsigned-integer-overflow"),
    (r"division by zero", "integer-divide-by-zero"),
    (r"index .* out of bounds", "out-of-bounds-index"),
    (r"negation of", "negate-overflow"),
    (r"variable length array bound", "vla-bound-not-positive"),
    (r"call to function .* through pointer to incorrect function type", "function-type-mismatch"),
    (r"downcast of|member call on address .* which does not point to an object", "vptr"),
    (r"execution reached the end of a value-returning function", "return"),
    (r"implicit conversion", "implicit-conversion"),
    (r"pointer overflow", "pointer-overflow"),
]


def short_path(p):
    """Drop the build prefix and the version of the package directory."""
    p = p.replace("//", "/")
    m = re.search(r"/build_dir/(?:target|toolchain|host|hostpkg)[^/]*/(.*)$", p)
    if m:
        parts = m.group(1).split("/")
        v = VER_RE.match(parts[0])
        if v:
            parts[0] = v.group(1)
        return "/".join(parts)
    m = re.search(r"/staging_dir/(.*)$", p)
    if m:
        return "staging/" + m.group(1)
    return p


class Frame:
    __slots__ = ("idx", "module", "off", "func", "loc", "text")

    def __init__(self, line):
        m = FRAME_RE.match(line)
        self.idx = int(m.group("n"))
        rest = m.group("rest")
        self.text = line.strip()
        mm = MOD_RE.search(rest)
        self.module = os.path.basename(mm.group("mod")) if mm else None
        self.off = mm.group("off").lower() if mm else None
        self.func = self.loc = None
        # symbolized by san-symbolize.py: "... (mod+0xoff) in func file:line [<- outer file:line]"
        # or by ASan itself: "in func file:line (mod+0xoff)" / "in func file:line"
        head = rest[:mm.start()].strip() if mm else rest.strip()
        tail = rest[mm.end():] if mm else ""
        body = None
        if " in " in tail:
            body = tail.split(" in ", 1)[1]
        elif head.startswith("in "):
            body = head[3:]
        if body is not None:
            body = body.split(" <- ")[0].strip()
            if " " in body:
                f, where = body.rsplit(" ", 1)
            else:
                f, where = body, ""
            self.func = f.strip() or None
            # location "file:line", "file:?" (function known, line not) or ":?" (nothing)
            self.loc = where if where and not where.startswith((":", "?")) else None

    def runtime(self):
        return bool(self.module and RUNTIME_RE.match(self.module))

    def token(self):
        if self.func and self.func != "??":
            f = self.func
            if self.loc:
                return "%s@%s" % (f, short_path(re.sub(r"(:[\d?]+)+$", "", self.loc)))
            return f
        if self.module:
            return "%s+0x%s" % (self.module, self.off)
        return "<unknown>"

    def brief(self):
        if self.func and self.func != "??":
            if self.loc:
                m = re.match(r"^(.*?)((?::[\d?]+)*)$", self.loc)
                return "%s (%s%s)" % (self.func, os.path.basename(m.group(1)), m.group(2))
            return "%s (%s)" % (self.func, self.module or "?")
        if self.module:
            return "%s+0x%s" % (self.module, self.off)
        return "<unknown module>"


class Record:
    def __init__(self, kind, typ, exe, pid, fname):
        self.kind, self.type, self.exe, self.pid, self.file = kind, typ, exe, pid, fname
        self.stacks = collections.defaultdict(list)
        self.nbytes = 0
        self.nobj = 0
        self.loc = ""
        self.extra = ""        # odr: global name

    def key_frames(self):
        name = "alloc" if self.kind == "lsan" else "access"
        fr = self.stacks.get(name, [])
        use = [f for f in fr if not f.runtime()]
        if not use:
            use = fr
        return use[:DEPTH]

    def key(self):
        if self.kind == "ubsan":
            return "ubsan|%s|%s" % (self.type, self.loc)
        if self.type == "odr-violation":
            return "asan|odr-violation|%s" % (self.extra or "?")
        toks = "|".join(f.token() for f in self.key_frames()) or "<no stack>"
        if self.kind == "lsan":
            return "lsan|%s" % toks
        return "asan|%s|%s" % (self.type, toks)


def ubsan_check(msg):
    for rx, name in UBSAN_CHECKS:
        if re.search(rx, msg):
            return name
    return "other"


def asan_type(rest):
    t = re.split(r" on | at |:| \(", rest, maxsplit=1)[0].strip()
    t = re.sub(r"0x[0-9a-fA-F]+|\d+", "N", t)
    return "-".join(t.split())[:60] or "unknown"


def parse_text(fname, text):
    m = NAME_RE.match(os.path.basename(fname))
    exe, pid = (m.group("exe"), m.group("pid")) if m else (os.path.basename(fname), "0")
    recs, cur, stack = [], None, None
    for line in text.split("\n"):
        e = ERR_RE.match(line)
        if e:
            if e.group(1) == "Leak":
                cur, stack = None, None
                if "fatal error" in e.group(2):
                    cur = Record("lsan", "lsan-fatal", exe, pid, fname)
                    cur.stacks["alloc"].append(Frame("#0 0x0 (lsan-fatal+0x0)"))
                    cur.extra = e.group(2)[:80]
                    recs.append(cur)
                    cur = None
                continue
            cur = Record("asan", asan_type(e.group(2)), exe, pid, fname)
            recs.append(cur)
            stack = "access"
            continue
        lk = LEAK_RE.match(line)
        if lk:
            cur = Record("lsan", "leak", exe, pid, fname)
            cur.nbytes, cur.nobj = int(lk.group(2)), int(lk.group(3))
            recs.append(cur)
            stack = "alloc"
            continue
        r = RTE_RE.match(line)
        if r:
            loc = r.group(1)
            lm = re.match(r"^(.*?):(\d+)(?::\d+)?$", loc)
            cur = Record("ubsan", ubsan_check(r.group(2)), exe, pid, fname)
            cur.loc = "%s:%s" % (short_path(lm.group(1)), lm.group(2)) if lm else short_path(loc)
            recs.append(cur)
            stack = "access"
            continue
        if cur is None:
            continue
        if FRAME_RE.match(line):
            if stack:
                cur.stacks[stack].append(Frame(line))
            continue
        s = line.strip()
        if not s:
            stack = None
        elif cur.kind == "asan":
            if s.startswith(("freed by thread", "previously freed")):
                stack = "free"
            elif s.startswith(("previously allocated by thread", "allocated by thread")):
                stack = "alloc"
            elif re.match(r"Address 0x[0-9a-f]+ is located in stack", s):
                stack = "frame"
            elif s.startswith("These globals were registered"):
                stack = None
            elif re.match(r"\[\d\]:", s):
                stack = "odr"
            else:
                g = re.match(r"\[1\] size=\d+ '(.*?)'", s)
                if g and cur.type == "odr-violation":
                    cur.extra = g.group(1)
                elif s.startswith("SUMMARY:"):
                    stack = None
    return recs


def read_input(src):
    if os.path.isdir(src):
        for dp, dn, fn in os.walk(src):
            dn.sort()
            for f in sorted(fn):
                if f.startswith("report."):
                    p = os.path.join(dp, f)
                    with open(p, "rb") as fh:
                        yield os.path.relpath(p, src), fh.read().decode("utf-8", errors="replace")
    elif tarfile.is_tarfile(src):
        with tarfile.open(src, "r:*") as tf:
            for m in tf:
                if m.isfile() and os.path.basename(m.name).startswith("report."):
                    yield m.name.lstrip("./"), tf.extractfile(m).read().decode("utf-8", errors="replace")
    elif os.path.isfile(src):
        with open(src, "rb") as fh:
            yield os.path.basename(src), fh.read().decode("utf-8", errors="replace")
    else:
        sys.exit("san-report: input not found: %s" % src)


def esc(s):
    return s.replace("\t", " ").replace("\n", " ")


def md_cell(s, n=110):
    s = s.replace("|", "\\|").replace("\n", " ")
    return s if len(s) <= n else s[:n - 3] + "..."


def main():
    ap = argparse.ArgumentParser(prog="san-report.py", description="Deduplicate sanitizer findings of a run.")
    ap.add_argument("inputs", nargs="+")
    ap.add_argument("-o", "--out", help="output directory (san-findings.tsv, san-findings.md)")
    ap.add_argument("--tsv")
    ap.add_argument("--md")
    ap.add_argument("--top", type=int, default=25, help="rows with a full sample stack in the markdown (default 25)")
    ap.add_argument("--depth", type=int, default=3, help="frames of the stack in the ASan/LSan dedup key (default 3)")
    ap.add_argument("-q", action="store_true")
    a = ap.parse_args()
    global DEPTH
    DEPTH = max(1, a.depth)

    rows = {}
    nfiles = nprof = nempty = nrec = 0
    unparsed = []
    for src in a.inputs:
        for fname, text in read_input(src):
            nfiles += 1
            if not text.strip():
                nempty += 1
                continue
            if text.lstrip().startswith("Live Heap Allocations") and "Sanitizer:" not in text:
                nprof += 1
                continue
            recs = parse_text(fname, text)
            if not recs:
                nempty += 1
                if UNPARSED_RE.search(text):
                    unparsed.append(fname)
                continue
            for r in recs:
                nrec += 1
                k = r.key()
                row = rows.get(k)
                if row is None:
                    row = rows[k] = {"key": k, "kind": r.kind, "type": r.type, "count": 0, "files": set(), "exes": collections.Counter(),
                                     "pids": set(), "first": fname, "bytes": 0, "sample": r}
                row["count"] += 1
                row["files"].add(fname)
                row["exes"][r.exe] += 1
                row["pids"].add((r.exe, r.pid))
                row["bytes"] += r.nbytes

    out = sorted(rows.values(), key=lambda x: (-x["count"], x["kind"], x["key"]))
    tsv = ["id\tkind\ttype\tcount\tfiles\texes\tpids\tfirst_file\tbytes\ttop_frame\tkey\tstack"]
    for r in out:
        r["id"] = hashlib.sha1(r["key"].encode("utf-8", "replace")).hexdigest()[:10]
        s = r["sample"]
        if s.kind == "ubsan":
            frames = s.stacks.get("access", [])
            top = s.loc
        else:
            frames = s.stacks.get("alloc" if s.kind == "lsan" else "access", [])
            kf = s.key_frames()
            top = kf[0].brief() if kf else (s.extra or "-")
            if s.type == "odr-violation":
                top = s.extra
        r["top"] = top
        r["frames"] = frames
        exes = ",".join(e for e, _ in r["exes"].most_common(6)) + ("+%d" % (len(r["exes"]) - 6) if len(r["exes"]) > 6 else "")
        pids = sorted(int(p) for _, p in r["pids"])
        pidtxt = ",".join(str(p) for p in pids[:6]) + ("+%d" % (len(pids) - 6) if len(pids) > 6 else "")
        r["exes_txt"], r["pids_txt"] = exes, pidtxt
        tsv.append("\t".join(esc(str(x)) for x in (
            r["id"], r["kind"], r["type"], r["count"], len(r["files"]), exes, pidtxt, r["first"], r["bytes"] if r["kind"] == "lsan" else "",
            top, r["key"], " | ".join(f.brief() for f in frames[:8]))))

    cnt = collections.Counter(r["kind"] for r in out)
    md = ["# Sanitizer findings", "",
          "%d unique findings from %d records in %d report files (asan %d, lsan %d, ubsan %d); %d memory profiles and %d empty files (or files with warnings only) not counted."
          % (len(out), nrec, nfiles, cnt["asan"], cnt["lsan"], cnt["ubsan"], nprof, nempty), "",
          "Dedup: ASan = type + top 3 access frames; LSan = top 3 allocation frames; UBSan = check + file:line; ODR = global name.", ""]
    if unparsed:
        md += ["**%d report file(s) with a sanitizer report that no parser rule matched (not in the table below):** %s" % (
            len(unparsed), ", ".join(unparsed[:10]) + (" ..." if len(unparsed) > 10 else "")), ""]
    md += ["| # | id | kind | type | count | exes | first file | top frame |", "|---|---|---|---|---|---|---|---|"]
    for i, r in enumerate(out, 1):
        md.append("| %d | %s | %s | %s | %d | %s | %s | %s |" % (
            i, r["id"], r["kind"], md_cell(r["type"], 40), r["count"], md_cell(r["exes_txt"], 40), os.path.basename(r["first"]), md_cell(r["top"])))
    md += ["", "## Sample stacks (top %d rows)" % min(a.top, len(out)), ""]
    for i, r in enumerate(out[:a.top], 1):
        md.append("### %d. %s %s %s (%d)" % (i, r["kind"], r["type"], r["id"], r["count"]))
        md.append("")
        md.append("```")
        md.append("key: " + r["key"][:300])
        for f in r["frames"][:10]:
            md.append(f.text[:300])
        md.append("```")
        md.append("")

    tsv_path, md_path = a.tsv, a.md
    if a.out:
        os.makedirs(a.out, exist_ok=True)
        tsv_path = tsv_path or os.path.join(a.out, "san-findings.tsv")
        md_path = md_path or os.path.join(a.out, "san-findings.md")
    if a.out:
        # san-summary.py fails the run when this file lists a report that was not parsed
        with open(os.path.join(a.out, "san-unparsed.txt"), "w") as fh:
            fh.write("".join(f + "\n" for f in unparsed))
    if tsv_path:
        with open(tsv_path, "w") as fh:
            fh.write("\n".join(tsv) + "\n")
    if md_path:
        with open(md_path, "w") as fh:
            fh.write("\n".join(md) + "\n")
    elif not a.q:
        sys.stdout.write("\n".join(md) + "\n")
    if unparsed:
        sys.stderr.write("san-report: %d report file(s) with a sanitizer report but no parsed record, e.g. %s\n" % (len(unparsed), unparsed[0]))
    if not a.q:
        sys.stderr.write("san-report: %d files, %d records, %d unique findings (asan %d, lsan %d, ubsan %d), %d profiles, %d empty\n"
                         % (nfiles, nrec, len(out), cnt["asan"], cnt["lsan"], cnt["ubsan"], nprof, nempty))


if __name__ == "__main__":
    main()
