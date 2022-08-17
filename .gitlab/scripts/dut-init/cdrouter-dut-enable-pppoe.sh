#!/bin/bash

ssh root@$TARGET_LAN_IP "ubus -t 60 wait_for PPP"
ssh root@$TARGET_LAN_IP "ubus -t 60 wait_for DHCPv4"
ssh root@$TARGET_LAN_IP "ubus-cli DHCPv4.Client.1.Enable=0"
ssh root@$TARGET_LAN_IP "ubus call PPP.Interface.1 _set '{\"parameters\":{\"Enable\":1}}'"
