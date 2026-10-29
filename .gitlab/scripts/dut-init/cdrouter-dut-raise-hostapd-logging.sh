#!/bin/bash

source .gitlab/scripts/helpers.sh

set -eu         # exit on error and undefined variables
set -o pipefail # catch errors in pipes

# Raise the syslog level of the running hostapd to "debug" for every BSS, so
# that the 4-way handshake lines (EAPOL-Key 2/4 received, 3/4 sent, timeout)
# reach /var/log/messages, and keep logrotate from cutting that file during
# the tests. hostapd's default logger_syslog_level is "info", pwhm does not
# write the key and the daemon arguments cannot set it, but the control
# interface accepts every config key per BSS. The level lives in the running
# process only, so this must run after the wireless configuration.

log_info "Raising hostapd syslog level to debug and the logrotate size for messages"

remote_script=$(
	cat <<'EOF'
set -eu

test_bss="wlan2.1"
sock_dir="/var/run/hostapd"
hcli="hostapd_cli -p $sock_dir"

# One file per syslog destination: messages is the one the job collects
for f in /etc/logrotate.d/syslog-messages.conf /etc/logrotate.d/syslog-hostapd.conf; do
	sed -i "s/maxsize 3M/maxsize 64M/" "$f"
	grep -H maxsize "$f"
	grep -q "maxsize 64M" "$f"
done

# The state line of the test BSS, from the plain or the MLD link form of status
enabled_state() {
	for link in "" "-l 0"; do
		# shellcheck disable=SC2086
		state=$($hcli -i "$test_bss" $link status 2> /dev/null | sed -n "/^state=/{p;q}")
		if [ "$state" = "state=ENABLED" ]; then
			echo "$state"
			return 0
		fi
	done
	return 1
}

i=0
until enabled_state > /dev/null; do
	i=$((i + 1))
	if [ "$i" -gt 60 ]; then
		echo "$test_bss is not ENABLED after 60 s"
		exit 1
	fi
	sleep 1
done
enabled_state

# Every control socket, plain and with the MLD link ids 0 to 2
apply_level() {
	n_ok=0
	n_test_bss=0
	for sock in "$sock_dir"/wlan*; do
		[ -S "$sock" ] || continue
		ifname="${sock##*/}"
		for link in "" "-l 0" "-l 1" "-l 2"; do
			# shellcheck disable=SC2086
			reply=$($hcli -i "$ifname" $link set logger_syslog_level 1 2>&1 | tail -n 1)
			echo "set logger_syslog_level 1 on $ifname ${link:-plain}: $reply"
			if [ "$reply" = "OK" ]; then
				n_ok=$((n_ok + 1))
				if [ "$ifname" = "$test_bss" ]; then
					n_test_bss=$((n_test_bss + 1))
				fi
			fi
		done
	done
	echo "logger_syslog_level 1: $n_ok replies OK, $n_test_bss of them on $test_bss"
	[ "$n_test_bss" -gt 0 ]
}

apply_level
# A second pass, in case the wireless FSM restarted hostapd in between
sleep 3
apply_level

logger -t CI -p local0.info "hostapd logger_syslog_level 1 accepted $n_ok times, logrotate maxsize 64M"
EOF
)

if ! ssh "root@$TARGET_LAN_IP" 'sh -s' <<< "$remote_script"; then
	log_error "Could not raise hostapd logging on the DUT"
	exit 1
fi

log_success "hostapd syslog level is debug and logrotate keeps messages up to 64M"
