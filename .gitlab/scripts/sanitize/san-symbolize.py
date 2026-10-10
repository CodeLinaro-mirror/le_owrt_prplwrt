#!/usr/bin/env python3
"""san-symbolize.py: symbolize sanitizer reports after the run.

The image is stripped and runs with symbolize=0, so a report frame looks like
    #3 0x7f62d289a4ca  (/usr/lib/libtlvf.so.2026+0x4b3e4ca)
This tool maps every module path to its UNSTRIPPED file in the build tree, checks that the GNU
build-id of that file equals the build-id of the stripped rootfs file, and appends the answer of
addr2line to the frame:
    #3 0x7f62d289a4ca  (/usr/lib/libtlvf.so.2026+0x4b3e4ca) in func /path/file.c:42 [<- outer file:line]
The part after " <- " lists the callers of an inlined function (addr2line -i).

Usage:
  san-symbolize.py INPUT -o OUTDIR [--tree DIR] [--rootfs DIR] [--addr2line PATH]
                   [--readelf PATH] [--runtime] [--strict] [-q]
  INPUT   a directory or a tarball (sanitizer-reports.tar.gz) holding files named report.<exe>.<pid>[.ubsan]
          (layout ext/sanitizer/...); the layout is copied to OUTDIR.
  --tree  a prplOS build tree, or the directory that holds the extracted sanitize-symbols.tar.xz of the build
          job (export-symbols.py): both have build_dir/target-*_glibc. Default: the current directory.
Output: OUTDIR/<same relative paths>, OUTDIR/symbolize-summary.md and OUTDIR/symbolize-summary.tsv
        (one row per module: ok / mismatch / not-found / runtime / unknown). The summary is also printed.
Exit: 0 done (also with mismatches), 3 with --strict and at least one mismatch or not-found module,
      2 usage or setup error.

Rules:
  - Module path -> rootfs file: symlinks are followed inside the rootfs (build_dir/target-*/root-x86).
  - Unstripped candidates: build_dir/target-*/**/.pkgdir/<pkg>/<path>, then ipkg-*/<pkg>/<path> and
    ipkg-install/<path> (a candidate counts only if it still has .symtab or .debug_info).
  - build-id differs: the module is NOT symbolized and is marked mismatch.
  - The sanitize profile links with --build-id. When neither file has a build-id, the identity check
    is the content of the allocated sections (every section of the stripped file must equal the same
    section of the unstripped one; stripping never changes them). Summary column "detail" says which
    method proved the match. If only one of the two has a build-id: mismatch. In the exported
    symbols archive an ELF without build-id is kept whole on both sides, so this proof works there too.
  - Frames above #0 of a stack use offset-1 (the pc is a return address). Offsets are relative to the
    load address, which equals the ELF virtual address for PIE and shared objects.
  - The sanitizer runtime (libasan, libubsan, ld-linux) is not symbolized unless --runtime is given.
Only the Python standard library and the target binutils are used (readelf and addr2line from
staging_dir/toolchain-*_glibc/bin, else the host ones).
"""
import argparse
import collections
import glob
import hashlib
import os
import re
import struct
import subprocess
import sys
import tarfile


FRAME_RE = re.compile(r"^(?P<head>\s*#(?P<n>\d+)\s+0x[0-9a-fA-F]+)\s+\((?P<mod>[^()]*?)\+0x(?P<off>[0-9a-fA-F]+)\)(?P<tail>.*)$")
RUNTIME_RE = re.compile(r"^(libasan|libubsan|liblsan|libtsan|libhwasan|ld-linux)")
HEADER_RE = re.compile(r"^0x[0-9a-fA-F]+$")
DISCR_RE = re.compile(r"\s*\(discriminator \d+\)")


def die(msg, code=2):
    sys.stderr.write("san-symbolize: %s\n" % msg)
    sys.exit(code)


def find_tool(tree, name, override):
    if override:
        return override
    for p in sorted(glob.glob(os.path.join(tree, "staging_dir", "toolchain-*_glibc", "bin", "x86_64-openwrt-linux-gnu-" + name))):
        if os.access(p, os.X_OK):
            return p
    return name


def read_input(src):
    """Return a list of (relative path, text) for every report.* file."""
    out = []
    if os.path.isdir(src):
        for dp, dn, fn in os.walk(src):
            dn.sort()
            for f in sorted(fn):
                if f.startswith("report."):
                    p = os.path.join(dp, f)
                    with open(p, "rb") as fh:
                        out.append((os.path.relpath(p, src), fh.read().decode("utf-8", errors="surrogateescape")))
    elif tarfile.is_tarfile(src):
        with tarfile.open(src, "r:*") as tf:
            for m in tf:
                if not m.isfile() or not os.path.basename(m.name).startswith("report."):
                    continue
                parts = [x for x in m.name.split("/") if x not in ("", ".", "..")]
                data = tf.extractfile(m).read()
                out.append(("/".join(parts), data.decode("utf-8", errors="surrogateescape")))
    elif os.path.isfile(src):
        with open(src, "rb") as fh:
            out.append((os.path.basename(src), fh.read().decode("utf-8", errors="surrogateescape")))
    else:
        die("input not found: %s" % src)
    return out


class Elf:
    """readelf results per file, cached."""

    def __init__(self, readelf):
        self.readelf = readelf
        self.cache = {}

    def info(self, path):
        """(build_id or None, has_symbols)."""
        if path in self.cache:
            return self.cache[path]
        try:
            r = subprocess.run([self.readelf, "-W", "-n", "-S", path], capture_output=True, text=True, errors="replace", timeout=120)
            txt = r.stdout
        except (OSError, subprocess.TimeoutExpired):
            txt = ""
        m = re.search(r"Build ID:\s*([0-9a-fA-F]+)", txt)
        bid = m.group(1).lower() if m else None
        syms = bool(re.search(r"\]\s+\.(symtab|debug_info)\s", txt))
        self.cache[path] = (bid, syms)
        return self.cache[path]

    def alloc_sections(self, path):
        """{section name: (addr, size, sha1)} for the allocated, non-NOBITS sections of an ELF64 LE file.

        Fallback identity when a build has no GNU build-id: stripping never changes the content of
        allocated sections, so the stripped file's sections must all equal the unstripped file's."""
        key = ("alloc", path)
        if key in self.cache:
            return self.cache[key]
        res = None
        try:
            with open(path, "rb") as fh:
                data = fh.read()
            if data[:6] == b"\x7fELF\x02\x01" and len(data) > 0x40:
                shoff, = struct.unpack_from("<Q", data, 0x28)
                shentsize, shnum, shstrndx = struct.unpack_from("<HHH", data, 0x3A)
                secs = []
                for i in range(shnum):
                    o = shoff + i * shentsize
                    name, typ, flags, addr, off, size = struct.unpack_from("<IIQQQQ", data, o)
                    secs.append((name, typ, flags, addr, off, size))
                stroff = secs[shstrndx][4]
                res = {}
                for name, typ, flags, addr, off, size in secs:
                    if not (flags & 2) or typ == 8:
                        continue
                    end = data.index(b"\0", stroff + name)
                    nm = data[stroff + name:end].decode("ascii", "replace")
                    res[nm] = (addr, size, hashlib.sha1(data[off:off + size]).hexdigest())
        except (OSError, struct.error, ValueError, IndexError):
            res = None
        self.cache[key] = res
        return res

    def same_alloc(self, stripped, full):
        """True if every allocated section of the stripped file is in the full file with equal content."""
        a, b = self.alloc_sections(stripped), self.alloc_sections(full)
        if not a or not b or ".text" not in a:
            return False
        # .dynstr/.dynamic are skipped: the OpenWrt install step rewrites RPATH (patchelf) in the
        # packaged copy, and nothing else in them matters for symbolization.
        return all(b.get(n) == v for n, v in a.items() if n not in (".dynstr", ".dynamic"))


def resolve_in_root(root, path):
    """Follow symlinks inside root. Return (host path, rootfs path) or (None, None)."""
    stack = list(reversed([p for p in path.split("/") if p]))
    cur = []
    hops = 0
    while stack:
        comp = stack.pop()
        if comp == ".":
            continue
        if comp == "..":
            if cur:
                cur.pop()
            continue
        host = os.path.join(root, *cur, comp)
        if os.path.islink(host):
            hops += 1
            if hops > 40:
                return None, None
            tgt = os.readlink(host)
            if tgt.startswith("/"):
                cur = []
            stack.extend(reversed([x for x in tgt.split("/") if x]))
            continue
        cur.append(comp)
    host = os.path.join(root, *cur)
    if not os.path.isfile(host):
        return None, None
    return host, "/" + "/".join(cur)


class Resolver:
    def __init__(self, tree, rootfs, elf, runtime):
        self.elf = elf
        self.runtime = runtime
        bd = sorted(glob.glob(os.path.join(tree, "build_dir", "target-*_glibc")))
        if not bd:
            die("no build_dir/target-*_glibc under %s" % tree)
        self.rootfs = rootfs
        if not self.rootfs:
            for t in bd:
                if os.path.isdir(os.path.join(t, "root-x86")):
                    self.rootfs = os.path.join(t, "root-x86")
                    break
        if not self.rootfs or not os.path.isdir(self.rootfs):
            die("rootfs not found (build_dir/target-*_glibc/root-x86); use --rootfs")
        pk, ip = [], []
        for t in bd:
            for pat in ("*/.pkgdir/*", "*/*/.pkgdir/*"):
                pk.extend(sorted(glob.glob(os.path.join(t, pat))))
            for pat in ("*/ipkg-*/*", "*/*/ipkg-*/*"):
                ip.extend(sorted(x for x in glob.glob(os.path.join(t, pat)) if os.path.isdir(x)))
            for pat in ("*/ipkg-install", "*/*/ipkg-install"):
                ip.extend(sorted(glob.glob(os.path.join(t, pat))))
        self.roots = pk + ip
        self.cache = {}

    def candidates(self, rel):
        seen, out = set(), []
        for r in self.roots:
            p = r + rel
            if os.path.isfile(p):
                rp = os.path.realpath(p)
                if rp not in seen:
                    seen.add(rp)
                    out.append(p)
        return out

    def resolve(self, mod):
        """Return (status, unstripped path or '', detail)."""
        if mod in self.cache:
            return self.cache[mod]
        res = self._resolve(mod)
        self.cache[mod] = res
        return res

    def _resolve(self, mod):
        if not mod.startswith("/"):
            return ("unknown", "", "not a file path")
        if RUNTIME_RE.match(os.path.basename(mod)) and not self.runtime:
            return ("runtime", "", "sanitizer/loader runtime, not symbolized")
        host, rel = resolve_in_root(self.rootfs, mod)
        if not host:
            return ("not-found", "", "no such file in the rootfs")
        rbid, _ = self.elf.info(host)
        cands = self.candidates(rel)
        full = [c for c in cands if self.elf.info(c)[1]]
        if not cands:
            return ("not-found", "", "no copy of %s under build_dir" % rel)
        if not full:
            return ("not-found", "", "only stripped copies of %s under build_dir" % rel)
        for c in full:
            cbid = self.elf.info(c)[0]
            if rbid and cbid:
                if cbid == rbid:
                    return ("ok", c, "build-id %s" % rbid)
            elif not rbid and not cbid:
                # The prplOS build links without --build-id: compare the allocated sections instead.
                if self.elf.same_alloc(host, c):
                    return ("ok", c, "alloc-hash (no build-id in either file)")
        ids = ",".join(sorted({(self.elf.info(c)[0] or "none")[:12] for c in full}))
        return ("mismatch", "", "rootfs %s, unstripped %s%s" % (
            (rbid or "no build-id")[:12], ids, "" if rbid else "; allocated sections differ"))


def run_addr2line(a2l, path, offs):
    """Return {off: [(func, loc), ...] or None}; None for an unresolved address. Raises RuntimeError."""
    inp = "".join("0x%x\n" % o for o in offs)
    try:
        r = subprocess.run([a2l, "-a", "-f", "-i", "-C", "-e", path], input=inp, capture_output=True, text=True, errors="replace", timeout=900)
    except (OSError, subprocess.TimeoutExpired) as e:
        raise RuntimeError("addr2line failed: %s" % e)
    entries = []
    for line in r.stdout.splitlines():
        if HEADER_RE.match(line):
            entries.append([])
        elif entries:
            entries[-1].append(line)
    if len(entries) != len(offs):
        raise RuntimeError("addr2line gave %d answers for %d addresses" % (len(entries), len(offs)))
    res = {}
    for o, lines in zip(offs, entries):
        pairs = []
        for i in range(0, len(lines) - 1, 2):
            func, loc = lines[i].strip(), DISCR_RE.sub("", lines[i + 1].strip())
            if func == "??" and loc.startswith("??"):
                continue
            pairs.append((func, loc))
        res[o] = pairs or None
    return res


def main():
    ap = argparse.ArgumentParser(prog="san-symbolize.py", description="Symbolize sanitizer reports against unstripped build files.")
    ap.add_argument("input", help="report directory or sanitizer-reports.tar.gz")
    ap.add_argument("-o", "--out", required=True, help="output directory")
    ap.add_argument("--tree", default=os.getcwd(), help="prplOS build tree or the extracted symbols archive (default: the current directory)")
    ap.add_argument("--rootfs", help="stripped rootfs (default build_dir/target-*_glibc/root-x86)")
    ap.add_argument("--addr2line")
    ap.add_argument("--readelf")
    ap.add_argument("--runtime", action="store_true", help="also symbolize libasan/libubsan/ld-linux")
    ap.add_argument("--strict", action="store_true", help="exit 3 if a module has a mismatch or is not found")
    ap.add_argument("-q", action="store_true", help="no summary on stdout")
    a = ap.parse_args()

    a2l = find_tool(a.tree, "addr2line", a.addr2line)
    rde = find_tool(a.tree, "readelf", a.readelf)
    reports = read_input(a.input)
    if not reports:
        die("no report.* files in %s" % a.input)
    res = Resolver(a.tree, a.rootfs, Elf(rde), a.runtime)

    # pass 1: which (module, offset) pairs are needed
    need = collections.defaultdict(set)          # module -> {off}
    frames_of = collections.Counter()            # module -> frame count
    for _, txt in reports:
        for line in txt.split("\n"):
            m = FRAME_RE.match(line)
            if m and " in " not in m.group("tail"):
                off = int(m.group("off"), 16)
                if int(m.group("n")) > 0 and off > 0:
                    off -= 1
                need[m.group("mod")].add(off)
                frames_of[m.group("mod")] += 1

    # resolve modules, run addr2line once per module
    answers = {}                                 # module -> {off: pairs}
    status = {}                                  # module -> (status, path, detail)
    resolved_frames = collections.Counter()
    for mod in sorted(need):
        st, path, detail = res.resolve(mod)
        if st == "ok":
            try:
                answers[mod] = run_addr2line(a2l, path, sorted(need[mod]))
            except RuntimeError as e:
                st, detail = "error", str(e)
        status[mod] = (st, path, detail)

    # pass 2: rewrite
    os.makedirs(a.out, exist_ok=True)
    nrep = 0
    for rel, txt in reports:
        outl = []
        for line in txt.split("\n"):
            m = FRAME_RE.match(line)
            if m and " in " not in m.group("tail") and m.group("mod") in answers:
                off = int(m.group("off"), 16)
                if int(m.group("n")) > 0 and off > 0:
                    off -= 1
                pairs = answers[m.group("mod")].get(off)
                if pairs:
                    resolved_frames[m.group("mod")] += 1
                    line = line + " in %s %s" % pairs[0] + "".join(" <- %s %s" % p for p in pairs[1:])
            outl.append(line)
        dst = os.path.join(a.out, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(dst, "wb") as fh:
            fh.write("\n".join(outl).encode("utf-8", errors="surrogateescape"))
        nrep += 1

    # summary
    cat = collections.Counter(s[0] for s in status.values())
    tot_fr = sum(frames_of.values())
    ok_fr = sum(frames_of[m] for m, s in status.items() if s[0] == "ok")
    lines = []
    lines.append("# Symbolization summary")
    lines.append("")
    lines.append("input: %s  reports: %d  frames: %d  tree: %s" % (a.input, nrep, tot_fr, a.tree))
    lines.append("tools: %s, %s" % (a2l, rde))
    lines.append("modules: %d ok, %d build-id mismatch, %d not found, %d runtime (skipped), %d unknown, %d error"
                 % (cat["ok"], cat["mismatch"], cat["not-found"], cat["runtime"], cat["unknown"], cat["error"]))
    lines.append("frames in ok modules: %d of %d; resolved to a function: %d" % (ok_fr, tot_fr, sum(resolved_frames.values())))
    by_id = sum(1 for s in status.values() if s[0] == "ok" and s[2].startswith("build-id"))
    lines.append("identity proof of the ok modules: %d by GNU build-id, %d by allocated-section hash (no build-id in the build)"
                 % (by_id, cat["ok"] - by_id))
    lines.append("")
    lines.append("| status | module | frames | resolved | unstripped file or reason |")
    lines.append("|---|---|---|---|---|")
    order = {"mismatch": 0, "not-found": 1, "error": 2, "ok": 3, "runtime": 4, "unknown": 5}
    tsv = ["status\tmodule\tframes\tresolved\tunstripped\tdetail"]
    for mod in sorted(status, key=lambda m: (order.get(status[m][0], 9), -frames_of[m], m)):
        st, path, detail = status[mod]
        shown = os.path.relpath(path, a.tree) if path.startswith(a.tree) else path
        lines.append("| %s | %s | %d | %d | %s |" % (st, mod, frames_of[mod], resolved_frames[mod], shown or detail))
        tsv.append("%s\t%s\t%d\t%d\t%s\t%s" % (st, mod, frames_of[mod], resolved_frames[mod], path, detail))
    with open(os.path.join(a.out, "symbolize-summary.md"), "w") as fh:
        fh.write("\n".join(lines) + "\n")
    with open(os.path.join(a.out, "symbolize-summary.tsv"), "w") as fh:
        fh.write("\n".join(tsv) + "\n")
    if not a.q:
        sys.stdout.write("\n".join(lines[2:7]) + "\n")
        for st in ("mismatch", "not-found", "error"):
            for mod in sorted(status):
                if status[mod][0] == st:
                    sys.stdout.write("  %s: %s (%s)\n" % (st, mod, status[mod][2]))
    if a.strict and (cat["mismatch"] or cat["not-found"] or cat["error"]):
        sys.exit(3)


if __name__ == "__main__":
    main()
