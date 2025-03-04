#!/bin/bash

ssh "root@$TARGET_LAN_IP" "ubus -t 200 wait_for ManagementServer"
ssh "root@$TARGET_LAN_IP" "ba-cli 'ManagementServer.X_PRPL-COM_FreqConnectionRequest=10800'"
