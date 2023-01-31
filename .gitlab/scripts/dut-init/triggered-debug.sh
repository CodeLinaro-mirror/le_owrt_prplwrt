#!/bin/bash

#copy dumper script 
scp .gitlab/scripts/luadumper.lua root@${TARGET_LAN_IP}:/tmp/
ssh root@$TARGET_LAN_IP 'chmod a+x /tmp/luadumper.lua'

#add a dns probe
ssh root@$TARGET_LAN_IP "exec <&- >&- 2>&- ; while true; do sh -c \"date; nslookup www.google.com; nslookup acs-download.qacafe.com \" >> /etc/tmpnslookups 2>&1;  sleep 2;  done &" 

#set a process to take getdebug when PPP is established 
ssh root@$TARGET_LAN_IP 'exec <&- >&- 2>&- ; (while [ "$(ubus call PPP.Interface.1 _get | jsonfilter -e @[*].ConnectionStatus)" !=  "Connected" ] ; do sleep 10; done ; sleep 10; cp /var/etc/dnsmasq.conf.* /etc/ ; /bin/getDebugInformation -n -w -p -m -l -o - > /etc/debug_triggered.txt; /tmp/luadumper.lua  >>/etc/debug_triggered.txt;  ) &'
