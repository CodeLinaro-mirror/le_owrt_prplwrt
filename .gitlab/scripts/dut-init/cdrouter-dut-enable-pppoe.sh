#!/bin/bash

ssh root@$TARGET_LAN_IP "ubus -t 60 wait_for PPP"
ssh root@$TARGET_LAN_IP "ubus -t 60 wait_for DHCPv4"
ssh root@$TARGET_LAN_IP "ubus -t 60 wait_for IP"
sleep 15
ssh root@$TARGET_LAN_IP "ubus call DHCPv4.Client.1 _set '{\"parameters\":{\"Enable\":0}}'"
ssh root@$TARGET_LAN_IP "ubus call PPP.Interface.1 _set '{\"parameters\":{\"Enable\":1}}'"
ssh root@$TARGET_LAN_IP "ubus call IP.Interface.2 _set '{\"parameters\":{\"LowerLayers\":\"Device.PPP.Interface.1.\"}}'"
ssh root@$TARGET_LAN_IP "ubus call IP.Interface.2.IPv4Address.1 _set '{\"parameters\":{\"AddressingType\":\"IPCP\"}}'"
sleep 10
ssh root@$TARGET_LAN_IP "ubus call IP.Interface.2 _get"
ssh root@$TARGET_LAN_IP "ubus call PPP.Interface.1 _get"

ssh root@$TARGET_LAN_IP "ubus call DNS.Client.Server _add '{\"parameters\":{\"Alias\":\"ppp\",\"Enable\":\"1\",\"DNSServer\":\"202.254.101.1\",\"Interface\":\"Device.IP.Interface.2.\",\"Type\":\"Static\"}}'"
sleep 5
ssh root@$TARGET_LAN_IP "ubus call PPP.Interface.1 _set '{\"parameters\":{\"Enable\":0}}'"
ssh root@$TARGET_LAN_IP "ubus call PPP.Interface.1 _set '{\"parameters\":{\"Enable\":1}}'"
sleep 5
ssh root@$TARGET_LAN_IP "ubus call PPP.Interface.1 _get"
