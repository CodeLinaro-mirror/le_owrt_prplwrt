#!/bin/bash
scp .gitlab/scripts/dut-init/obuspa_param_reset-mqtt.txt root@${TARGET_LAN_IP}:/etc/config/obuspa_param_reset.txt
ssh root@$TARGET_LAN_IP "rm /etc/obuspa.db"
ssh root@$TARGET_LAN_IP "service obuspa restart"
