#!/bin/bash

#copy dumper script 
scp .gitlab/scripts/luadumper.lua root@${TARGET_LAN_IP}:/tmp/
ssh root@$TARGET_LAN_IP 'chmod a+x /tmp/luadumper.lua'

#add a dns probe
ssh root@$TARGET_LAN_IP "exec <&- >&- 2>&- ; while true; do sh -c \"date; nslookup acs-download.qacafe.com \" >> /etc/tmpnslookup 2>&1;  sleep 2;  done &" 

#set a process to take getdebug when PPP is established 
ssh root@$TARGET_LAN_IP 'exec <&- >&- 2>&- ; (while [ "$(ubus call PPP.Interface.1 _get | jsonfilter -e @[*].ConnectionStatus)" !=  "Connected" ] ; do sleep 10; done ; sleep 10; /bin/getDebugInformation -n -w -p -m -l -o - > /etc/debug_triggered.txt; /tmp/luadumper.lua  >>/etc/debug_triggered.txt ) &'
