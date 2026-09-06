#!/usr/bin/env bash
set -Eeuo pipefail
# The Runner helper clones as root; the build runs as builder, as in legacy CI.
git config --global --add safe.directory '*'
die() { echo "persistent: $*" >&2; exit 1; }
scripts="${CI_PROJECT_DIR:?}/.gitlab/scripts"
if [[ ${1:-} != --inside ]]; then
    [[ $CI_PROJECT_DIR == /* && $CI_PROJECT_DIR != / && -e "$CI_PROJECT_DIR/.git" && $CI_PROJECT_DIR != /build/prplos ]] || die "Disposable project checkout is invalid"
    rm -rf "${CI_PROJECT_DIR:?}/bin" "$CI_PROJECT_DIR/logs" "$CI_PROJECT_DIR/rootfs-debug.tar.xz"
    rm -f "$CI_PROJECT_DIR/"*packages-hash-issues.patch
    exec bash "$scripts/with-tree" bash "$0" --inside
fi
[[ $(pwd -P) == /build/prplos && ${CI_COMMIT_SHA:?} =~ ^[a-f0-9]{40,64}$ ]] || die "Expected fixed build path and a hexadecimal commit SHA"
# shellcheck source=/dev/null
source "$scripts/helpers.sh"
read -r -a profiles <<< "${CI_BUILD_PROFILE:?}"
family=$(printf '%s\n' "${profiles[0]}" "${PRPLOS_BUILDER_IMAGE_DIGEST:?}" policy-v1 | sha256sum)
[[ ${profiles[0]} =~ ^[A-Za-z0-9_-]+$ ]] || die "Invalid cache family"
cache_family=${profiles[0]}
case "$cache_family" in qca_ipq95xx|mxl_x86_osp_tb341_v2|x86_64) ;; *) cache_family=other ;; esac
export BUILD_CCACHE=${BUILD_CCACHE:-1}
[[ $BUILD_CCACHE =~ ^[01]$ ]] || die "BUILD_CCACHE must be 0 or 1"
export CCACHE_DIR="/ccache/$cache_family" CCACHE_NAMESPACE="${family%% *}"
export CCACHE_DISABLE=${CLEAN_NO_CCACHE:-0} BUILD_PHASE=setup
if [[ $BUILD_CCACHE == 1 ]]; then mkdir -p "$CCACHE_DIR"; fi
export CCACHE_COMPILERCHECK=content CCACHE_MAXSIZE=15G CCACHE_COMPRESS=1
export BUILD_MAKE_JOBS CI_BUILD_ENABLE_COREDUMPS=1 CI_BUILD_ENABLE_EXCEPTION_TRACE=1
BUILD_MAKE_JOBS=${BUILD_JOBS:?}
[[ $BUILD_MAKE_JOBS =~ ^[1-9][0-9]*$ ]] || die "BUILD_JOBS must be positive"
cache_stats() {
    [[ $BUILD_CCACHE == 1 ]] || return 0
    local cache; cache=$(command -v ccache || :)
    [[ -n $cache ]] || cache=staging_dir/host/bin/ccache
    [[ ! -x $cache ]] || "$cache" "$@" || :
}
export CCACHE_STATSLOG="$PWD/logs/ccache.log"
# ccache treats any set CCACHE_DISABLE value as disabled.
if [[ $CCACHE_DISABLE == 0 ]]; then unset CCACHE_DISABLE; fi
prepare_logs() {
    rm -rf logs; mkdir logs
    printf 'tree-attach %s\n' "${BUILD_ATTACH_SECONDS:-0}" > logs/build-timers.txt
}
prepare_logs
printf '{}\n' > .incomplete
finish() {
    status=$?; trap - EXIT ERR; set +e
    cache_stats --print-stats > logs/ccache-after.txt
    cache_stats --print-log-stats > logs/ccache-job.txt 2>/dev/null || : > logs/ccache-job.txt
    export BUILD_JOB_ELAPSED=$((SECONDS + ${BUILD_ATTACH_SECONDS:-0}))
    python3 "$scripts/persistent-policy.py" evidence "$status"
    evidence_status=$?
    mkdir -p "$CI_PROJECT_DIR/logs"
    cp -a logs/. "$CI_PROJECT_DIR/logs/"; copy_status=$?
    if (( status == 0 )); then
        cp -a bin "$CI_PROJECT_DIR/"; copy_status=$((copy_status + $?))
        if [[ -f rootfs-debug.tar.xz ]]; then cp rootfs-debug.tar.xz "$CI_PROJECT_DIR/"; copy_status=$((copy_status + $?)); fi
    fi
    if (( status == 0 && evidence_status == 0 && copy_status == 0 )); then
        python3 "$scripts/persistent-policy.py" commit-success; evidence_status=$?
    fi
    if (( evidence_status != 0 || copy_status != 0 )); then
        printf '{}\n' > .incomplete
        (( status != 0 )) || status=1
    fi
    if (( status == 0 )); then rm -f .build_failed "$CI_PROJECT_DIR/.build_failed"; else touch .build_failed "$CI_PROJECT_DIR/.build_failed"; fi
    exit "$status"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
timed() {
    # Used by the subshell EXIT trap.
    # shellcheck disable=SC2034
    local name=$1 start=$SECONDS; shift
    ( trap - ERR
      trap 'rc=$?; printf "%s %s\n" "$name" "$((SECONDS-start))" >> logs/build-timers.txt; section_end "$name"; exit "$rc"' EXIT
      section_start "$name"; "$@"
    ) 2>&1 | tee --append logs/build.log
}
fresh() {
    export BUILD_CLEAN=1 BUILD_TREE_REUSED=0 BUILD_CLEAN_REASON=$1
    if [[ -f logs/incremental-plan.json ]]; then
        mkdir -p "$CI_PROJECT_DIR/logs"
        cp logs/incremental-plan.json "$CI_PROJECT_DIR/logs/incremental-escalation.json"
    fi
    python3 - <<'PY'
from pathlib import Path
import shutil
for p in Path('.').iterdir():
    if p.is_symlink() or not p.is_dir(): p.unlink()
    else: shutil.rmtree(p)
PY
    prepare_logs
    printf '{}\n' > .incomplete
}
root_sync() {
    [[ -d .git ]] || git init -q
    local shallow
    if ! shallow=$(git -C "$CI_PROJECT_DIR" rev-parse --is-shallow-repository 2>&1); then
        die "Cannot inspect Runner checkout: $shallow"
    fi
    [[ $shallow == false ]] || die "Runner checkout must have full history (GIT_DEPTH=0)"
    local -a depth=()
    [[ $(git rev-parse --is-shallow-repository) == false ]] || depth=(--unshallow)
    printf '/.persistent-*\n/.incomplete\n/.build_failed\n/rootfs-debug.tar.xz\n' > .git/info/exclude
    git fetch "${depth[@]}" --force --prune --prune-tags "$CI_PROJECT_DIR" "$CI_COMMIT_SHA" '+refs/tags/*:refs/tags/*'
    git checkout --detach --force "$CI_COMMIT_SHA"
    [[ $(git rev-parse HEAD) == "$CI_COMMIT_SHA" ]] || die "Fetched checkout does not match CI_COMMIT_SHA"
}
setup() {
    touch .build_failed
    [[ ! -e version && ! -e version.date ]] || die "Unexpected version or version.date override"
    sudo apt-get update
    sudo apt-get install --yes --no-install-recommends swig coccinelle libbsd-dev libssl-dev libpython3-dev lzop
    if LC_ALL=C grep -rIl $'\r' profiles | grep -q .; then echo 'CRLF in profiles' >&2; return 1; fi
    for hook in .gitlab/scripts/build.d/*; do [[ ! -f $hook ]] || bash "$hook"; done
}
incremental_generator() {
    [[ ${BUILD_INCREMENTAL_GENERATOR:-1} == 1 ]] && grep -q -- --incremental scripts/gen_config.py
}
[[ ${BUILD_INCREMENTAL_GENERATOR:-1} =~ ^[01]$ ]] || die "BUILD_INCREMENTAL_GENERATOR must be 0 or 1"
# Phase 1 keeps toolchain/tools/kernel/target and in-tree package objects.
# Legacy setup reclones feeds: feed packages rebuild as their recipe mtimes change.
generate() {
    local status=0
    sed -i -E 's;git.openwrt.org/(feed|project);github.com/openwrt;' feeds.conf.default || return $?
    if incremental_generator; then
        export GENCONFIG_BASE_REV
        GENCONFIG_BASE_REV=$(python3 "$scripts/persistent-policy.py" baseline) || { git checkout -- feeds.conf.default; return 1; }
        scripts/gen_config.py --incremental "${profiles[@]}" || status=$?
    else
        scripts/gen_config.py "${profiles[@]}" || status=$?
    fi
    git checkout -- feeds.conf.default || return $?
    return "$status"
}
configure() {
    local option
    set -f
    # Intentional whitespace splitting matches the legacy multiline configuration.
    # shellcheck disable=SC2086
    for option in ${CI_BUILD_CONFIG:-} ${CI_BUILD_CONFIG_EXTRA:-}; do printf '%s\n' "$option" | sed -E 's/^\+(.*)$/CONFIG_\1=y/;s/^-(.*)$/CONFIG_\1=n/' >> .config; done
    # Remove earlier settings so the persistent controls cannot be ambiguous.
    sed -i '/^CONFIG_\(AUTOREMOVE\|AUTOREBUILD\|CCACHE\|CCACHE_DIR\|DOWNLOAD_FOLDER\)=/d' .config
    printf 'CONFIG_AUTOREMOVE=n\nCONFIG_AUTOREBUILD=y\nCONFIG_CCACHE=%s\n' \
        "$([[ $BUILD_CCACHE == 0 || ${CLEAN_NO_CCACHE:-0} == 1 ]] && echo n || echo y)" >> .config
    if [[ $BUILD_CCACHE == 1 ]]; then printf 'CONFIG_CCACHE_DIR="%s"\n' "$CCACHE_DIR" >> .config; fi
    printf 'CONFIG_DOWNLOAD_FOLDER="%s"\n' "$BUILD_DL_DIR" >> .config
    make defconfig
}
if [[ $BUILD_CCACHE == 0 ]]; then
    export CI_BUILD_CONFIG_EXTRA="${CI_BUILD_CONFIG_EXTRA:-} -CCACHE"
else
    export CI_BUILD_CONFIG_EXTRA="${CI_BUILD_CONFIG_EXTRA:-} +CCACHE CONFIG_CCACHE_DIR=\"$CCACHE_DIR\""
fi
if [[ ! -d .git ]]; then export BUILD_CLEAN=1 BUILD_CLEAN_REASON=${BUILD_CLEAN_REASON:-first-build}; fi
if [[ -f .genconfig-state/incremental-plan.failed ]] && incremental_generator; then fresh incomplete-generator; fi
if [[ -d .git && -z $(python3 "$scripts/persistent-policy.py" baseline) ]]; then fresh missing-success; fi
export BUILD_PARENT_SHA
BUILD_PARENT_SHA=$(python3 "$scripts/persistent-policy.py" baseline)
cleans=()
for attempt in 1 2; do
    timed root-sync root_sync
    timed build-setup setup
    if ! timed gen-config generate; then
        (( attempt == 1 )) && [[ $BUILD_CLEAN != 1 ]] || die "Configuration generation failed"
        fresh generator-failed; continue
    fi
    timed defconfig configure
    if [[ $BUILD_CLEAN == 1 ]] || ! incremental_generator; then break; fi
    python3 "$scripts/persistent-policy.py" plan > logs/clean-plan.txt
    mapfile -t cleans < logs/clean-plan.txt
    if [[ ${cleans[0]:-fresh} == fresh ]]; then fresh invalidation; continue; fi
    break
done
[[ -f .config ]] || die "Configuration was not generated"
cache_before() { cache_stats --print-stats > logs/ccache-before.txt; }
timed ccache-before cache_before
clean_targets() {
    for target in "${cleans[@]:1}"; do [[ -z $target ]] || make "$target/clean"; done
}
timed targeted-cleans clean_targets
integrity() {
    local bad=0 feed name patch
    patch="$CI_PROJECT_DIR/packages-hash-issues.patch"
    if ! git diff-index --quiet HEAD --; then
        git diff HEAD -- | tee "$patch"; bad=1
    fi
    while IFS= read -r -d '' feed; do
        name=${feed%/.git}; name=${name##*/}
        if ! git -C "${feed%/.git}" diff-index --quiet HEAD --; then
            echo "Feed $name packages integrity issues" >&2
            git -C "${feed%/.git}" diff HEAD -- | tee "$CI_PROJECT_DIR/$name-packages-hash-issues.patch"
            bad=1
        fi
    done < <(find feeds -name .git -print0)
    (( bad == 0 )) || die "Recipe integrity failed; inspect hash-issues patch artifacts"
}

diagnostics() {
    local rc=$?; trap - ERR; set +e
    if [[ $BUILD_PHASE == world ]]; then
        make package/install V=s 2>&1 | tee --append logs/build.log
        make target/install -j "$BUILD_MAKE_JOBS" V=s 2>&1 | tee --append logs/build.log
    fi
    ( integrity ) 2>&1 | tee --append logs/build.log
    exit "$rc"
}
trap diagnostics ERR
timed tools-tar-compile make -j "$BUILD_MAKE_JOBS" tools/tar/compile
# The label skips checksum checking, matching the legacy escape hatch.
# FIXUP stays off: never publish automatic recipe hash repairs as accepted inputs.
download_targets=(download)
if [[ ${CI_MERGE_REQUEST_LABELS:-} != *skip_integrity_check* ]]; then download_targets+=(check); fi
timed download make -j "$BUILD_MAKE_JOBS" "${download_targets[@]}"
timed integrity-check integrity
export BUILD_PHASE=world
timed compile-world make -j "$BUILD_MAKE_JOBS"
export BUILD_PHASE=publish
if [[ -n ${CI_BUILD_EXPORT_STAGING_ROOTFS:-} ]]; then
    mapfile -t roots < <(find "$PWD/staging_dir" -maxdepth 2 -type d -name 'root-*')
    [[ ${#roots[@]} == 1 ]] || die "Expected exactly one staging rootfs"
    timed export-rootfs tar cfJ rootfs-debug.tar.xz -C "${roots[0]}" .
fi
