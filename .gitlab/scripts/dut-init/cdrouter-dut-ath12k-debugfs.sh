#!/bin/bash

source .gitlab/scripts/helpers.sh

set -eu         # exit on error and undefined variables
set -o pipefail # catch errors in pipes

# Dump the ath12k TX completion, drop and station counters of the DUT from
# debugfs into /etc/ci-debugfs/<phase>, which the job collects with the rest
# of /etc. "before" (the default, as a DUT init script) first zeroes the
# counters so that the "after" dump, run once the tests are over, holds the
# counts of the test run only.

phase="${1:-before}"

case "$phase" in
	before | after) ;;
	*)
		log_error "Usage: $0 [before|after]"
		exit 1
		;;
esac

log_info "Dumping ath12k debugfs counters ($phase)"

remote_script=$(
	cat <<'EOF'
set -eu

phase="$1"
dbg="/sys/kernel/debug"
out="/etc/ci-debugfs/$phase"

if [ ! -d "$dbg/ieee80211" ]; then
	mount -t debugfs none "$dbg" 2> /dev/null || true
fi
[ -d "$dbg/ieee80211" ] || {
	echo "no $dbg/ieee80211 on the DUT"
	exit 1
}

rm -rf "$out"
mkdir -p "$out"

if [ "$phase" = before ]; then
	for f in $(find "$dbg/ieee80211" "$dbg/ath12k" -type f \( -name reset_dp_stats -o -name reset_tx_stats -o -name reset_rx_stats -o -name reset_dp_tid_stats -o -name htt_stats_reset -o -name htt_peer_stats_reset \) 2> /dev/null); do
		echo 1 > "$f" 2> /dev/null && echo "reset ${f#$dbg/}" || echo "reset failed ${f#$dbg/}"
	done
fi

dump() {
	# $1 = debugfs file, $2 = output name suffix
	name="$(echo "${1#$dbg/}" | tr '/' '_')$2"
	timeout 10 cat "$1" 2> /dev/null | head -c 200000 > "$out/$name" || true
}

for f in $(find "$dbg/ieee80211" "$dbg/ath12k" -type f \( -name device_dp_stats -o -name dump_mgmt_stats -o -name fw_reset_stats -o -name vdev_stats -o -name link_stats -o -name mld_stats -o -name pdev_stats -o -name device_mon_stats -o -name htt_peer_stats -o -name tx_stats -o -name rx_stats \) 2> /dev/null); do
	dump "$f" ""
done

# htt_stats: write the stats type, then read; types 1 PDEV_TX, 3 TX_HWQ,
# 4 TX_SCHED, 5 PDEV_ERROR, 6 TQM, 8 TX_DE_INFO, 12 TX_SELFGEN_INFO
for f in $(find "$dbg/ieee80211" "$dbg/ath12k" -type f -name htt_stats_type 2> /dev/null); do
	d="${f%/*}"
	[ -f "$d/htt_stats" ] || continue
	for t in 1 3 4 5 6 8 12; do
		echo "$t" > "$f" 2> /dev/null || continue
		dump "$d/htt_stats" "_type$t"
	done
done

echo "dumped $(ls "$out" | wc -l) files into $out"
ls "$out" | sed 's/^/  /'
logger -t CI -p local0.info "ath12k debugfs dump ($phase) written to $out"
EOF
)

# shellcheck disable=SC2029
if ! ssh "root@$TARGET_LAN_IP" 'sh -s' "$phase" <<< "$remote_script"; then
	log_error "Could not dump the ath12k debugfs counters ($phase)"
	exit 1
fi

log_success "ath12k debugfs counters ($phase) are in /etc/ci-debugfs/$phase"
