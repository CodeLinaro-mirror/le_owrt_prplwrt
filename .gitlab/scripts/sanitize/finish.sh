#!/usr/bin/env bash
# finish.sh: judge the artifacts of a sanitize run. The cram job runs it after the
# loop; it also works on a downloaded artifacts directory.
#
#   1. serial-check.py all: metrics (SANRSS series) and SANDEATH matching from serial.log;
#   2. san-rss-trend.py (/proc trend) and san-calibrate.py (quarantine suggestions, drift report);
#   3. san-symbolize.py on the report tarball of every iteration, against the exported symbols;
#   4. san-report.py: one row per unique finding;
#   5. san-summary.py: san-summary.md, san-junit.xml, cram-merged.xml.
# Exit status: 88 (metrics failed), 89 (an unmatched SANDEATH), another non-zero status of serial-check.py (it did
# not run: a crash or a usage error), 1 (the summary has a failure: a sanitizer report exists, or a harness
# check failed, or a symbolization failed), else 0. The status of serial-check.py wins over 1.
#
# Usage: finish.sh ARTIFACTS [--symbols ARCHIVE_OR_DIR] [--tree DIR]
#   --symbols  sanitize-symbols.tar.xz of the build job, or a directory with build_dir/ (default:
#              sanitize-symbols.tar.xz in the current directory)
#   --tree     the checkout, for the drift report of the committed .opts files and the shim-regress.log of the
#              build job in sanitize-build/ (default: the current directory)
set -uo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
art=''
symbols=sanitize-symbols.tar.xz
tree=$PWD
while (($#)); do
    case $1 in
        --symbols) symbols=$2; shift 2 ;;
        --tree) tree=$2; shift 2 ;;
        -*) echo "finish: unknown option $1" >&2; exit 2 ;;
        *) art=$1; shift ;;
    esac
done
[[ -d $art ]] || { echo "usage: finish.sh ARTIFACTS [--symbols ARCHIVE_OR_DIR] [--tree DIR]" >&2; exit 2; }
art=$(cd -- "$art" && pwd -P)
py() { python3 -I "$here/$1" "${@:2}"; }

echo "== serial log: metrics and SANDEATH"
py serial-check.py all --artifacts "$art"
rc_serial=$?

echo "== memory trend and calibration"
py san-rss-trend.py "$art/serial.log" -o "$art" || echo "finish: san-rss-trend failed" >&2
py san-calibrate.py "$art/serial.log" -o "$art/calibration" --force || echo "finish: san-calibrate failed" >&2
opts=$tree/package/utils/sanitizer-opts/files/opts
# OpenWrt adds -<libc> to the target directory in bin/ for every libc except musl (bin/targets/x86/64-glibc).
# Without a .config (the cram job, downloaded artifacts) it is glibc, the libc of the sanitize profile.
libc=$(sed -n 's/^CONFIG_LIBC="\(.*\)"$/\1/p' "$tree/.config" 2>/dev/null)
bindir=$tree/bin/targets/x86/64
[[ ${libc:-glibc} == musl ]] || bindir+=-${libc:-glibc}
shopt -s nullglob
manifests=("$bindir"/*.manifest)
shopt -u nullglob
if [[ -d $opts && ${#manifests[@]} -gt 0 && -d $art/calibration ]]; then
    py san-calibrate.py drift "$opts" --manifest "${manifests[0]}" --calibration "$art/calibration" >"$art/calibration/drift.txt" 2>&1 || true
fi

echo "== symbolization"
# apt_install PKG...: install packages the image of the job lacks (the testbed-qemu container has neither xz nor
# binutils); the output goes away, a failed install shows up where the caller runs the tool.
apt_install() {
    local sudo=''
    [[ $(id -u) -eq 0 ]] || sudo=sudo
    # shellcheck disable=SC2086
    { $sudo apt-get update && $sudo apt-get install --yes --no-install-recommends "$@"; } >/dev/null 2>&1
}
symtree=''
tmp=''
if [[ -d $symbols ]]; then
    symtree=$symbols
elif [[ -f $symbols ]]; then
    if ! command -v xz >/dev/null; then
        echo "finish: xz not found, installing xz-utils with apt-get" >&2
        apt_install xz-utils || echo "finish: xz-utils not available" >&2
    fi
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/sanitize-symbols.XXXXXX") || exit 2
    if tar -C "$tmp" -xJf "$symbols"; then symtree=$tmp; else echo "finish: cannot unpack $symbols" >&2; fi
else
    echo "finish: no symbols archive at $symbols" >&2
fi
# addr2line and readelf: the toolchain ones of the symbols archive (export-symbols.py), else the host ones. A
# missing tool is a failure of the symbolization, never silent.
sym_failed=0
tool_args=()
mapfile -t packed_a2l < <(compgen -G "$symtree/staging_dir/toolchain-*_glibc/bin/x86_64-openwrt-linux-gnu-addr2line")
mapfile -t packed_rde < <(compgen -G "$symtree/staging_dir/toolchain-*_glibc/bin/x86_64-openwrt-linux-gnu-readelf")
if [[ -n $symtree && -n ${packed_a2l[0]:-} && -n ${packed_rde[0]:-} ]] \
    && "${packed_a2l[0]}" --version >/dev/null 2>&1 && "${packed_rde[0]}" --version >/dev/null 2>&1; then
    echo "finish: addr2line and readelf of the symbols archive"
else
    [[ -n $symtree && -n ${packed_a2l[0]:-} ]] && echo "finish: addr2line and readelf of the symbols archive do not run here, using the host tools" >&2
    tool_args=(--addr2line addr2line --readelf readelf)
    if ! command -v addr2line >/dev/null || ! command -v readelf >/dev/null; then
        echo "finish: addr2line or readelf not found, installing binutils with apt-get" >&2
        apt_install binutils || echo "finish: binutils not available" >&2
        if ! command -v addr2line >/dev/null || ! command -v readelf >/dev/null; then
            echo "finish: no addr2line or readelf: the reports cannot be symbolized" >&2
            sym_failed=1
        fi
    fi
fi
sym=$art/symbolized
mkdir -p "$sym"
inputs=()
symfail=()   # rows of symbolize-summary.tsv for the reports that could not be symbolized
if [[ -z $symtree ]]; then
    symfail+=("$(printf 'error\t%s\t0\t0\t\t%s' "(archive)" "no usable symbols archive: $symbols")")
    sym_failed=1
fi
for d in "$art"/iter-*/ "$art/"; do
    d=${d%/}
    tgz=$d/sanitizer-reports.tar.gz
    [[ -s $tgz ]] || continue
    [[ $d == "$art" && -d $art/iter-01 ]] && continue
    tag=$(basename "$d")
    [[ $d == "$art" ]] && tag=run
    # san-symbolize.py exits 2 on an input without a report file: nothing to symbolize is not a failure
    listing=$(tar -tzf "$tgz" 2>/dev/null)
    if ! grep -Eq '(^|/)report\.' <<<"$listing"; then
        echo "finish: no report file in $tgz, nothing to symbolize" >&2
        inputs+=("$tgz")
        continue
    fi
    if [[ -n $symtree ]] && py san-symbolize.py "$tgz" -o "$sym/$tag" --tree "$symtree" "${tool_args[@]}" >"$sym/$tag.log" 2>&1; then
        inputs+=("$sym/$tag")
    else
        echo "finish: symbolization of $tgz failed, the raw reports are used ($sym/$tag.log)" >&2
        inputs+=("$tgz")
        symfail+=("$(printf 'error\t%s\t0\t0\t\t%s' "$tag" "symbolization of $tgz failed, see $tag.log")")
        sym_failed=1
    fi
done
sumtsv=$sym/symbolize-summary.tsv
# one table over all iterations: the header, a failed run as an error row, the rows of every iteration (a module once)
printf 'status\tmodule\tframes\tresolved\tunstripped\tdetail\n' >"$sumtsv"
if ((${#symfail[@]} > 0)); then printf '%s\n' "${symfail[@]}" >>"$sumtsv"; fi
for f in "$sym"/*/symbolize-summary.tsv; do
    [[ -f $f ]] && tail -n +2 "$f"
done | sort -u >>"$sumtsv"

echo "== findings"
if ((${#inputs[@]} > 0)); then
    py san-report.py "${inputs[@]}" -o "$art" || echo "finish: san-report failed" >&2
else
    echo "finish: no sanitizer-reports.tar.gz in $art: no findings can be judged" >&2
fi

echo "== summary"
args=(--artifacts "$art" --lab-list "$here/lab-network-tests.txt" --exit-code)
[[ -f $art/san-findings.tsv ]] && args+=(--findings "$art/san-findings.tsv")
args+=(--symbolize-summary "$sumtsv")   # a missing file is a failure in the summary: the symbolization did not run
# the shim regression test of the build job (its artifact sanitize-build/): passed, or skipped where bwrap cannot run.
# Without that log (a run judged without the build job's artifacts) the summary has no shim-regress row.
[[ -f $tree/sanitize-build/shim-regress.log ]] && args+=(--shim-regress-log "$tree/sanitize-build/shim-regress.log")
py san-summary.py "${args[@]}"
rc_sum=$?

if [[ -n $tmp ]]; then
    rm -rf -- "${tmp:?}"
fi
if ((rc_serial != 0)); then exit "$rc_serial"; fi
exit $((rc_sum != 0 || sym_failed))
