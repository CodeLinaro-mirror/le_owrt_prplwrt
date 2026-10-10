#!/usr/bin/env bash
# instr-scan.sh: post-build check that every ELF (except *.ko) in a target rootfs
# is ASan-instrumented, or explained by an opt-out or an allowlist entry. It compensates
# verify_asan_link_order=0, which masks the "ASan runtime does not come first" error.
# Usage: instr-scan.sh ROOTFS_DIR [--allowlist FILE] [--tree DIR] [--feed-clone DIR]
#                      [--out FILE] [-j N] [-q]
#   --tree        the prplOS build tree (default: the current directory), for .config, include/package.mk
#                 and the package Makefiles of the opt-outs
#   --feed-clone  optional extra directory searched for feed_prplos package Makefiles
# Output: TSV (status, class, path, binary pkg, source pkg, reason) on stdout or --out.
# Summary and the unexpected list (grouped by source package) go to stderr.
# Exit: 0 all explained, 1 unexpected non-instr ELF present, 2 usage/setup error or no
# instrumented ELF at all (empty or wrong rootfs).
# Classes: instr (undefined __asan_report_* only; instr-noaccess: no
# __asan_report_*, but __asan_version_mismatch_check_v8 and __asan_init or
# __asan_register_globals: compiled with ASan, no checked access, OK and listed
# in .dynsym), link-only (DT_NEEDED libasan, no such symbols), plain (neither).
set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
exec python3 -I - "$here" "$@" <<'PY'
import argparse, collections, concurrent.futures as cf, fnmatch, os, re, subprocess, sys

here = sys.argv[1]
ap = argparse.ArgumentParser(prog="instr-scan.sh")
ap.add_argument("rootfs")
ap.add_argument("--allowlist", default=os.path.join(here, "instr-allowlist.tsv"))
ap.add_argument("--tree", default=os.getcwd())
ap.add_argument("--feed-clone", default=None)
ap.add_argument("--out")
ap.add_argument("-j", type=int, default=min(32, os.cpu_count() or 4))
ap.add_argument("-q", action="store_true", help="no unexpected list on stderr")
a = ap.parse_args(sys.argv[2:])
def die(msg):
    sys.stderr.write("instr-scan: %s\n" % msg)
    sys.exit(2)
root = os.path.realpath(a.rootfs)
info = os.path.join(root, "usr/lib/opkg/info")
for p, what in ((root, "rootfs"), (info, "opkg info dir"), (a.allowlist, "allowlist"),
                (os.path.join(a.tree, "include/package.mk"), "package.mk")):
    if not os.path.exists(p):
        die("%s not found: %s" % (what, p))

# ---- path resolution inside the rootfs (symlinked dirs, absolute links) ----
_dircache = {}
def canon_dir(d, depth=0):
    """Resolve directory d (absolute, rootfs-relative) without leaving the rootfs."""
    if d in _dircache: return _dircache[d]
    cur = "/"
    parts = [x for x in d.split("/") if x]
    i = 0
    hops = 0
    while i < len(parts):
        nxt = os.path.join(cur, parts[i])
        host = root + nxt
        if os.path.islink(host) and hops < 40:
            hops += 1
            t = os.readlink(host)
            t = t if t.startswith("/") else os.path.join(cur, t)
            parts = [x for x in os.path.normpath(t).split("/") if x] + parts[i+1:]
            cur, i = "/", 0
            continue
        cur, i = nxt, i + 1
    _dircache[d] = cur
    return cur
def canon(p):
    d, b = os.path.split(os.path.normpath(p))
    return os.path.join(canon_dir(d), b)

# ---- opkg metadata: file -> binary pkg, pkg -> (SourceName, Source path) ----
owner = collections.defaultdict(set)
for f in os.listdir(info):
    if f.endswith(".list"):
        pkg = f[:-5]
        with open(os.path.join(info, f), errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if line.startswith("/"): owner[canon(line)].add(pkg)
srcinfo = {}   # pkg -> (SourceName, Source)
for f in os.listdir(info):
    if f.endswith(".control"):
        d = {}
        with open(os.path.join(info, f), errors="replace") as fh:
            for line in fh:
                k, _, v = line.partition(":")
                if k in ("Package", "Source", "SourceName"): d[k] = v.strip()
        pkg = d.get("Package", f[:-8])
        src = d.get("Source", "")
        srcinfo[pkg] = (d.get("SourceName") or (os.path.basename(src) if src else ""), src)

# ---- opt-out data from the tree ----
def read_logical(path):
    with open(path, errors="replace") as fh:
        buf = ""
        for line in fh:
            line = line.rstrip("\n")
            if line.endswith("\\"): buf += line[:-1] + " "; continue
            yield buf + line; buf = ""
        if buf: yield buf
_config = None
def config_set(sym):
    """True if the build tree's .config has sym=y (or any non-empty, non-'n' value)."""
    global _config
    if _config is None:
        _config = {}
        try:
            for l in open(os.path.join(a.tree, ".config"), errors="replace"):
                k, sep, v = l.strip().partition("=")
                if sep and k.startswith("CONFIG_"): _config[k] = v
        except OSError:
            pass
    v = _config.get(sym, "")
    return v not in ("", "n", '""')
optout = set()
for line in read_logical(os.path.join(a.tree, "include/package.mk")):
    m = re.match(r"\s*SANITIZE_OPTOUT_PKGS\s*[:+?]?=\s*(.*)", line)
    if m:
        # $(if $(CONFIG_X),A,B), e.g. busybox when CONFIG_SANITIZE_BUSYBOX is off: use the tree's .config
        def _if(mm):
            return mm.group(2) if config_set(mm.group(1)) else mm.group(3)
        val = re.sub(r"\$\(if \$\((CONFIG_\w+)\),([^,)]*),([^)]*)\)", _if, m.group(1).split("#")[0])
        optout.update(val.split())
_mk = {}
def makefile_for(source):
    """Return (path or None, no_sanitize bool)."""
    if source in _mk: return _mk[source]
    cands = []
    if source.startswith("feeds/"):
        feed, _, rest = source[6:].partition("/")
        if feed == "base": cands.append(os.path.join(a.tree, "package", rest))
        cands.append(os.path.join(a.tree, "feeds", feed, rest))
        if feed == "feed_prplos" and a.feed_clone: cands.append(os.path.join(a.feed_clone, rest))
    elif source:
        cands.append(os.path.join(a.tree, source))
    res = (None, False)
    for c in cands:
        mk = os.path.join(c, "Makefile")
        if os.path.isfile(mk):
            ns = False
            for line in read_logical(mk):
                m = re.match(r"\s*PKG_BUILD_FLAGS\s*[:+?]?=\s*(.*)", line)
                if m and "no-sanitize" in m.group(1).split("#")[0].split(): ns = True
            res = (mk, ns); break
    _mk[source] = res
    return res

allow = []
with open(a.allowlist) as fh:
    for n, line in enumerate(fh, 1):
        line = line.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"): continue
        g, _, why = line.partition("\t")
        if not g.strip(): die("bad allowlist line %d" % n)
        allow.append((g.strip(), why.strip() or "allowlisted"))

# ---- find ELFs ----
elfs = []
for dp, dn, fn in os.walk(root):
    dn[:] = [d for d in dn if not os.path.islink(os.path.join(dp, d))]
    for f in fn:
        if f.endswith(".ko"): continue
        p = os.path.join(dp, f)
        if os.path.islink(p) or not os.path.isfile(p): continue
        try:
            with open(p, "rb") as fh:
                if fh.read(4) != b"\x7fELF": continue
        except OSError: continue
        elfs.append(p)

NEED = re.compile(r"\(NEEDED\)\s+Shared library: \[([^\]]*)\]")
def classify(p):
    r = subprocess.run(["readelf", "-W", "-d", "--dyn-syms", p], capture_output=True, text=True, errors="replace")
    if r.returncode != 0 and not r.stdout: return "error"
    asan = False
    und = set()
    for line in r.stdout.splitlines():
        t = line.split()
        if len(t) >= 8 and t[6] == "UND" and t[0].endswith(":"):
            n = t[7].split("@")[0]
            if n.startswith("__asan_report_"):
                asan = True; break
            und.add(n)
    if asan: return "instr"
    # Built with -fsanitize=address but no checked memory access, e.g. a
    # main() that only calls a library: the version check plus
    # __asan_init or __asan_register_globals. OK, listed apart from instr.
    if "__asan_version_mismatch_check_v8" in und and \
            und & {"__asan_init", "__asan_register_globals"}:
        return "instr-noaccess"
    for m in NEED.finditer(r.stdout):
        if m.group(1).startswith("libasan.so"): return "link-only"
    return "plain"
with cf.ThreadPoolExecutor(a.j) as ex:
    classes = list(ex.map(classify, elfs))

# ---- decide ----
rows, unmapped = [], []
cnt = collections.Counter()
for p, cls in sorted(zip(elfs, classes)):
    rel = "/" + os.path.relpath(p, root)
    pkgs = sorted(owner.get(rel, ()))
    srcs = sorted({srcinfo[k][0] for k in pkgs if k in srcinfo and srcinfo[k][0]})
    pkg_s = ",".join(pkgs) or "-"
    src_s = ",".join(srcs) or "-"
    cnt[cls] += 1
    if cls in ("instr", "instr-noaccess"):
        rows.append(("ok", cls, rel, pkg_s, src_s, "")); continue
    why = None
    for k in pkgs:                                     # (a) opt-out
        name, source = srcinfo.get(k, ("", ""))
        if name in optout: why = "optout:%s (SANITIZE_OPTOUT_PKGS)" % name; break
        mk, ns = makefile_for(source)
        if ns: why = "optout:%s (no-sanitize in %s)" % (name, os.path.relpath(mk, a.tree) if mk.startswith(a.tree) else mk); break
    if why: status = "optout"
    else:                                              # (b) allowlist
        status = "UNEXPECTED"
        for g, r in allow:
            if fnmatch.fnmatchcase(rel, g): status, why = "allowed", "allowlist:" + r; break
    if status == "UNEXPECTED":
        if not pkgs: why = "no opkg .list owns this file"; unmapped.append(rel)
        elif not srcs: why = "no Source/SourceName for %s" % pkg_s; unmapped.append(rel)
        else:
            miss = [k for k in pkgs if srcinfo.get(k) and makefile_for(srcinfo[k][1])[0] is None]
            why = "not opted out, not allowlisted" + (" (Makefile not found for %s)" % ",".join(miss) if miss else "")
    cnt["st:" + status] += 1
    rows.append((status, cls, rel, pkg_s, src_s, why))

out = open(a.out, "w") if a.out else sys.stdout
out.write("#status\tclass\tpath\tbinary_pkg\tsource_pkg\treason\n")
for r in rows: out.write("\t".join(r) + "\n")
if a.out: out.close()

unexp = [r for r in rows if r[0] == "UNEXPECTED"]
e = sys.stderr
e.write("instr-scan: ELF=%d instr=%d instr-noaccess=%d link-only=%d plain=%d error=%d | non-instr ok: optout=%d allowlist=%d | UNEXPECTED=%d (link-only=%d plain=%d error=%d, unmapped=%d)\n" % (
    len(elfs), cnt["instr"], cnt["instr-noaccess"], cnt["link-only"], cnt["plain"], cnt["error"], cnt["st:optout"], cnt["st:allowed"],
    len(unexp), sum(r[1] == "link-only" for r in unexp), sum(r[1] == "plain" for r in unexp),
    sum(r[1] == "error" for r in unexp), len(unmapped)))
noacc = [r for r in rows if r[1] == "instr-noaccess"]
if noacc:
    e.write("instr-noaccess (OK): %s\n" % " ".join(r[2] for r in noacc))
if unexp and not a.q:
    g = collections.defaultdict(list)
    for r in unexp: g[r[4]].append(r)
    for s, rs in sorted(g.items(), key=lambda kv: (-len(kv[1]), kv[0])):
        e.write("  %-28s %3d  %s\n" % (s, len(rs), " ".join(sorted({x[2] for x in rs})[:3]) + (" ..." if len(rs) > 3 else "")))
# An empty or wrong rootfs, or a build without the sanitizer flags, must not pass as "all explained".
if not cnt["instr"]:
    die("no ASan-instrumented ELF among %d ELF files in %s: wrong rootfs, or the build did not use the sanitizer flags" % (len(elfs), root))
sys.exit(1 if unexp else 0)
PY
