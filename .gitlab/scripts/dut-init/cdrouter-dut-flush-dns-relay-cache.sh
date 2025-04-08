#!/bin/bash

ssh "root@$TARGET_LAN_IP" "ubus -t 180 wait_for DNS.Relay.Config.1"
ssh "root@$TARGET_LAN_IP" "ba-cli 'DNS.Relay.Config.[Alias==\"lan\"].FlushCache()'"
