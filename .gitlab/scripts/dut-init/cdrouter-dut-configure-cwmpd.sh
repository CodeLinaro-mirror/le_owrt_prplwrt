#!/bin/bash

ssh "root@$TARGET_LAN_IP" "ubus -t 200 wait_for ManagementServer"
ssh "root@$TARGET_LAN_IP" "ba-cli 'ManagementServer.X_PRPLWARE-COM_FreqConnectionRequest=60'"
ssh "root@$TARGET_LAN_IP" "ba-cli 'ManagementServer.X_PRPLWARE-COM_MaxConnectionRequest=10000'"
