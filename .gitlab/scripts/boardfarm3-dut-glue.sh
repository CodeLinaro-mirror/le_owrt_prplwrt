#!/bin/bash
# SPDX-FileCopyrightText: 2026 prpl Foundation
# SPDX-License-Identifier: GPL-2.0-only
#
# The steps of the labgrid DUT lifecycle that are prplOS CI policy and do
# not control the board, for a boardfarm3 job. The boardfarm3 tests run
# them from a session fixture, while the board is up:
#
#   ready     after the boot: the DUT system information and the DUT init
#             scripts (.dut-lifecycle.ready, .testbed), then the start
#             marker of the tests
#   finished  the end marker of the tests
#   collect   the logs of the DUT (.dut-lifecycle.collect-logs and
#             .dut-lifecycle.extract-debug), without the power-off: the
#             boardfarm3 device powers the board off at the end of the
#             session
#
# The commands are those of .gitlab/dut-lifecycle.yml and .gitlab/testbed.yml.

set -e

source "${CI_PROJECT_DIR}/.gitlab/scripts/helpers.sh"

ready() {
	ssh-keyscan $TARGET_LAN_IP >> ~/.ssh/known_hosts 2> /dev/null
	if [ -n "${DUT_OBUSPA_VERBOSE_LEVEL:-}" ] ||
	   [ -n "${DUT_OBUSPA_PROTOCOL_TRACE:-}" ]; then
		.gitlab/scripts/dut-init/dut-configure-obuspa-logging.sh;
	fi
	ssh root@$TARGET_LAN_IP 'logger -t CI -p local0.info "System accessible over SSH, $(uptime -p)"' || true
	ssh root@$TARGET_LAN_IP "cat /var/log/messages" > syslog-$LABGRID_TARGET.txt 2> /dev/null || true
	ssh root@$TARGET_LAN_IP "ubus call system board" | tee system-$LABGRID_TARGET.json
	.gitlab/scripts/memory-footprint.sh boot || true

	for dut_init_script in $DUT_INIT_SCRIPTS; do
		echo "Running $dut_init_script"; "${CI_PROJECT_DIR}/$dut_init_script";
	done

	ssh root@$TARGET_LAN_IP 'f=$(logread | grep "procd.*init complete"); echo "${f:-Warning: init is not complete yet,} $(uptime -p)"'
	ssh root@$TARGET_LAN_IP 'logger -t CI -p local0.info "Testing starts, $(uptime -p)"'
}

finished() {
	ssh root@$TARGET_LAN_IP 'logger -t CI -p local0.info "Testing finished, $(uptime -p)"'
}

collect() {
	.gitlab/scripts/memory-footprint.sh final || true
	ssh root@$TARGET_LAN_IP exit && {
		ssh root@$TARGET_LAN_IP ps > processes-$LABGRID_TARGET.txt
		ssh root@$TARGET_LAN_IP dmesg > dmesg-$LABGRID_TARGET.txt
		ssh root@$TARGET_LAN_IP "cat /var/log/messages" > syslog-$LABGRID_TARGET.txt
		ssh root@$TARGET_LAN_IP opkg list > opkg_list-$LABGRID_TARGET.txt
		script --quiet --command "ssh -t root@$TARGET_LAN_IP /bin/getDebugInformation --all"
		scp -O -r root@${TARGET_LAN_IP}:/tmp/debug-*_all.tar.gz . > /dev/null
		scp -O -r root@${TARGET_LAN_IP}:/etc etc > /dev/null
		scp -O -r root@${TARGET_LAN_IP}:/var/log/prplmesh prplmesh_beerocks_logs > /dev/null
	} || true

	tar xzf debug-*_all.tar.gz || true
	mv debug-*.txt debug-information-$LABGRID_TARGET.txt || true
	( [ $(tar -tf coredumps_all.tar.gz | wc -l) -eq 0 ] && rm coredumps_all.tar.gz || true ) 2>/dev/null
	mv coredumps_all.tar.gz coredumps-$LABGRID_TARGET.tar.gz 2> /dev/null || true
}

case "${1:-}" in
	ready|finished|collect) "$1" ;;
	*) echo "usage: $0 ready|finished|collect" >&2; exit 2 ;;
esac
