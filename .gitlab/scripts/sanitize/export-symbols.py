#!/usr/bin/env python3
"""export-symbols.py: pack what san-symbolize.py needs to symbolize sanitizer reports after the run.

The sanitize image is stripped and its reports hold module+offset only. The reports are symbolized after
the run, against the unstripped build files. A full copy of those files is about 2.4 GB (the sanitizer
instrumentation makes the code huge), the debug data in them is a small part of that. The archive therefore
keeps only the debug data, in the layout of the build tree, so san-symbolize.py --tree <extracted dir>
works on it unchanged:

  build_dir/target-*_glibc/<pkg>/.pkgdir/<pkg>/<path>   the unstripped ELF reduced to .symtab and .debug_*
                                                       (objcopy --only-keep-debug, sections zlib-compressed)
  build_dir/target-*_glibc/root-x86/<path>              the rootfs, as the image has it: every ELF is reduced
                                                       to its GNU build-id note (about 1 KB), symlinks are
                                                       kept, other files are left out. Identity check of
                                                       san-symbolize.py: build-id of the rootfs file equals
                                                       build-id of the debug file (-Wl,--build-id is in the
                                                       sanitize profile).
  staging_dir/toolchain-*_glibc/bin/x86_64-openwrt-linux-gnu-{addr2line,readelf}
                                                       the toolchain tools that san-symbolize.py uses, so the
                                                       job that symbolizes needs no binutils
  sanitize-symbols.tsv                                  one row per file: kind, path, bytes

An executable or shared object without a build-id (the toolchain libraries, for example) is proved by
san-symbolize.py through the content of its allocated sections. The archive keeps both files of such a pair
whole (the rootfs file as it is, the debug file with compressed debug sections only), as --only-keep-debug
would turn the allocated sections into NOBITS and the hash would not match. Kernel modules are not kept whole.

Usage: export-symbols.py [--tree DIR] [--out FILE] [-j N]
  --tree  the prplOS build tree (default: the current directory)
  --out   the archive (default: sanitize-symbols.tar.xz in --tree)
Uses the toolchain objcopy of the tree (staging_dir/toolchain-*_glibc/bin), else the one in PATH.
"""
import argparse
import concurrent.futures as cf
import glob
import os
import shutil
import struct
import subprocess
import sys
import tempfile


TOOLS = ("addr2line", "readelf")


def die(msg):
    sys.exit("export-symbols: " + msg)


def is_elf(path):
    try:
        with open(path, "rb") as fh:
            return fh.read(4) == b"\x7fELF"
    except OSError:
        return False


def section_names(path):
    """Section names of an ELF64 little endian file, or None."""
    try:
        with open(path, "rb") as fh:
            hdr = fh.read(0x40)
            if hdr[:6] != b"\x7fELF\x02\x01" or len(hdr) < 0x40:
                return None
            shoff, = struct.unpack_from("<Q", hdr, 0x28)
            shentsize, shnum, shstrndx = struct.unpack_from("<HHH", hdr, 0x3A)
            if not shoff or not shnum:
                return set()
            fh.seek(shoff)
            raw = fh.read(shentsize * shnum)
            secs = [struct.unpack_from("<IIQQQQ", raw, i * shentsize) for i in range(shnum)]
            _, _, _, _, stroff, strsize = secs[shstrndx]
            fh.seek(stroff)
            strtab = fh.read(strsize)
        names = set()
        for name, *_ in secs:
            end = strtab.index(b"\0", name)
            names.add(strtab[name:end].decode("ascii", "replace"))
        return names
    except (OSError, struct.error, ValueError, IndexError):
        return None


def lacks_build_id(path):
    """True for an ET_EXEC or ET_DYN ELF64 file with no GNU build-id note: san-symbolize.py then needs the
    allocated sections of the file itself."""
    names = section_names(path)
    if names is None or ".note.gnu.build-id" in names:
        return False
    try:
        with open(path, "rb") as fh:
            fh.seek(0x10)
            etype, = struct.unpack("<H", fh.read(2))
    except (OSError, struct.error):
        return False
    return etype in (2, 3)


def pack_tools(tree, work):
    """Copy the toolchain addr2line and readelf into the archive, in the layout of the build tree, where
    san-symbolize.py --tree finds them: the job that symbolizes needs no binutils then. Returns a list of
    (path in the archive, bytes); empty when the tree has no such pair (the host tools are then used)."""
    for bindir in sorted(glob.glob(os.path.join(tree, "staging_dir", "toolchain-*_glibc", "bin"))):
        srcs = [os.path.join(bindir, "x86_64-openwrt-linux-gnu-" + name) for name in TOOLS]
        if not all(os.access(p, os.X_OK) for p in srcs):
            continue
        packed = []
        for p in srcs:
            dst = os.path.join(work, os.path.relpath(p, tree))
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(p, dst)
            packed.append((os.path.relpath(dst, work), os.path.getsize(dst)))
        return packed
    return []


def main():
    ap = argparse.ArgumentParser(prog="export-symbols.py", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--tree", default=os.getcwd())
    ap.add_argument("--out")
    ap.add_argument("-j", type=int, default=min(16, os.cpu_count() or 4))
    a = ap.parse_args()
    tree = os.path.realpath(a.tree)
    out = os.path.realpath(a.out or os.path.join(tree, "sanitize-symbols.tar.xz"))
    bd = sorted(glob.glob(os.path.join(tree, "build_dir", "target-*_glibc")))
    if len(bd) != 1:
        die("expected one build_dir/target-*_glibc in %s, found %d" % (tree, len(bd)))
    t = bd[0]
    rootfs = os.path.join(t, "root-x86")
    if not os.path.isdir(rootfs):
        die("no rootfs: " + rootfs)
    objcopy = None
    for p in sorted(glob.glob(os.path.join(tree, "staging_dir", "toolchain-*_glibc", "bin", "*-linux-gnu-objcopy"))):
        if os.access(p, os.X_OK):
            objcopy = p
            break
    objcopy = objcopy or shutil.which("objcopy")
    if not objcopy:
        die("no objcopy found")

    work = tempfile.mkdtemp(prefix="sanitize-symbols.", dir=os.environ.get("TMPDIR") or None)
    rel_t = os.path.relpath(t, tree)
    rows = []
    jobs = []        # (kind, src, dst)
    stats = {"stub": 0, "debug": 0, "link": 0, "skipped": 0, "tool": 0, "whole": 0}
    try:
        # rootfs: stubs + symlinks
        for dp, dn, fn in os.walk(rootfs):
            for name in dn + fn:
                p = os.path.join(dp, name)
                rel = os.path.relpath(p, rootfs)
                dst = os.path.join(work, rel_t, "root-x86", rel)
                if os.path.islink(p):
                    os.makedirs(os.path.dirname(dst), exist_ok=True)
                    os.symlink(os.readlink(p), dst)
                    stats["link"] += 1
                elif os.path.isfile(p) and is_elf(p):
                    jobs.append(("whole" if lacks_build_id(p) else "stub", p, dst))
        # unstripped files: .pkgdir of every package
        for pat in ("*/.pkgdir/*", "*/*/.pkgdir/*"):
            for pk in sorted(glob.glob(os.path.join(t, pat))):
                for dp, dn, fn in os.walk(pk):
                    for name in fn:
                        p = os.path.join(dp, name)
                        if os.path.islink(p) or not os.path.isfile(p) or not is_elf(p):
                            continue
                        dst = os.path.join(work, os.path.relpath(p, tree))
                        names = section_names(p)
                        if not names or not (names & {".symtab", ".debug_info"}):
                            stats["skipped"] += 1
                            continue
                        jobs.append(("debug-whole" if lacks_build_id(p) else "debug", p, dst))

        def run(job):
            kind, src, dst = job
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            if kind == "stub":
                cmd = [objcopy, "--only-section=.note.gnu.build-id", src, dst]
            elif kind == "whole":
                cmd = [objcopy, src, dst]
            elif kind == "debug-whole":
                cmd = [objcopy, "--compress-debug-sections=zlib", src, dst]
            else:
                cmd = [objcopy, "--only-keep-debug", "--compress-debug-sections=zlib", src, dst]
            r = subprocess.run(cmd, capture_output=True, text=True)
            if r.returncode != 0:
                return (kind, src, dst, "objcopy failed: " + (r.stderr.strip().splitlines() or ["?"])[-1])
            return (kind, src, dst, None)

        errors = []
        with cf.ThreadPoolExecutor(a.j) as ex:
            for kind, src, dst, err in ex.map(run, jobs):
                if err:
                    errors.append("%s: %s" % (src, err))
                    continue
                stats["debug" if kind.startswith("debug") else "stub"] += 1   # "whole" kinds count as their pair kind too
                stats["whole"] += kind.endswith("whole")
                rows.append((kind, os.path.relpath(dst, work), os.path.getsize(dst)))
        if errors:
            sys.stderr.write("export-symbols: %d file(s) failed:\n  %s\n" % (len(errors), "\n  ".join(errors[:20])))
            sys.exit(1)
        for rel, size in pack_tools(tree, work):
            stats["tool"] += 1
            rows.append(("tool", rel, size))
        if not stats["tool"]:
            sys.stderr.write("export-symbols: warning: no toolchain addr2line and readelf in staging_dir, the symbolization needs the host ones\n")
        with open(os.path.join(work, "sanitize-symbols.tsv"), "w") as fh:
            for r in sorted(rows):
                fh.write("%s\t%s\t%d\n" % r)
        raw = sum(r[2] for r in rows)
        sys.stderr.write("export-symbols: %d debug files, %d build-id stubs, %d symlinks, %d toolchain tools, %d ELF without symbols skipped; %d ELF without build-id kept whole; %.1f MB before compression\n" % (
            stats["debug"], stats["stub"], stats["link"], stats["tool"], stats["skipped"], stats["whole"], raw / 1e6))
        if not stats["debug"] or not stats["stub"]:
            die("nothing to export (debug files %d, stubs %d)" % (stats["debug"], stats["stub"]))
        tmp = out + ".part"
        with open(tmp, "wb") as fh:
            tar = subprocess.Popen(["tar", "-C", work, "-cf", "-", "."], stdout=subprocess.PIPE)
            xz = subprocess.Popen(["xz", "-T0", "-6"], stdin=tar.stdout, stdout=fh)
            tar.stdout.close()
            if xz.wait() != 0 or tar.wait() != 0:
                die("tar or xz failed")
        os.replace(tmp, out)
        sys.stderr.write("export-symbols: %s %.1f MB\n" % (out, os.path.getsize(out) / 1e6))
        shutil.copy(os.path.join(work, "sanitize-symbols.tsv"), os.path.join(os.path.dirname(out), "sanitize-symbols.tsv"))
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main()
