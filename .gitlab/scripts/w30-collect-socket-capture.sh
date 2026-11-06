#!/bin/sh
set -u
status=0
ssh "root@$TARGET_LAN_IP" /usr/sbin/w30-socket-capture stop || status=$?
echo "capture_stop_exit=$status" > "socket-trace-$LABGRID_TARGET.status"
ssh "root@$TARGET_LAN_IP" 'tar -czf - -C /var/log w30-socket-trace' \
    > "socket-trace-$LABGRID_TARGET.tar.gz" || status=$?
echo "capture_collect_exit=$status" >> "socket-trace-$LABGRID_TARGET.status"
exit "$status"
