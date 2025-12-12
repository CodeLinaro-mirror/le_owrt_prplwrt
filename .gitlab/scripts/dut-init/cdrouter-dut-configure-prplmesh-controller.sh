#!/bin/bash

ssh "root@$TARGET_LAN_IP" "( /etc/init.d/prplmesh setmode --mode Multi-AP-Controller-and-Agent ; sleep 2 ) > /tmp/prplmesh-gw-mode.log 2>&1 ; logger -t prplmesh-gateway-mode < /tmp/prplmesh-gw-mode.log"
