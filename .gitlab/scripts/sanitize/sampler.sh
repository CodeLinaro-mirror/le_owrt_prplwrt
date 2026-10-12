#!/usr/bin/env bash
# sampler.sh: the resource use of the build host while the sanitize build job runs, so that a slow or stalled build
# shows whether memory, swap or IO ran short. Every INTERVAL seconds it appends one sample to LOG: a UTC timestamp,
# free -m, one vmstat line (over 1 s), the 5 largest processes by RSS and the number of cc1, cc1plus and ld processes.
# It stops within a second when the process PID (the shell of the job) is gone. Its errors go to LOG, never to the job.
#
# Usage: sampler.sh PID LOG [INTERVAL]   (default INTERVAL: 60)
#   sampler.sh $$ logs/sanitize-sampler.log </dev/null >/dev/null 2>&1 &
set -u
pid=${1:?usage: sampler.sh PID LOG [INTERVAL]}
log=${2:?usage: sampler.sh PID LOG [INTERVAL]}
interval=${3:-60}

mkdir -p -- "$(dirname -- "$log")" && exec >>"$log" 2>&1 || exit 0
echo "sampler: every ${interval} s while process $pid runs, on $(nproc) CPUs"
while kill -0 "$pid" 2>/dev/null; do
    echo "== $(date -u +%FT%TZ)"
    free -m
    vmstat -w 1 2 | sed -n '2p;$p'
    ps -eo pid,ppid,rss,pcpu,etime,args --sort=-rss | head -n 6 | cut -c 1-200
    ps -eo comm= | awk '
        $1 == "cc1" { cc1++ } $1 == "cc1plus" { cxx++ } $1 == "ld" || $1 == "ld.bfd" || $1 == "ld.gold" { ld++ }
        END { printf "compilers: cc1=%d cc1plus=%d ld=%d\n", cc1, cxx, ld }'
    for ((i = 0; i < interval; i++)); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 1
    done
done
echo "sampler: process $pid is gone at $(date -u +%FT%TZ)"
