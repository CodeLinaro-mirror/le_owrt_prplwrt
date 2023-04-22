#!/bin/bash

ssh "root@$TARGET_LAN_IP" "ubus -t 200 wait_for WiFi.AccessPoint.1"
ssh "root@$TARGET_LAN_IP" "ubus -S call WiFi.AccessPoint.1 _set '{\"parameters\":{\"Enable\":1}}'"
