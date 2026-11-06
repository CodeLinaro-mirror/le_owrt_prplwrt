#!/bin/sh
set -eu
ssh "root@$TARGET_LAN_IP" /usr/sbin/w30-socket-capture start
