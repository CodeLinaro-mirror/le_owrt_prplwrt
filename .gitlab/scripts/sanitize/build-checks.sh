#!/usr/bin/env bash
# build-checks.sh: the steps of the sanitize build job after "make" has built the image.
#
#   1. the image is there (bin/targets/x86/64/...-combined-efi.img) and its sha256 is recorded;
#   2. instr-scan.sh on the rootfs: fails on an ELF that is neither instrumented, opted out nor allowlisted;
#   3. shim-regress.sh: the shim regression test in bwrap on the rootfs, skipped where bwrap cannot run;
#   4. export-symbols.py: sanitize-symbols.tar.xz for the symbolization after the run.
# All steps run, the exit status is the first failure, so the artifacts of the later steps exist. The outputs
# are in sanitize-build/ (instr-scan.tsv, shim-regress.log, image.sha256) and sanitize-symbols.tar.xz.
#
# Usage: build-checks.sh [TREE]   (default: the current directory, the root of the build tree)
set -uo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
tree=$(cd -- "${1:-.}" && pwd -P) || exit 2
cd "$tree" || exit 2
out=sanitize-build
mkdir -p "$out"
rc=0

shopt -s nullglob
roots=("$tree"/build_dir/target-*_glibc/root-x86)
shopt -u nullglob
if ((${#roots[@]} != 1)); then
    echo "build-checks: expected one build_dir/target-*_glibc/root-x86, found ${#roots[@]}" >&2
    exit 2
fi
rootfs=${roots[0]}

img=bin/targets/x86/64/prplos-x86-64-generic-squashfs-combined-efi.img
echo "== image"
if [[ -f $img ]]; then
    sha256sum "$img" | tee "$out/image.sha256"
else
    echo "build-checks: image not found: $img" >&2
    rc=1
fi

echo "== instr-scan (instrumented = undefined __asan_report_* in the dynamic symbols)"
"$here/instr-scan.sh" "$rootfs" --tree "$tree" --out "$out/instr-scan.tsv" || { s=$?; echo "build-checks: instr-scan failed ($s)" >&2; ((rc)) || rc=$s; }

echo "== shim regression test"
if "$here/shim-regress.sh" --preflight >"$out/shim-regress.log" 2>&1 || [[ $? -ne 77 ]]; then
    "$here/shim-regress.sh" --prplos "$tree" 2>&1 | tee "$out/shim-regress.log"
    s=${PIPESTATUS[0]}
    if ((s)); then echo "build-checks: shim-regress failed ($s)" >&2; ((rc)) || rc=$s; fi
else
    cat "$out/shim-regress.log"   # the SKIPPED line: bwrap cannot run here
fi

echo "== symbols for the symbolization after the run"
python3 -I "$here/export-symbols.py" --tree "$tree" --out "$tree/sanitize-symbols.tar.xz" || { s=$?; echo "build-checks: export-symbols failed ($s)" >&2; ((rc)) || rc=$s; }

exit "$rc"
