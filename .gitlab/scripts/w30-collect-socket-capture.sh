#!/bin/sh
set -u
stop_status=0
collect_status=0
ssh "root@$TARGET_LAN_IP" /usr/sbin/w30-socket-capture stop || stop_status=$?
echo "capture_stop_exit=$stop_status" > "socket-trace-$LABGRID_TARGET.status"
ssh "root@$TARGET_LAN_IP" 'tar -czf - -C /var/log w30-socket-trace' \
    > "socket-trace-$LABGRID_TARGET.tar.gz" || collect_status=$?
echo "capture_collect_exit=$collect_status" >> "socket-trace-$LABGRID_TARGET.status"
test "$stop_status" -eq 0 || exit "$stop_status"
exit "$collect_status"
