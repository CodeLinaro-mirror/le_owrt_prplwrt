#!/bin/bash

ssh "root@$TARGET_LAN_IP" "ubus -t 200 wait_for WiFi.AccessPoint.2"
ssh "root@$TARGET_LAN_IP" "ubus -S call WiFi.AccessPoint.2 _set '{\"parameters\":{\"Enable\":1}}'"
