#!/bin/bash

ssh root@$TARGET_LAN_IP "ubus -t 60 wait_for Ethernet.VLANTermination"
ssh root@$TARGET_LAN_IP "ubus call Ethernet.VLANTermination _add '{\"parameters\":{\"Alias\":\"vlanWan\", \"Name\":\"vlan_wan\", \"LowerLayers\":\"$DUT_TR181_WAN_INTERFACE\", \"VLANID\":100, \"Enable\":1}}'"
ssh root@$TARGET_LAN_IP "ubus call Ethernet.VLANTermination _add '{\"parameters\":{\"Alias\":\"vlanLan\", \"Name\":\"vlan_lan\", \"LowerLayers\":\"$DUT_TR181_LAN_INTERFACE\", \"VLANID\":200, \"Enable\":1}}'"
