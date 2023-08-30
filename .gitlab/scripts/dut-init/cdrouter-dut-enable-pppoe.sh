#!/bin/bash

ssh root@$TARGET_LAN_IP "ubus -t 200 wait_for X_PRPL-COM_WANManager"
ssh root@$TARGET_LAN_IP "ubus-cli X_PRPL-COM_WANManager.WAN.Ethernet_PPP.Intf.1.Type=\"untagged\""
ssh root@$TARGET_LAN_IP "ubus call X_PRPL-COM_WANManager setWANMode '{ \"WANMode\": \"Ethernet_PPP\" }'"
