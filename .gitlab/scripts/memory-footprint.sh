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
			mv "$work/snapshot.txt.gz" "$output/$phase.txt.gz" ||
				log_warning "$phase: could not save snapshot"
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
	if ! mkdir -p "$output"; then
		log_warning "$phase: could not create $output"
		return 0
	fi
	# after_script uses a new shell: retain runtime TEST_PACKAGE/COMPONENT.
	if [ "$phase" = boot ]; then
		suite=${TEST_PACKAGE:-${COMPONENT:-auto}}
		printf '%s\n' "$suite" > "$output/suite" ||
			log_warning 'could not save suite identity'
	elif ! suite=$(cat "$output/suite" 2>/dev/null); then
		log_warning 'final: missing boot suite identity; suite label and registry operations skipped'
		suite=''
	fi
	# Clear previous output if this phase is retried in the same workspace.
	if ! rm -f "$output/$phase.txt.gz" "$output/report.html" \
		"$output/metrics.prom" "$output/widget.prom" "$output/summary.json"; then
		log_warning "$phase: could not clear previous output"
		return 0
	fi
	if ! work=$(mktemp -d "$output/.$phase.XXXXXX"); then
		log_warning "$phase: could not create temporary directory"
		return 0
	fi
	trap 'rm -rf "$work" || log_warning "could not remove temporary directory $work"' 0
	collect_snapshot
	if [ "$phase" = final ]; then
		if [ -f "$output/boot.txt.gz" ] && [ -f "$output/final.txt.gz" ]; then
			# The pinned mem-report reads text/JSON, not gzip streams.
			if ! gzip -dc "$output/boot.txt.gz" > "$work/boot.txt" ||
				! gzip -dc "$output/final.txt.gz" > "$work/final.txt"; then
				log_warning 'final: could not decompress snapshots for comparison'
				return 0
			fi
			set -- "$work/boot.txt" "$work/final.txt" \
				--mode cmp --labels boot final -o "$output/report.html" \
				--metrics "$output/metrics.prom" --summary "$output/summary.json"
			report_help=$(mem-report --help 2>/dev/null)
			if [ -n "$suite" ]; then
				if printf '%s\n' "$report_help" | grep -q -- '--metrics-label'; then
					set -- "$@" --metrics-label "suite=$suite"
				else
					log_warning 'mem-report lacks --metrics-label; upgrade the container'
				fi
			fi
			if printf '%s\n' "$report_help" | grep -q -- '--widget-metrics'; then
				set -- "$@" --widget-metrics "$output/widget.prom"
			else
				log_warning 'mem-report lacks --widget-metrics; widget unavailable'
			fi
			if ! mem-report "$@"; then
				log_warning 'final: mem-report failed; weekly upload skipped'
				return 0
			fi
			if [ -n "$suite" ]; then
				case "${CI_COMMIT_BRANCH:-}" in
					ci-weekly/*)
						timeout 120 python3 .gitlab/scripts/memory-footprint-registry.py \
							push "$output" "$board" "$suite" ||
							log_warning 'final: weekly baseline upload failed' ;;
				esac
			fi
		else
			log_warning 'final: comparison skipped; boot or final snapshot is missing'
		fi
	fi
	return 0
}

main "$@" || log_warning 'unexpected hook failure'
exit 0
