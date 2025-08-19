#!/bin/bash

ssh "root@$TARGET_LAN_IP" "ubus -t 200 wait_for DHCPv6Client RouterAdvertisement"
ssh "root@$TARGET_LAN_IP" "ba-cli 'DHCPv6Client.Client.wan.RequestAddresses=1'"
ssh "root@$TARGET_LAN_IP" "ba-cli 'RouterAdvertisement.InterfaceSetting.lan.AdvManagedFlag=1'"
