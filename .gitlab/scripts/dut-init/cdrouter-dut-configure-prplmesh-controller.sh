#!/bin/bash

ssh "root@$TARGET_LAN_IP" "ba-cli X_PRPLWARE-COM_ProcessManager.PrplMesh.ManagementMode=Multi-AP-Controller-and-Agent"
ssh "root@$TARGET_LAN_IP" "ba-cli X_PRPLWARE-COM_ProcessManager.PrplMesh.Enable=1"
