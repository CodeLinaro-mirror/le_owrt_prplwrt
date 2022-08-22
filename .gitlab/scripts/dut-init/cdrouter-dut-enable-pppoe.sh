#!/bin/bash

ssh root@$TARGET_LAN_IP "ubus -t 60 wait_for PPP"
ssh root@$TARGET_LAN_IP "ubus -t 60 wait_for DHCPv4"
ssh root@$TARGET_LAN_IP "ubus-cli DHCPv4.Client.1.Enable=0"
ssh root@$TARGET_LAN_IP "ubus-cli PPP.Interface.1.Enable=1"
ssh root@$TARGET_LAN_IP "ubus-cli IP.Interface.2.LowerLayers=Device.PPP.Interface.1."
ssh root@$TARGET_LAN_IP "ubus-cli IP.Interface.2.IPv4Address.1.AddressingType=IPCP"
