#!/bin/bash

source .gitlab/scripts/helpers.sh

set -eu         # exit on error and undefined variables
set -o pipefail # catch errors in pipes

# Start (default, as a DUT init script) or stop the DUT-side instruments of
# the EAPOL M3 hunt: the ath12k debug_mask for the EAPOL, PEER and MLME
# messages, and a bounded per-second loop that writes the station dump and
# hostapd's all_sta of the test BSS into /etc/ci-debugfs/loop.log, which the
# job collects with the rest of /etc. The DUT busybox has neither timeout nor
# nohup, so the loop is a plain background subshell with closed file
# descriptors.

action="${1:-start}"

case "$action" in
	start | stop) ;;
	*)
		log_error "Usage: $0 [start|stop]"
		exit 1
		;;
esac

log_info "DUT instruments: $action"

remote_script=$(
	cat <<'EOF'
set -eu

action="$1"
dbg="/sys/kernel/debug"
mask_file="/sys/module/ath12k/parameters/debug_mask"
mask="0x30020000" # EAPOL 0x20000000, MLME 0x10000000, PEER 0x00020000
ctl="$dbg/dynamic_debug/control"
dir="/etc/ci-debugfs"
log="$dir/loop.log"
pidfile="/var/run/ci-station-loop.pid"
bss="wlan2.1"

if [ "$action" = start ]; then
	mkdir -p "$dir"
	if [ -f "$mask_file" ]; then
		echo "$mask" > "$mask_file"
		echo "debug_mask now $(cat "$mask_file")"
	else
		echo "no $mask_file"
	fi
	if [ -w "$ctl" ]; then
		echo 'module ath12k func __ath12k_dbg +p' > "$ctl"
		echo "dynamic debug enabled for __ath12k_dbg"
	else
		echo "no writable $ctl: dev_dbg lines of the driver will not print"
	fi

	: > "$log"
	(
		n=0
		# at most 2100 iterations (35 minutes) and 12 MB
		while [ "$n" -lt 2100 ] && [ "$(wc -c < "$log")" -lt 12000000 ]; do
			echo "## $(date +%T) up $(cut -d' ' -f1 /proc/uptime)" >> "$log"
			iw dev "$bss" station dump >> "$log" 2>&1 || true
			hostapd_cli -p /var/run/hostapd -i "$bss" -l 0 all_sta >> "$log" 2>&1 || true
			sleep 1
			n=$((n + 1))
		done
	) < /dev/null > /dev/null 2>&1 &
	echo $! > "$pidfile"
	echo "station loop pid $(cat "$pidfile"), log $log"
	logger -t CI -p local0.info "DUT instruments started: debug_mask $mask, station loop"
else
	if [ -f "$pidfile" ]; then
		kill "$(cat "$pidfile")" 2> /dev/null || true
		rm -f "$pidfile"
		echo "station loop stopped, $(wc -c < "$log" 2> /dev/null || echo 0) bytes in $log"
	fi
	[ ! -w "$ctl" ] || echo 'module ath12k func __ath12k_dbg -p' > "$ctl"
	[ ! -f "$mask_file" ] || echo 0 > "$mask_file"
	echo "debug_mask now $(cat "$mask_file" 2> /dev/null || echo n/a)"
	logger -t CI -p local0.info "DUT instruments stopped"
fi
EOF
)

# shellcheck disable=SC2029
if ! ssh "root@$TARGET_LAN_IP" 'sh -s' "$action" <<< "$remote_script"; then
	log_error "Could not $action the DUT instruments"
	exit 1
fi

log_success "DUT instruments: $action done"
