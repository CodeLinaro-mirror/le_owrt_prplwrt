#!/bin/bash

ssh "root@$TARGET_LAN_IP" "ubus -t 200 wait_for DHCPv6Client RouterAdvertisement"
ssh "root@$TARGET_LAN_IP" "ba-cli 'DHCPv6Client.Client.wan.RequestAddresses=1'"
ssh "root@$TARGET_LAN_IP" "ba-cli 'RouterAdvertisement.InterfaceSetting.lan.AdvManagedFlag=1'"

# DNS.Client.Server entries from the QA Cafe prpl certification guide,
# needed by prplos.1.4.2 - prplos.1.4.4
ssh "root@$TARGET_LAN_IP" "ubus -t 200 wait_for DNS.Client"
ssh "root@$TARGET_LAN_IP" "ba-cli 'DNS.Client.Server.+{Alias=\"dhcpv4-1\", Type=\"DHCPv4\", Enable=true, Interface=\"Device.Logical.Interface.1\"}'"
ssh "root@$TARGET_LAN_IP" "ba-cli 'DNS.Client.Server.+{Alias=\"dhcpv6-1\", Type=\"DHCPv6\", Enable=true, Interface=\"Device.Logical.Interface.1\"}'"
ssh "root@$TARGET_LAN_IP" "ba-cli 'DNS.Client.Server.+{Alias=\"ra-1\", Type=\"RouterAdvertisement\", Enable=true, Interface=\"Device.Logical.Interface.1\"}'"
ssh "root@$TARGET_LAN_IP" "ba-cli 'DNS.Client.Server.?'"
