#!/bin/sh
# Best-effort snapshots: execute this script, do not source it.
set +e

log_warning() {
	printf '\033[93mWARNING: memory-footprint: %s\033[0m\n' "$*" >&2
}

collect_snapshot() {
	# Match the SSH-ready check, including its connection retry settings.
	set -- -o BatchMode=yes -o StrictHostKeyChecking=no \
		-o "ConnectionAttempts=${DUT_SSH_CONNECT_ATTEMPTS:-3}" \
		-o "ConnectTimeout=${DUT_SSH_CONNECT_TIMEOUT:-30}"
	if ! timeout 120 scp -O "$@" \
		/usr/local/share/memory-footprint/collect.sh \
		"root@$TARGET_LAN_IP:/tmp/ci-memory-footprint-collect.sh"; then
		log_warning "$phase: could not stage collector (SSH/copy failed or timed out)"
		return 0
	fi

	# POSIX pipelines expose only gzip's status. Record SSH success separately
	# so a failed or timed-out collector cannot publish a truncated snapshot.
	if {
		timeout 120 ssh -n "$@" "root@$TARGET_LAN_IP" \
			"sh /tmp/ci-memory-footprint-collect.sh -t $phase </dev/null" &&
			: > "$work/collected"
	} | gzip > "$work/snapshot.txt.gz"; then
		if [ -f "$work/collected" ]; then
			mv "$work/snapshot.txt.gz" "$output/$phase.txt.gz"
		else
			log_warning "$phase: collection failed or timed out; discarding partial snapshot"
		fi
	else
		log_warning "$phase: could not compress snapshot; discarding partial snapshot"
	fi
}

main() {
	phase=${1:-}
	case "$phase" in
		boot|final) ;;
		*) log_warning 'expected boot or final'; return 0 ;;
	esac
	if [ "$#" -ne 1 ]; then
		log_warning 'expected exactly one phase argument'
		return 0
	fi
	board=${DUT_BOARD:-${LABGRID_TARGET:-}}
	case "$board" in
		''|.|..|*[!a-zA-Z0-9_.-]*)
			log_warning 'missing or invalid DUT_BOARD/LABGRID_TARGET'
			return 0 ;;
	esac
	if [ -z "${TARGET_LAN_IP:-}" ]; then
		log_warning "$phase: TARGET_LAN_IP is unset"
		return 0
	fi
	output="memory-footprint/$board"
	mkdir -p "$output"
	# Clear previous output if this phase is retried in the same workspace.
	rm -f "$output/$phase.txt.gz" "$output/report.html" \
		"$output/metrics.prom" "$output/summary.json"
	work=$(mktemp -d "$output/.$phase.XXXXXX") || return 0
	trap 'rm -rf "$work" || log_warning "could not remove temporary directory $work"' 0
	collect_snapshot
	[ "$phase" = final ] || return 0
	if [ ! -f "$output/boot.txt.gz" ] || [ ! -f "$output/final.txt.gz" ]; then
		log_warning 'final: comparison skipped; boot or final snapshot is missing'
		return 0
	fi
	# The pinned mem-report reads text/JSON, not gzip streams.
	gzip -dc "$output/boot.txt.gz" > "$work/boot.txt" &&
		gzip -dc "$output/final.txt.gz" > "$work/final.txt" &&
		mem-report "$work/boot.txt" "$work/final.txt" \
			--mode cmp --labels boot final -o "$output/report.html" \
			--metrics-label "job=$CI_JOB_NAME" \
			--metrics "$output/metrics.prom" --summary "$output/summary.json" ||
		log_warning 'final: comparison failed'
	return 0
}

main "$@" || log_warning 'unexpected hook failure'
exit 0
