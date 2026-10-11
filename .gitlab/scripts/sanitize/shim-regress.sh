#!/usr/bin/env bash
# Regression test for the sanitizer shim (package sanitizer-shim, preloaded through /etc/ld.so.preload
# on the glibc image). Runs on the build host (the CI build job after the image
# build): test programs are cross-built with the target toolchain and run in bwrap on top of the target
# rootfs, with the shim .so under test bound over /usr/lib/libsanitizer-shim.so. No QEMU, no make.
# bwrap needs unprivileged user namespaces; "shim-regress.sh --preflight" checks that and exits.
# The sandbox keeps the network namespace of the caller (--share-net): a CI container may not set up the
# loopback of a new one, and no test case uses the network.
#
# Usage: shim-regress.sh [--prplos DIR] [--shim PATH] [--rootfs DIR] [--gcc PATH] [--only CASE[,CASE]]
#                        [--keep] [--list] [--preflight]
#   --prplos  build tree (default: the current directory)
#   --shim    libsanitizer-shim.so to test (default: the package build output under build_dir)
#   --rootfs  target rootfs, needs libasan.so.8 + libubsan.so.1 + the image's ld.so.preload
#             (default: build_dir/target-*glibc*/root-*)
#   --keep    keep the scratch directory (printed at the end)
# Output: one PASS/FAIL line per case, then a summary. Exit 0 = all cases pass, 1 = a case failed,
# 2 = setup problem (no shim, rootfs, toolchain or bwrap; nothing was judged).
#
# Cases (every one has its own console file bound over /dev/console, own log dir, own pid namespace):
#   g4-writable    t.c (heap-buffer-overflow, invalid shift, 64-byte leak), log dir writable: exactly 3
#                  "SANREPORT sant <pid> <type> <file>" lines, one per type, files exist in the log dir.
#   g4-readonly    same, log dir read-only (--ro-bind): 3 lines with file "console"; the console minus
#                  the SANREPORT lines equals stderr (the copy is complete and has no extra lines).
#   die-asan       ASAN_OPTIONS=halt_on_error=1: the process dies; exactly one SANDEATH, and a SANREPORT
#                  of the same exe and pid before it. The line has the form
#                  "SANDEATH <exe> <pid> logdir=<rw|ro|missing> lsan_off=<0|1>"; here logdir=rw lsan_off=0.
#   die-ubsan      UBSAN_OPTIONS=halt_on_error=1: same for libubsan.
#   death-lsan-off the die-asan program, named busybox in the sandbox (bound as /tmp/busybox; the rootfs
#                  ships /etc/sanitizer/off/busybox): one SANDEATH with lsan_off=1 (logdir=rw).
#   death-logdir-ro starts with a writable log dir; at about 2 s (before the early open at 10 s) the host
#                  makes the dir 0555, then a forced ASan error with halt_on_error=1: libsanitizer
#                  cannot open its report file and dies. Expect exit 1 and one SANDEATH with logdir=ro
#                  lsan_off=0. There may be no SANREPORT: that death is "unmatched-expected" (the console
#                  index lists it UNMATCHED; the case reports it and still passes).
#   early-open     starts with a writable dir, sleeps 12 s (the shim opens the report file at about
#                  10 s), the host then chmods the dir 0555 (the program checks inside that an
#                  open(O_CREAT) really fails), the program triggers a recoverable ASan error: it
#                  exits 0, no SANDEATH, the report body is in the early-opened file.
#   early-control  negative control: dir unwritable from the start, short-lived process reports before
#                  the early open: exit 0, no SANDEATH, report on stderr + console, no file.
#   no-proc        at shutdown procd unmounts /proc and LSan's exit check then dies ("LeakSanitizer
#                  has encountered a fatal error"). A program that only leaks 64 bytes runs under bwrap with
#                  an empty tmpfs on /proc: exit 0, exactly one "SANSKIP <exe> <pid> leak-check no-proc" console
#                  line, no SANDEATH. The exe name is program_invocation_short_name; report file names become
#                  report.exe.<pid> without /proc, so no file name is asserted.
#   no-proc-off    the same program bound as /tmp/busybox (rootfs ships /etc/sanitizer/off/busybox), no /proc:
#                  only exit 0 and no SANDEATH are asserted (a SANSKIP line is expected but not required).
#   g7-signalfd    SIGCHLD blocked in main only, read through signalfd: 20 of 20 arrive (G7a).
#   g7-sigmask     sigprocmask(SIG_SETMASK, empty) in main, then 20x kill -37 in a burst: the process
#                  is still alive and exits 0 (G7b).
#   g7-sigmask-eintr (extra, only with --only) the same with a plain sleep() that the signal cuts short
#                  in the main thread: the process then exits while the worker's leak check runs.
# Slow cases run in parallel; the whole run takes about 20 s.
set -uo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
prplos=$PWD
shim='' rootfs='' gcc='' only='' keep=0 list=0 preflight=0
case_timeout=60
early_sleep=12
all_cases=(g4-writable g4-readonly die-asan die-ubsan death-lsan-off death-logdir-ro early-open early-control no-proc no-proc-off g7-signalfd g7-sigmask)
death_sleep=2 # death-logdir-ro: seconds before the host makes the dir unwritable (must stay below the early open at 10 s)
extra_cases=(g7-sigmask-eintr) # run only with --only: informational, see the case list above

die() { echo "shim-regress: $*" >&2; exit 2; }
usage() { awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "${BASH_SOURCE[0]}"; exit "${1:-2}"; }

while (($#)); do
    case $1 in
        --prplos) prplos=$2; shift 2 ;;
        --shim) shim=$2; shift 2 ;;
        --rootfs) rootfs=$2; shift 2 ;;
        --gcc) gcc=$2; shift 2 ;;
        --only) only=$2; shift 2 ;;
        --keep) keep=1; shift ;;
        --list) list=1; shift ;;
        --preflight) preflight=1; shift ;;
        -h|--help) usage 0 ;;
        *) usage ;;
    esac
done
if ((list)); then printf '%s\n' "${all_cases[@]}" "${extra_cases[@]}"; exit 0; fi

newest() { # newest FILE among the glob matches
    local f best='' bt=0 t
    for f in "$@"; do
        [[ -e $f ]] || continue
        t=$(stat -c %Y -- "$f")
        ((t >= bt)) && { best=$f; bt=$t; }
    done
    printf '%s' "$best"
}

command -v bwrap >/dev/null || die "bwrap not found"
if ((preflight)); then
    bwrap --unshare-all --share-net --ro-bind / / --dev /dev --proc /proc true 2>&1 || die "bwrap cannot set up its sandbox here (see its error above)"
    echo "shim-regress: bwrap works"
    exit 0
fi
command -v timeout >/dev/null || die "timeout not found"
[[ -n $shim ]] || shim=$(newest "$prplos"/build_dir/target-*glibc*/sanitizer-shim/libsanitizer-shim.so)
[[ -n $shim && -f $shim ]] || die "no libsanitizer-shim.so under $prplos/build_dir/target-*glibc*/sanitizer-shim (use --shim)"
shim=$(realpath -e -- "$shim")
if [[ -z $rootfs ]]; then
    for d in "$prplos"/build_dir/target-*glibc*/root-*; do [[ -d $d ]] && rootfs=$d; done
fi
[[ -n $rootfs && -d $rootfs ]] || die "no target rootfs under $prplos/build_dir/target-*glibc*/root-* (use --rootfs)"
rootfs=$(realpath -e -- "$rootfs")
[[ -e $rootfs/lib/libasan.so.8 && -e $rootfs/lib/libubsan.so.1 && -e $rootfs/etc/ld.so.preload ]] ||
    die "rootfs $rootfs lacks libasan.so.8, libubsan.so.1 or etc/ld.so.preload"
grep -q libsanitizer-shim "$rootfs/etc/ld.so.preload" || die "$rootfs/etc/ld.so.preload does not preload the shim"
if [[ -z $gcc ]]; then
    for g in "$prplos"/staging_dir/toolchain-*glibc*/bin/*-linux-gnu-gcc; do [[ -x $g ]] && gcc=$g; done
fi
[[ -n $gcc && -x $gcc ]] || die "no glibc target gcc under $prplos/staging_dir (use --gcc)"
export STAGING_DIR=$prplos/staging_dir

base=${TMPDIR:-/tmp}
mkdir -p -- "$base"
work=$(mktemp -d "$base/shim-regress.XXXXXX") || die "cannot create a scratch directory under $base"
cleanup() {
    local rc=$?
    jobs -p | xargs -r kill 2>/dev/null
    if ((keep)); then
        echo "shim-regress: scratch kept: $work" >&2
    else
        chmod -R u+rwx -- "${work:?}" 2>/dev/null
        rm -rf -- "${work:?}"
    fi
    exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

# ---- test programs --------------------------------------------------------------------------------

src=$work/src bin=$work/bin res=$work/res
mkdir -p "$src" "$bin" "$res"

cat >"$src/sant.c" <<'EOF'
#include <stdlib.h>
#include <stdio.h>
int main(int argc, char **argv)
{
	char *p = malloc(8);
	volatile int sh = 63 + argc;
	int x = 1 << sh;           /* UBSan: invalid shift exponent */
	p[8] = 'x';                /* ASan: heap-buffer-overflow, recoverable */
	void *leak = malloc(64);   /* LSan at exit */
	(void)leak; (void)argv;
	printf("done %d\n", x);
	free(p);
	return 0;
}
EOF

cat >"$src/dieasan.c" <<'EOF'
#include <stdlib.h>
#include <stdio.h>
int main(void)
{
	char *p = malloc(8);
	volatile int i = 8;
	p[i] = 'x';                /* halt_on_error=1: Die() in libasan */
	puts("survived");
	free(p);
	return 0;
}
EOF

cat >"$src/leak.c" <<'EOF'
#include <stdlib.h>
int main(void)
{
	void *volatile leak = malloc(64);   /* LSan at exit; no error otherwise */
	(void)leak;
	return 0;
}
EOF

cat >"$src/dieubsan.c" <<'EOF'
#include <stdio.h>
int main(void)
{
	volatile int sh = 64;
	int x = 1 << sh;           /* halt_on_error=1: Die() in libubsan */
	puts("survived");
	return x == 12345;
}
EOF

# early <seconds>: sleep, wait until the log dir is really unwritable, then one recoverable ASan error.
cat >"$src/early.c" <<'EOF'
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
int main(int argc, char **argv)
{
	const char *dir = "/ext/sanitizer";
	char probe[256];
	int i, ok = 0;

	setvbuf(stdout, NULL, _IONBF, 0);
	sleep(argc > 1 ? atoi(argv[1]) : 0);
	puts("slept");
	snprintf(probe, sizeof(probe), "%s/probe.%d", dir, (int)getpid());
	for (i = 0; i < 150 && !ok; i++) {
		int fd = open(probe, O_WRONLY | O_CREAT | O_EXCL, 0600);
		if (fd < 0) {
			printf("probe: dir unwritable: %s\n", strerror(errno));
			ok = 1;
		} else {
			close(fd);
			unlink(probe);
			usleep(200000);
		}
	}
	if (!ok) {
		puts("probe: dir stayed writable");
		return 3;
	}
	char *p = malloc(8);
	volatile int k = 8;
	p[k] = 'x';                /* recoverable heap-buffer-overflow */
	puts("survived");
	free(p);
	return 0;
}
EOF

cat >"$src/sfd.c" <<'EOF'
/* amxp_syssig pattern: block SIGCHLD in main only, read it through signalfd */
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/signalfd.h>
#include <poll.h>
#include <unistd.h>
int main(void)
{
	sigset_t m;
	int fd, got = 0, i;

	sigemptyset(&m);
	sigaddset(&m, SIGCHLD);
	sigprocmask(SIG_BLOCK, &m, NULL);
	fd = signalfd(-1, &m, SFD_NONBLOCK);
	for (i = 0; i < 20; i++) {
		if (fork() == 0)
			_exit(0);
		struct pollfd p = { fd, POLLIN, 0 };
		if (poll(&p, 1, 500) == 1) {
			struct signalfd_siginfo si;
			if (read(fd, &si, sizeof(si)) == sizeof(si))
				got++;
		}
	}
	printf("SIGCHLD via signalfd: %d of 20\n", got);
	return 0;
}
EOF

cat >"$src/sigmask.c" <<'EOF'
/* Reset the signal mask like a program that does SIG_SETMASK, then idle for 5 s.
 * Default: a sleep that restarts after a signal. "eintr": plain sleep(), which a signal that reaches
 * the main thread cuts short (the process then exits while the worker's leak check runs). */
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
int main(int argc, char **argv)
{
	sigset_t e;
	char *p = malloc(16);
	time_t t0 = time(NULL);

	setvbuf(stdout, NULL, _IONBF, 0);
	sigemptyset(&e);
	sigprocmask(SIG_SETMASK, &e, NULL);
	puts("mask reset");
	if (argc > 1 && !strcmp(argv[1], "eintr")) {
		sleep(5);
	} else {
		while (time(NULL) - t0 < 5) {
			struct timespec ts = { 0, 100000000 };
			nanosleep(&ts, NULL);
		}
	}
	puts("alive");
	free(p);
	return 0;
}
EOF

build_one() {
    "$gcc" -g -O0 -fno-omit-frame-pointer -fsanitize=address,undefined -fsanitize-recover=address \
        -o "$bin/$1" "$src/$1.c" 2>"$work/cc-$1.log" ||
        { sed 's/^/  cc: /' "$work/cc-$1.log" >&2; die "cannot compile $1.c with $gcc"; }
}
for p in sant dieasan dieubsan early sfd sigmask leak; do build_one "$p"; done
# death-lsan-off: the same forced-Die program under the name busybox (the shim's off list is by exe name)
cp -- "$bin/dieasan" "$bin/busybox"
# no-proc-off: the leaking program under the name busybox (own dir: --bin binds by basename)
mkdir -p "$bin/off"
cp -- "$bin/leak" "$bin/off/busybox"

# ---- sandbox helpers ------------------------------------------------------------------------------

# sb_run CASEDIR MODE [--env K V]... [--bin PATH]... [--no-proc] -- COMMAND [ARG...]
# MODE rw|ro: CASEDIR/logdir bound writable or read-only on /ext/sanitizer. Writes CASEDIR/{console,out,err,rc}.
# --no-proc: an empty tmpfs on /proc instead of a real procfs (procd has unmounted /proc at shutdown).
# The bind target is /ext/sanitizer. The mount point must exist in the (read-only) rootfs: the rootfs gets
# /ext/sanitizer from the shim package. With an older shim package bwrap can fail on the bind
# (no such directory). Do not work around it by changing the rootfs; rebuild the shim first.
sb_run() {
    local cdir=$1 mode=$2 bindopt=--bind
    shift 2
    local -a envs=() bins=() procopt=(--proc /proc)
    while (($#)); do
        case $1 in
            --no-proc) procopt=(--tmpfs /proc); shift ;;
            --env) envs+=(--setenv "$2" "$3"); shift 3 ;;
            --bin) bins+=(--ro-bind "$2" "/tmp/$(basename "$2")"); shift 2 ;;
            --) shift; break ;;
            *) echo "sb_run: bad argument $1" >&2; return 2 ;;
        esac
    done
    [[ $mode == ro ]] && bindopt=--ro-bind
    : >"$cdir/console"
    timeout "$case_timeout" bwrap --unshare-all --share-net --die-with-parent \
        --ro-bind "$rootfs" / "${procopt[@]}" --dev /dev --tmpfs /tmp \
        --bind "$cdir/console" /dev/console \
        --ro-bind "$shim" /usr/lib/libsanitizer-shim.so \
        "${bins[@]}" "$bindopt" "$cdir/logdir" /ext/sanitizer \
        "${envs[@]}" "$@" >"$cdir/out" 2>"$cdir/err"
    echo $? >"$cdir/rc"
}

new_case() { # new_case NAME -> prints the case dir
    mkdir -p "$work/c/$1/logdir"
    echo "$work/c/$1"
}

# verdicts: pass NAME DETAIL / fail NAME REASON; first one wins; written to res/NAME
pass() { [[ -e $res/$1 ]] || printf 'PASS %s\n' "$2" >"$res/$1"; }
fail() { [[ -e $res/$1 ]] || printf 'FAIL %s\n' "$2" >"$res/$1"; }

# console_reports CONSOLE EXE: the "SANREPORT EXE PID TYPE FILE" lines
console_reports() { grep -aE "^SANREPORT $2 [0-9]+ " "$1" || true; }
# count_lines FILE ERE
count_lines() { grep -acE "$2" "$1" || true; }

# check_three_reports NAME CASEDIR FILE_MODE: shared by g4-writable and g4-readonly
check_three_reports() {
    local name=$1 cdir=$2 mode=$3 lines n pids types f
    lines=$(console_reports "$cdir/console" sant)
    n=$(grep -c . <<<"$lines")
    [[ -n $lines ]] || n=0
    ((n == 3)) || { fail "$name" "$name: expected exactly 3 '^SANREPORT sant <pid> ' lines, got $n"; return 1; }
    pids=$(awk '{print $3}' <<<"$lines" | sort -u | wc -l)
    ((pids == 1)) || { fail "$name" "$name: SANREPORT lines carry $pids different pids"; return 1; }
    types=$(awk '{print $4}' <<<"$lines" | sort -u | tr '\n' ' ')
    (($(wc -w <<<"$types") == 3)) || { fail "$name" "$name: not one line per type (types: $types)"; return 1; }
    for t in heap-buffer-overflow leak; do
        [[ " $types" == *" $t "* ]] || { fail "$name" "$name: missing type $t (types: $types)"; return 1; }
    done
    [[ $types == *shift* ]] || { fail "$name" "$name: missing the shift type (types: $types)"; return 1; }
    if [[ $mode == rw ]]; then
        while read -r _ _ pid _ f; do
            [[ $f == /ext/sanitizer/report.sant.$pid* ]] ||
                { fail "$name" "$name: unexpected report file name '$f'"; return 1; }
            [[ -s $cdir/logdir/${f##*/} ]] || { fail "$name" "$name: report file $f missing or empty in the log dir"; return 1; }
        done <<<"$lines"
    else
        [[ $(awk '$5 != "console"' <<<"$lines" | wc -l) -eq 0 ]] ||
            { fail "$name" "$name: read-only dir but a SANREPORT names a file instead of console"; return 1; }
    fi
    printf '%s' "$types"
}

case_g4_writable() {
    local cdir types
    cdir=$(new_case g4-writable)
    sb_run "$cdir" rw --bin "$bin/sant" -- /tmp/sant
    [[ $(<"$cdir/rc") == 0 ]] || { fail g4-writable "g4-writable: sant exited $(<"$cdir/rc")"; return; }
    types=$(check_three_reports g4-writable "$cdir" rw) || return
    pass g4-writable "g4-writable: 3 SANREPORT lines, one per type ($types), report files in the log dir"
}

case_g4_readonly() {
    local cdir types
    cdir=$(new_case g4-readonly)
    sb_run "$cdir" ro --bin "$bin/sant" -- /tmp/sant
    [[ $(<"$cdir/rc") == 0 ]] || { fail g4-readonly "g4-readonly: sant exited $(<"$cdir/rc")"; return; }
    types=$(check_three_reports g4-readonly "$cdir" ro) || return
    grep -av '^SANREPORT ' "$cdir/console" >"$cdir/console.rest" || true
    if ! cmp -s "$cdir/console.rest" "$cdir/err"; then
        fail g4-readonly "g4-readonly: console minus SANREPORT lines != stderr ($(wc -l <"$cdir/console.rest") vs $(wc -l <"$cdir/err") lines; see --keep: console.rest, err)"
        return
    fi
    [[ -z $(ls -A "$cdir/logdir") ]] || { fail g4-readonly "g4-readonly: files appeared in the read-only dir"; return; }
    pass g4-readonly "g4-readonly: 3 SANREPORT lines ($types) with file console; console minus SANREPORT == stderr ($(wc -l <"$cdir/err") lines)"
}

# check_sandeath NAME CDIR EXE LOGDIR LSAN_OFF: exactly one SANDEATH line, in the form above
# "SANDEATH EXE <pid> logdir=LOGDIR lsan_off=LSAN_OFF" (no trailing text). Prints the pid on success.
check_sandeath() {
    local name=$1 cdir=$2 exe=$3 want_ld=$4 want_lo=$5 deaths line
    deaths=$(count_lines "$cdir/console" '^SANDEATH ')
    ((deaths == 1)) || { fail "$name" "$name: expected exactly 1 SANDEATH line, got $deaths"; return 1; }
    line=$(grep -a '^SANDEATH ' "$cdir/console")
    if ! grep -qE "^SANDEATH $exe [0-9]+ logdir=$want_ld lsan_off=${want_lo}[[:space:]]*\$" <<<"$line"; then
        fail "$name" "$name: SANDEATH line is not 'SANDEATH $exe <pid> logdir=$want_ld lsan_off=$want_lo' (got: $line)"
        return 1
    fi
    awk '{print $3}' <<<"$line"
}

# case_die NAME EXE ENVVAR [LOGDIR LSAN_OFF]: forced Die() with a report; the expected SANDEATH fields
# default to logdir=rw lsan_off=0.
case_die() {
    local name=$1 exe=$2 envvar=$3 want_ld=${4:-rw} want_lo=${5:-0} cdir lnd pid rl rc
    cdir=$(new_case "$name")
    sb_run "$cdir" rw --env "$envvar" halt_on_error=1 --bin "$bin/$exe" -- "/tmp/$exe"
    rc=$(<"$cdir/rc")
    ((rc != 0 && rc != 124)) || { fail "$name" "$name: expected the process to die, exit code $rc"; return; }
    ! grep -q survived "$cdir/out" || { fail "$name" "$name: the process went on after the error"; return; }
    pid=$(check_sandeath "$name" "$cdir" "$exe" "$want_ld" "$want_lo") || return
    lnd=$(grep -anE '^SANDEATH ' "$cdir/console" | head -n 1 | cut -d: -f1)
    rl=$(grep -anE "^SANREPORT $exe $pid " "$cdir/console" | head -n 1 | cut -d: -f1)
    [[ -n $rl ]] || { fail "$name" "$name: SANDEATH $exe $pid without a SANREPORT of that pid"; return; }
    ((rl < lnd)) || { fail "$name" "$name: SANREPORT (console line $rl) is not before SANDEATH (line $lnd)"; return; }
    pass "$name" "$name: exit $rc, 1 SANDEATH $exe $pid logdir=$want_ld lsan_off=$want_lo, SANREPORT on console line $rl before it (line $lnd)"
}

# case_death_logdir_ro: the host makes the log dir unwritable at about death_sleep s; the forced ASan error
# then kills the process because libsanitizer cannot open its report file. SANREPORT may be missing.
case_death_logdir_ro() {
    local name=death-logdir-ro cdir pid i rc dpid art idx circ note
    cdir=$(new_case "$name")
    sb_run "$cdir" rw --env ASAN_OPTIONS halt_on_error=1 --bin "$bin/early" -- /tmp/early "$death_sleep" &
    pid=$!
    for ((i = 0; i < (death_sleep + 15) * 5; i++)); do
        grep -q '^slept' "$cdir/out" 2>/dev/null && break
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.2
    done
    chmod 0555 "$cdir/logdir"
    wait "$pid"
    rc=$(<"$cdir/rc")
    if ! grep -q 'probe: dir unwritable' "$cdir/out"; then
        fail "$name" "$name: setup invalid, the dir was not unwritable inside the sandbox ($(tr '\n' ' ' <"$cdir/out"))"
        return
    fi
    ! grep -q survived "$cdir/out" || { fail "$name" "$name: the process went on after the error"; return; }
    ((rc == 1)) || { fail "$name" "$name: exit $rc, expected 1 (stderr: $(head -c 200 "$cdir/err" | tr '\n' ' '))"; return; }
    dpid=$(check_sandeath "$name" "$cdir" early ro 0) || return
    # How would the console index classify it? Run the real parser on the console as serial.log.
    art=$cdir/art
    mkdir -p "$art"
    cp -- "$cdir/console" "$art/serial.log"
    python3 -I "$here/serial-check.py" console-index --artifacts "$art" >/dev/null 2>&1
    circ=$?
    idx=$(grep -aE "^[0-9]+ +early +$dpid " "$art/san-console-index.txt" | head -n 1)
    if [[ -n $(console_reports "$cdir/console" early | grep -a " $dpid " || true) ]]; then
        note="SANREPORT present: matched ($circ)"
    elif ((circ == 3)) && [[ $idx == *UNMATCHED* ]]; then
        note="no SANREPORT: unmatched-expected (console-index exit 3, UNMATCHED)"
    else
        fail "$name" "$name: no SANREPORT, but console-index did not list the death as UNMATCHED (exit $circ, line: $idx)"
        return
    fi
    pass "$name" "$name: dir unwritable inside (verified), exit 1, 1 SANDEATH early $dpid logdir=ro lsan_off=0; $note"
}

case_early_open() {
    local name=early-open cdir pid i rc deaths body f
    cdir=$(new_case "$name")
    sb_run "$cdir" rw --bin "$bin/early" -- /tmp/early "$early_sleep" &
    pid=$!
    for ((i = 0; i < (early_sleep + 15) * 5; i++)); do
        grep -q '^slept' "$cdir/out" 2>/dev/null && break
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.2
    done
    chmod 0555 "$cdir/logdir"
    wait "$pid"
    rc=$(<"$cdir/rc")
    if ! grep -q 'probe: dir unwritable' "$cdir/out"; then
        fail "$name" "$name: setup invalid, the dir was not unwritable inside the sandbox ($(tr '\n' ' ' <"$cdir/out"))"
        return
    fi
    ((rc == 0)) || { fail "$name" "$name: exit $rc, expected 0 (the process must survive the unwritable dir; stderr: $(head -c 200 "$cdir/err" | tr '\n' ' '))"; return; }
    grep -q survived "$cdir/out" || { fail "$name" "$name: no 'survived' in the program output"; return; }
    deaths=$(count_lines "$cdir/console" '^SANDEATH ')
    ((deaths == 0)) || { fail "$name" "$name: $deaths SANDEATH line(s), expected none"; return; }
    body=''
    for f in "$cdir"/logdir/report.early.*; do
        [[ -e $f && $f != *.ubsan ]] && { body=$f; break; }
    done
    [[ -n $body ]] || { fail "$name" "$name: no early-opened report file report.early.<pid> in the log dir"; return; }
    grep -q 'heap-buffer-overflow' "$body" || { fail "$name" "$name: report body not in $(basename "$body")"; return; }
    pass "$name" "$name: exit 0 after the dir became unwritable (verified inside), no SANDEATH, report body in $(basename "$body")"
}

case_early_control() {
    local name=early-control cdir rc deaths
    cdir=$(new_case "$name")
    chmod 0555 "$cdir/logdir"
    sb_run "$cdir" rw --bin "$bin/early" -- /tmp/early 0
    rc=$(<"$cdir/rc")
    grep -q 'probe: dir unwritable' "$cdir/out" ||
        { fail "$name" "$name: setup invalid, the dir was writable inside the sandbox"; return; }
    ((rc == 0)) || { fail "$name" "$name: exit $rc, expected 0 (unwritable from the start must not kill the process)"; return; }
    deaths=$(count_lines "$cdir/console" '^SANDEATH ')
    ((deaths == 0)) || { fail "$name" "$name: $deaths SANDEATH line(s), expected none"; return; }
    [[ $(count_lines "$cdir/console" '^SANREPORT early [0-9]+ heap-buffer-overflow console$') -eq 1 ]] ||
        { fail "$name" "$name: no 'SANREPORT early <pid> heap-buffer-overflow console' line"; return; }
    grep -q 'AddressSanitizer: heap-buffer-overflow' "$cdir/err" ||
        { fail "$name" "$name: report not on stderr"; return; }
    [[ -z $(ls -A "$cdir/logdir") ]] || { fail "$name" "$name: files in the unwritable dir?"; return; }
    pass "$name" "$name: dir unwritable from the start, exit 0, no SANDEATH, report on stderr + console (SANREPORT ... console)"
}

# case_no_proc NAME BINPATH EXE STRICT: the leaking program without a real /proc. STRICT=1 asserts exactly one
# "SANSKIP EXE <pid> leak-check no-proc" line; either way exit 0 and no SANDEATH (and no LSan fatal error).
case_no_proc() {
    local name=$1 binpath=$2 exe=$3 strict=$4 cdir rc deaths skips sk
    cdir=$(new_case "$name")
    sb_run "$cdir" rw --no-proc --bin "$binpath" -- "/tmp/$exe"
    rc=$(<"$cdir/rc")
    ((rc == 0)) || { fail "$name" "$name: exit $rc, expected 0 (stderr: $(head -c 200 "$cdir/err" | tr '\n' ' '))"; return; }
    deaths=$(count_lines "$cdir/console" '^SANDEATH ')
    ((deaths == 0)) || { fail "$name" "$name: $deaths SANDEATH line(s), expected none"; return; }
    ! grep -aq 'LeakSanitizer has encountered a fatal error' "$cdir/err" "$cdir/console" ||
        { fail "$name" "$name: LSan fatal error without /proc"; return; }
    skips=$(count_lines "$cdir/console" '^SANSKIP ')
    sk=$(count_lines "$cdir/console" "^SANSKIP $exe [0-9]+ leak-check no-proc[[:space:]]*\$")
    if ((strict)); then
        ((skips == 1 && sk == 1)) ||
            { fail "$name" "$name: expected exactly 1 'SANSKIP $exe <pid> leak-check no-proc' line, got $sk of $skips SANSKIP line(s) ($(grep -a '^SANSKIP ' "$cdir/console" | head -n 2 | tr '\n' '|'))"; return; }
    fi
    pass "$name" "$name: no /proc, exit 0, no SANDEATH, $skips SANSKIP line(s) ($sk matching 'leak-check no-proc')"
}

case_g7_signalfd() {
    local name=g7-signalfd cdir
    cdir=$(new_case "$name")
    sb_run "$cdir" rw --bin "$bin/sfd" -- /tmp/sfd
    [[ $(<"$cdir/rc") == 0 ]] || { fail "$name" "$name: sfd exited $(<"$cdir/rc")"; return; }
    if grep -q '^SIGCHLD via signalfd: 20 of 20$' "$cdir/out"; then
        pass "$name" "$name: 20 of 20 SIGCHLD via signalfd with the shim loaded"
    else
        fail "$name" "$name: $(grep -a 'SIGCHLD' "$cdir/out" | head -n 1) (expected '20 of 20')"
    fi
}

# case_sigmask NAME [eintr]: the burst of 20 kill -37 comes from `kill` in the rootfs busybox sh.
case_sigmask() {
    local name=$1 cdir rc stats
    cdir=$(new_case "$name")
    # shellcheck disable=SC2016 # the script runs in the sandbox shell, not here
    sb_run "$cdir" rw --bin "$bin/sigmask" -- /bin/sh -c '
        /tmp/sigmask '"${2:-}"' & p=$!
        sleep 1
        i=0
        while [ $i -lt 20 ]; do kill -37 $p || echo "kill failed at $i"; i=$((i + 1)); done
        n=0
        while [ -d /proc/$p ] && [ $n -lt 15 ]; do sleep 1; n=$((n + 1)); done
        if [ -d /proc/$p ]; then
            echo "HUNG: still there after 15 s: $(grep State /proc/$p/status)"
            kill -9 $p
        fi
        wait $p; echo "child rc=$?"'
    rc=$(<"$cdir/rc")
    stats=$(count_lines "$cdir/console" '^SANSTATS sigmask ')
    if grep -q '^HUNG' "$cdir/out"; then
        fail "$name" "$name: $(grep '^HUNG' "$cdir/out") (process stuck at exit after the signal burst)"
        return
    fi
    if ! grep -q '^alive$' "$cdir/out" || ! grep -q '^child rc=0$' "$cdir/out"; then
        fail "$name" "$name: the process did not survive the burst ($(tr '\n' ' ' <"$cdir/out"); sh exit $rc)"
        return
    fi
    pass "$name" "$name: 20x kill -37 burst, process alive and exited 0 ($stats SANSTATS line(s) from the coalesced checks)"
}

# ---- run ------------------------------------------------------------------------------------------

selected=()
if [[ -n $only ]]; then
    IFS=, read -r -a want <<<"$only"
    for w in "${want[@]}"; do
        [[ " ${all_cases[*]} ${extra_cases[*]} " == *" $w "* ]] || die "unknown case '$w' (see --list)"
    done
    selected=("${want[@]}")
else
    selected=("${all_cases[@]}")
fi

# The slow case (about 15 s) starts first; the quick ones overlap with it, at most 4 at a time.
order=()
for c in "${selected[@]}"; do [[ $c == early-open ]] && order+=("$c"); done
for c in "${selected[@]}"; do [[ $c == early-open ]] || order+=("$c"); done
for c in "${order[@]}"; do
    (($(jobs -pr | wc -l) < 4)) || wait -n
    case $c in
        g4-writable) case_g4_writable ;;
        g4-readonly) case_g4_readonly ;;
        die-asan) case_die die-asan dieasan ASAN_OPTIONS ;;
        die-ubsan) case_die die-ubsan dieubsan UBSAN_OPTIONS ;;
        death-lsan-off) case_die death-lsan-off busybox ASAN_OPTIONS rw 1 ;;
        death-logdir-ro) case_death_logdir_ro ;;
        early-open) case_early_open ;;
        early-control) case_early_control ;;
        no-proc) case_no_proc no-proc "$bin/leak" leak 1 ;;
        no-proc-off) case_no_proc no-proc-off "$bin/off/busybox" busybox 0 ;;
        g7-signalfd) case_g7_signalfd ;;
        g7-sigmask) case_sigmask g7-sigmask ;;
        g7-sigmask-eintr) case_sigmask g7-sigmask-eintr eintr ;;
    esac &
done
wait

echo "shim-regress: shim=$shim"
echo "shim-regress: rootfs=$rootfs"
npass=0 nfail=0
for c in "${selected[@]}"; do
    if [[ -s $res/$c ]]; then
        cat "$res/$c"
        [[ $(cut -c1-4 "$res/$c") == PASS ]] && npass=$((npass + 1)) || nfail=$((nfail + 1))
    else
        echo "FAIL $c: no result (the case crashed or timed out)"
        nfail=$((nfail + 1))
    fi
done
echo "shim-regress: $npass passed, $nfail failed (of ${#selected[@]})"
((nfail == 0))
