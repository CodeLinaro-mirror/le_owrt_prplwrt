#!/bin/bash

ssh root@$TARGET_LAN_IP "ubus -t 200 wait_for PPP"
ssh root@$TARGET_LAN_IP "ubus -t 200 wait_for DHCPv4"
ssh root@$TARGET_LAN_IP "ubus -t 200 wait_for IP"
ssh root@$TARGET_LAN_IP "ubus call DHCPv4.Client.1 _set '{\"parameters\":{\"Enable\":0}}'"
ssh root@$TARGET_LAN_IP "ubus call PPP.Interface.1 _set '{\"parameters\":{\"Enable\":1}}'"
ssh root@$TARGET_LAN_IP "ubus call IP.Interface.2 _set '{\"parameters\":{\"LowerLayers\":\"Device.PPP.Interface.1.\"}}'"
ssh root@$TARGET_LAN_IP "ubus call IP.Interface.2.IPv4Address.1 _set '{\"parameters\":{\"AddressingType\":\"IPCP\"}}'"

#add a dns monitor
ssh root@$TARGET_LAN_IP "exec <&- >&- 2>&- ; while true; do sh -c \"date; nslookup acs-download.qacafe.com \">> /etc/tmpnslookup;  sleep 10;  done &" 

#set a process to take getdebug when PPP is established 
ssh root@$TARGET_LAN_IP "exec <&- >&- 2>&- ; (while [ \"\$(ubus call PPP.Interface.1 _get | jsonfilter -e @[*].ConnectionStatus)\" !=  \"Connected\" ] ; do sleep 10; done   sleep 10; /bin/getDebugInformation -a;  cp /tmp/debug_all.tar.gz /etc/) &"