#!/usr/bin/env bash
# make-world.sh: the world build of the sanitize build job, in steps, so that a build that hangs or fails still
# ends with a finished image or with the exact command that failed:
#   1. make -j JOBS, limited to 2 h;
#   2. make -j JOBS/2, limited to 2 h, in the same tree;
#   3. make -j1 V=s without a limit of its own (the script timeout of the job stops it): it prints the command
#      of a failure.
# timeout runs make in a process group of its own and sends SIGTERM to the whole group; --kill-after sends SIGKILL
# when make is still there 5 min later. After a failed step, SIGKILL to that group also stops a process that
# ignored SIGTERM while make exited, so no make job of a failed step goes on beside the next step.
#
# Usage: make-world.sh JOBS   (MAKE_STEP_LIMIT and MAKE_KILL_AFTER change 2h and 5m, for a test)
set -u
jobs=${1:-}
if [[ ! $jobs =~ ^[1-9][0-9]*$ ]]; then
    echo "usage: make-world.sh JOBS (a positive number, not '$jobs')" >&2
    exit 2
fi
limit=${MAKE_STEP_LIMIT:-2h}
kill_after=${MAKE_KILL_AFTER:-5m}
steps=("$jobs")
((jobs > 1)) && steps+=($((jobs / 2)))

for j in "${steps[@]}"; do
    echo "make-world: make -j $j, time limit $limit"
    timeout --kill-after="$kill_after" "$limit" make -j "$j" &
    pid=$!   # timeout leads the process group: its pid is the group id
    wait "$pid"
    rc=$?
    ((rc == 0)) && exit 0
    if kill -KILL -- "-$pid" 2>/dev/null; then echo "make-world: killed the processes left of make -j $j"; fi
    echo "make-world: make -j $j failed with exit $rc (124 or 137: time limit)"
done
echo "make-world: make -j1 V=s"
exec make -j1 V=s
