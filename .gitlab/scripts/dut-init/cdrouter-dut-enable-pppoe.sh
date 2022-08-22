#!/bin/bash

ssh root@$TARGET_LAN_IP "ubus -t 60 wait_for PPP"
ssh root@$TARGET_LAN_IP "ubus -t 60 wait_for DHCPv4"
ssh root@$TARGET_LAN_IP "ubus -t 60 wait_for IP"
sleep 30
ssh root@$TARGET_LAN_IP "ubus call DHCPv4.Client.1 _set '{\"parameters\":{\"Enable\":0}}'"
ssh root@$TARGET_LAN_IP "ubus call PPP.Interface.1 _set '{\"parameters\":{\"Enable\":1}}'"
ssh root@$TARGET_LAN_IP "ubus call IP.Interface.2 _set '{\"parameters\":{\"LowerLayers\":\"Device.PPP.Interface.1.\"}}'"
ssh root@$TARGET_LAN_IP "ubus call IP.Interface.2.IPv4Address.1 _set '{\"parameters\":{\"AddressingType\":\"IPCP\"}}'"
ssh root@$TARGET_LAN_IP "ubus call PPP.Interface.1.IPCP _get"
