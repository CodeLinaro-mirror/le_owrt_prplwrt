#!/bin/bash

ssh "root@$TARGET_LAN_IP" "( /etc/init.d/prplmesh stop ; sleep 2 )  2>&1 > /dev/null"

ssh "root@$TARGET_LAN_IP" "( /etc/init.d/prplmesh gateway_mode ; sleep 2 ) > /tmp/prplmesh-gw-mode.log 2>&1 ; logger -t prplmesh-gateway-mode < /tmp/prplmesh-gw-mode.log"
