#!/usr/bin/env bash
# run-loop.sh: the [full] cram selection in a loop on one QEMU run, for the sanitize job.
#
# It is the command of "testbed-qemu run -- ...", so the DUT is up when it starts and QEMU stays up until it
# returns. One iteration is the whole [full] selection of the board, as the [full] job runs it, plus:
#   - sanitize/000-san-sampler.t in front: the RSS sampler. The reboot test of [full] stops the sampler, so
#     every iteration starts a new one; serial-check.py judges each boot on its own.
#   - sanitize/010-san-broadcast.t in front of qemu-x86-64/reboot.t: the leak check signal (SIGRTMIN+3) to every
#     process with the shim, after the whole iteration and before the DUT reboots.
#   - sanitize/020-san-netprobe.t in the first iteration only (a 15 minute logger).
#   - the generic post checks and the sanitizer collector (sanitize/post) after the iteration.
#   - a factory reset between two iterations (see below).
# The selection is resolved by the resolver of the [full] job, so it follows the manifest. New iterations start
# while less than SANITIZE_LOOP_SECONDS of wall time have passed since the first one began (default 10800, 3 h),
# so the run ends when the iteration that is running at that time ends.
#
# Factory reset: /overlay keeps the configuration that the tests of iteration N leave (MQTT clients, a bulkdata
# profile, UPnP and PCP entries, the marker of reboot.t), and the tests of iteration N+1 fail on it. So a new
# iteration starts on a factory-fresh DUT: `firstboot -y`, reboot, SSH, then the datamodel (all on the same
# QEMU run, so the /proc trend continues). /ext is not a mount point: /ext/sanitizer is a directory of the
# squashfs that is written on the f2fs overlay, so the reset wipes the reports and the sampler log. The collector of the
# iteration has copied them out already; right before the reset the driver copies them out once more
# (sanitizer-reports.tar.gz and san-rss.log in iter-NN are replaced when the guest holds more than the
# collected copy; the SANREPORT/SANRSS console lines in serial.log are on the host anyway). The reset is
# checked (a marker file in /etc is gone, a new boot id); a failed reset ends the run (exit 1), because
# the next iteration would only show the inherited state. The reset after the last iteration is skipped.
# The datamodel wait mirrors the knobs of the testbed-qemu MR (they apply to the first boot only):
# TESTBED_QEMU_DATAMODEL_WAIT_FOR (default Device.WiFi.; empty: only a stable line count), _TIMEOUT (240 s,
# a warning only, the iteration starts anyway) and _SETTLE (6 s: ceil(SETTLE/2) equal samples, 2 s apart). The
# poll is done here, over SSH, so it also works with a testbed-qemu image that ignores the knobs.
#
# Results of iteration N go to ARTIFACTS/iter-NN (cram.xml, cram-post.xml, the collected files, the .err
# files); ARTIFACTS/san-loop.txt lists the iterations; ARTIFACTS/san-uptime-end.txt has the guest uptime at
# the end of every iteration (for the age of the last sample); iter-NN/reset.log has the reset after iteration NN.
# A failing cram test does not stop the loop; a DUT that is gone or a failed reset does (exit 1).
#
# Environment: PRPLOS_SOURCE_ROOT (the checkout, default: the current directory), TESTBED_QEMU_ARTIFACT_ROOT
# (default /artifacts), DUT_BOARD (default qemu-x86-64), SANITIZE_LOOP_SECONDS, SANITIZE_MAX_ITERATIONS
# (default 0 = no limit; a limit helps a trial run), SANITIZE_DUT_WAIT (seconds, default 300),
# SANITIZE_RESET (default 1; 0 = no factory reset between iterations, only the reboot of reboot.t),
# SANITIZE_MIN_MEM_KB (default 0 = no check; else the loop stops before the first iteration when the guest has
# less MemTotal, in kB),
# TESTBED_QEMU_DATAMODEL_WAIT_FOR, _TIMEOUT, _SETTLE (after the reset, see above).
set -uo pipefail

root=${PRPLOS_SOURCE_ROOT:-$PWD}
art=${TESTBED_QEMU_ARTIFACT_ROOT:-/artifacts}
board=${DUT_BOARD:-qemu-x86-64}
budget=${SANITIZE_LOOP_SECONDS:-10800}
max_iter=${SANITIZE_MAX_ITERATIONS:-0}
dut_wait=${SANITIZE_DUT_WAIT:-300}
do_reset=${SANITIZE_RESET:-1}
min_mem_kb=${SANITIZE_MIN_MEM_KB:-0}
# Unset: the values of the sanitize job. Set but empty (WAIT_FOR): no prefix, only a stable line count.
dm_prefix=${TESTBED_QEMU_DATAMODEL_WAIT_FOR-Device.WiFi.}
dm_timeout=${TESTBED_QEMU_DATAMODEL_TIMEOUT:-240}
dm_settle=${TESTBED_QEMU_DATAMODEL_SETTLE:-6}
cram=.gitlab/tests/cram
san=$cram/sanitize

[[ $budget =~ ^[0-9]+$ && $max_iter =~ ^[0-9]+$ && $dut_wait =~ ^[0-9]+$ && $min_mem_kb =~ ^[0-9]+$ ]] || { echo "run-loop: the SANITIZE_* values take whole numbers" >&2; exit 2; }
[[ $do_reset =~ ^[01]$ ]] || { echo "run-loop: SANITIZE_RESET is 0 or 1" >&2; exit 2; }
[[ $dm_timeout =~ ^[0-9]+$ && $dm_settle =~ ^[0-9]+$ ]] || { echo "run-loop: the TESTBED_QEMU_DATAMODEL_* values take whole numbers" >&2; exit 2; }
# The pattern of testbed-qemu (config.py): the prefix goes into a remote shell command.
[[ -z $dm_prefix || $dm_prefix =~ ^[A-Za-z0-9][A-Za-z0-9_.:{}-]{0,127}$ ]] || { echo "run-loop: TESTBED_QEMU_DATAMODEL_WAIT_FOR '$dm_prefix' is not a datamodel path prefix" >&2; exit 2; }
cd "$root" || { echo "run-loop: cannot enter $root" >&2; exit 2; }
mkdir -p "$art"

mapfile -t full < <("$cram/scripts/resolve-component-tests.py" --test-root "$cram" --manifest components.yml --board "$board" --component full)
if ((${#full[@]} == 0)); then
    echo "run-loop: the [full] selection of $board is empty" >&2
    exit 2
fi
for t in "$san/000-san-sampler.t" "$san/010-san-broadcast.t" "$san/020-san-netprobe.t" "$san/post"; do
    [[ -e $t ]] || { echo "run-loop: missing $t" >&2; exit 2; }
done
# The leak check broadcast has to run before the reboot test. Without that test in the selection it would
# end up after the last test of the iteration and the leak check would not see what the tests left behind.
reboot_test=0
for t in "${full[@]}"; do
    [[ $t == */qemu-x86-64/reboot.t ]] && reboot_test=1
done
((reboot_test)) || { echo "run-loop: no */qemu-x86-64/reboot.t in the [full] selection of $board: the leak check broadcast has no place before the reboot" >&2; exit 2; }

# Files that one iteration leaves in the artifacts directory, and the test trees with the .err files.
iter_files=(cram.xml cram-post.xml cram.txt sanitizer-reports.tar.gz logread-full.txt logread-prereboot.txt
    pm-tests-prereboot.json san-broadcast.txt san-rss.log proc-rss.txt proc-rss-prereboot.txt)
err_dirs=(generic qemu-x86-64 sanitize post wifi prplmesh)

# --- factory reset between iterations ---------------------------------------------------------------------

reset_log=/dev/null
rlog() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*" | tee -a "$reset_log"; }

# dut_ssh SECONDS COMMAND: one command on the DUT, bounded in time, stdin closed.
dut_ssh() { timeout "$1" testbed-qemu ssh "$2" </dev/null; }

dut_uptime() {
    local v
    v=$(dut_ssh 10 "cut -d' ' -f1 /proc/uptime" 2>/dev/null | tr -d '\r' | tail -n 1)
    [[ $v =~ ^[0-9]+(\.[0-9]+)?$ ]] && echo "${v%.*}"
}

# The kernel's boot id: it differs after every boot, which an uptime comparison cannot promise.
dut_boot_id() {
    local v
    v=$(dut_ssh 10 'cat /proc/sys/kernel/random/boot_id' 2>/dev/null | tr -d '\r' | tail -n 1)
    [[ $v =~ ^[0-9a-f-]{8,}$ ]] && echo "$v"
}

# Wait for the datamodel as the knobs of testbed-qemu do at the first boot: obuspa dumps the datamodel, which is
# ready when the line count stays the same, and the prefix is in it, for ceil(settle/2) samples 2 s apart. A
# time out is a warning: the iteration starts anyway. Sets dm_state.
dm_wait() {
    local t0=$SECONDS deadline=$((SECONDS + dm_timeout)) need=$(((dm_settle + 1) / 2))
    local stable=0 prev='' prev_pres='' cnt pres out rc cmd last='no answer'
    if [[ -n $dm_prefix ]]; then
        cmd="set -o pipefail; obuspa -f /etc/obuspa.db -c dump datamodel | awk -v p='$dm_prefix' 'index(\$0, p) == 1 { f = 1 } END { print NR, f + 0 }'"
    else
        cmd="set -o pipefail; obuspa -f /etc/obuspa.db -c dump datamodel | awk 'END { print NR, 1 }'"
    fi
    while ((SECONDS < deadline)); do
        out=$(timeout 8 testbed-qemu ssh "$cmd" </dev/null 2>/dev/null)
        rc=$?
        if ((rc == 127)); then
            dm_state="skipped (obuspa is not installed)"
            return 0
        fi
        read -r cnt pres <<<"$out"
        if ((rc == 0)) && [[ $cnt =~ ^[0-9]+$ && $pres =~ ^[01]$ ]] && ((cnt > 0)); then
            last="$cnt lines, prefix ${dm_prefix:-none} $([[ $pres == 1 ]] && echo present || echo missing)"
            if [[ $pres == 1 && $prev_pres == 1 && $cnt == "$prev" ]]; then stable=$((stable + 1)); else stable=0; fi
            prev=$cnt
            prev_pres=$pres
            if [[ $pres == 1 ]] && ((stable >= need)); then
                dm_state="ready after $((SECONDS - t0)) s ($last)"
                return 0
            fi
        else
            prev='' prev_pres='' stable=0
        fi
        sleep 2
    done
    dm_state="NOT READY after ${dm_timeout} s ($last); the iteration starts anyway"
    return 1
}

# Copy /ext/sanitizer and the sampler log out of the guest once more before the reset wipes them. The collector
# has done it at the end of the iteration; this catches what came after (a late report, a sample). A copy
# replaces the collected one only when it has more entries (lines).
sweep_ext() {
    local d=$1 n_new n_old
    local tgz=$d/.sweep-reports.tgz log=$d/.sweep-rss.log
    if dut_ssh 120 'tar -czf - -C / ext/sanitizer 2>/dev/null' >"$tgz"; then
        n_new=$(tar -tzf "$tgz" 2>/dev/null | wc -l)
        n_old=$(tar -tzf "$d/sanitizer-reports.tar.gz" 2>/dev/null | wc -l)
        if ((n_new > n_old)); then
            mv -f -- "$tgz" "$d/sanitizer-reports.tar.gz"
            rlog "copy-out: sanitizer-reports.tar.gz replaced, $n_old -> $n_new entries"
        else
            rlog "copy-out: sanitizer-reports.tar.gz kept, collected $n_old entries, guest $n_new"
        fi
    else
        rlog "copy-out: tar of /ext/sanitizer failed"
    fi
    rm -f -- "${tgz:?}"
    if dut_ssh 60 'cat /ext/sanitizer/san-rss.log' >"$log" 2>/dev/null; then
        n_new=$(wc -l <"$log")
        n_old=$([[ -f $d/san-rss.log ]] && wc -l <"$d/san-rss.log" || echo 0)
        if ((n_new > n_old)); then
            mv -f -- "$log" "$d/san-rss.log"
            rlog "copy-out: san-rss.log replaced, $n_old -> $n_new lines"
        else
            rlog "copy-out: san-rss.log kept, collected $n_old lines, guest $n_new"
        fi
    else
        rlog "copy-out: no san-rss.log on the guest"
    fi
    rm -f -- "${log:?}"
}

# reset_dut TAG DIR: copy out, firstboot -y, reboot, wait for SSH and the datamodel. Log: DIR/reset.log.
# Returns 1 when the reset failed (no firstboot, no reboot, no SSH, state still there).
reset_dut() {
    local tag=$1 d=$2 up_before up_after boot_before boot_after out gone i
    reset_log=$d/reset.log
    rlog "reset after $tag"
    sweep_ext "$d"
    up_before=$(dut_uptime) || up_before=
    boot_before=$(dut_boot_id) || boot_before=
    rlog "uptime before: ${up_before:-unknown} s, boot id ${boot_before:-unknown}"
    # The marker is on the overlay: it has to be gone after the reboot.
    if ! dut_ssh 20 "echo $tag > /etc/san-loop-marker && sync"; then
        rlog "FAILED: cannot write the marker /etc/san-loop-marker"
        return 1
    fi
    out=$(dut_ssh 120 'firstboot -y 2>&1; echo "firstboot rc=$?"' 2>&1 | tr -d '\r')
    printf '%s\n' "$out" >>"$reset_log"
    if [[ $out != *'firstboot rc=0'* ]]; then
        rlog "FAILED: firstboot -y did not return 0"
        return 1
    fi
    dut_ssh 30 'sync; reboot' >/dev/null 2>&1 || true
    gone=0
    for ((i = 0; i < 90; i++)); do
        if ! dut_ssh 8 true >/dev/null 2>&1; then gone=1; break; fi
        sleep 1
    done
    if ((!gone)); then
        rlog "FAILED: SSH did not go away within 90 s after reboot"
        return 1
    fi
    if ! testbed-qemu wait --timeout "$dut_wait"; then
        rlog "FAILED: no SSH ${dut_wait} s after the reboot"
        return 1
    fi
    up_after=$(dut_uptime) || up_after=
    boot_after=$(dut_boot_id) || boot_after=
    rlog "SSH is back, uptime ${up_after:-unknown} s, boot id ${boot_after:-unknown}"
    if [[ -n $boot_before && $boot_before == "$boot_after" ]]; then
        rlog "FAILED: the DUT did not boot again (same boot id)"
        return 1
    fi
    if dut_ssh 20 'test -e /etc/san-loop-marker'; then
        rlog "FAILED: /etc/san-loop-marker survived: the overlay was not reset"
        return 1
    fi
    dm_state=''
    dm_wait
    rlog "datamodel: $dm_state"
    return 0
}

start=$(date +%s)
iter=0
rc_loop=0
bad_iters=0
echo "run-loop: ${#full[@]} tests in the [full] selection of $board; wall time budget $budget s"
while :; do
    iter=$((iter + 1))
    tag=$(printf 'iter-%02d' "$iter")
    t0=$(date +%s)
    if ! testbed-qemu wait --timeout "$dut_wait"; then
        echo "run-loop: the DUT does not answer after ${dut_wait}s, stopping before $tag" >&2
        printf '%s DUT-GONE at %s\n' "$tag" "$(date -u +%FT%TZ)" >>"$art/san-loop.txt"
        rc_loop=1
        break
    fi

    # The RAM of the guest: a testbed-qemu image that ignores --memory would boot with its default and the OOM
    # killer would end the daemons within minutes.
    if ((iter == 1 && min_mem_kb > 0)); then
        mem_kb=''
        for _ in 1 2 3; do
            mem_kb=$(dut_ssh 10 "awk '/^MemTotal:/ { print \$2 }' /proc/meminfo" 2>/dev/null | tr -d '\r' | tail -n 1)
            [[ $mem_kb =~ ^[0-9]+$ ]] && break
            sleep 5
        done
        echo "run-loop: guest MemTotal ${mem_kb:-unknown} kB (SANITIZE_MIN_MEM_KB $min_mem_kb)"
        if [[ ! $mem_kb =~ ^[0-9]+$ ]] || ((mem_kb < min_mem_kb)); then
            echo "run-loop: guest MemTotal ${mem_kb:-unknown} kB is below $min_mem_kb kB: --memory did not reach QEMU (a testbed-qemu image without --memory?), stopping" >&2
            printf '%s LOW-GUEST-MEMORY MemTotal=%s kB, minimum %s kB\n' "$tag" "${mem_kb:-unknown}" "$min_mem_kb" >>"$art/san-loop.txt"
            rc_loop=1
            break
        fi
    fi

    list=("$san/000-san-sampler.t")
    ((iter == 1)) && list+=("$san/020-san-netprobe.t")
    broadcast=0
    for t in "${full[@]}"; do
        if [[ $t == */qemu-x86-64/reboot.t && $broadcast == 0 ]]; then
            list+=("$san/010-san-broadcast.t")
            broadcast=1
        fi
        list+=("$t")
    done

    echo "run-loop: $tag starts at $(date -u +%FT%TZ), ${#list[@]} tests, $((t0 - start)) s into the budget"
    testbed-qemu cram --post "$cram/post/generic" --post "$san/post" "${list[@]}"
    rc=$?

    # Guest uptime at the end of the iteration, for the age check of the last SANRSS sample.
    up=-
    for _ in 1 2 3; do
        v=$(testbed-qemu ssh "cut -d' ' -f1 /proc/uptime" 2>/dev/null | tr -d '\r' | tail -n 1)
        if [[ $v =~ ^[0-9]+(\.[0-9]+)?$ ]]; then up=$v; break; fi
        sleep 5
    done
    printf '%s %s %s\n' "$iter" "$(date +%s)" "$up" >>"$art/san-uptime-end.txt"

    d=$art/$tag
    mkdir -p "$d"
    for f in "${iter_files[@]}"; do
        [[ -e $art/$f ]] && mv -- "$art/$f" "$d/"
    done
    for e in "${err_dirs[@]}"; do
        [[ -d $art/$e ]] && mv -- "$art/$e" "$d/"
    done
    # run.log of testbed-qemu holds the offsets of the test results; keep the state at the end of the iteration
    [[ -f $art/run.log ]] && cp -- "$art/run.log" "$d/run.log"

    t1=$(date +%s)
    printf '%s start=%s end=%s seconds=%d cram_rc=%d uptime_end=%s\n' "$tag" "$(date -u -d "@$t0" +%FT%TZ)" "$(date -u -d "@$t1" +%FT%TZ)" \
        "$((t1 - t0))" "$rc" "$up" >>"$art/san-loop.txt"
    echo "run-loop: $tag done in $((t1 - t0)) s, cram exit $rc"

    # The console log of testbed-qemu is the evidence of the metrics checks: a wrong artifact directory loses it.
    if ((iter == 1)) && [[ ! -s $art/serial.log ]]; then
        echo "run-loop: $art/serial.log is missing or empty after the first iteration: wrong TESTBED_QEMU_ARTIFACT_ROOT? The console checks have nothing to read" >&2
        printf '%s NO-SERIAL-LOG at %s\n' "$tag" "$(date -u +%FT%TZ)" >>"$art/san-loop.txt"
        rc_loop=1
        break
    fi
    # A testbed that fails at once gives short iterations without a cram result, each followed by a factory reset,
    # until the time budget is spent. Stop after two of them in a row.
    if [[ ! -s $d/cram.xml ]] || ((t1 - t0 < 60)); then bad_iters=$((bad_iters + 1)); else bad_iters=0; fi
    if ((bad_iters >= 2)); then
        printf '%s ABORTED at %s: %d iterations in a row without a cram.xml or shorter than 60 s\n' "$tag" "$(date -u +%FT%TZ)" "$bad_iters" >>"$art/san-loop.txt"
        echo "run-loop: $bad_iters iterations in a row without a cram.xml or shorter than 60 s, the testbed does not work: stopping" >&2
        rc_loop=1
        break
    fi

    ((max_iter > 0 && iter >= max_iter)) && break
    ((t1 - start >= budget)) && break

    if ((do_reset)); then
        t2=$(date +%s)
        dm_state=''
        if reset_dut "$tag" "$d"; then
            printf '%s RESET ok seconds=%d datamodel=%s\n' "$tag" "$(($(date +%s) - t2))" "$dm_state" >>"$art/san-loop.txt"
        else
            printf '%s RESET-FAILED at %s, see %s/reset.log\n' "$tag" "$(date -u +%FT%TZ)" "$tag" >>"$art/san-loop.txt"
            echo "run-loop: the factory reset after $tag failed, stopping" >&2
            rc_loop=1
            break
        fi
    fi
done
echo "run-loop: $iter iteration(s), $(($(date +%s) - start)) s"
exit "$rc_loop"
