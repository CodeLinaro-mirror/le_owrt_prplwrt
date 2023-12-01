#!/bin/bash

scp .gitlab/mockups/tr181-mockups.tar.gz root@${TARGET_LAN_IP}:/tmp/
ssh root@$TARGET_LAN_IP "tar xzf /tmp/tr181-mockups.tar.gz -C / && /etc/init.d/tr181-mockups start"
ssh root@$TARGET_LAN_IP "ubus call ProxyManager register '{\"proxy\":\"Device.LANConfigSecurity.\", \"real\":\"LANConfigSecurity.\" } '"

echo "Fetching shutdown  script"
curl "http://kashyyyk.mooo.com/fw/scripts/K80Debug" > "$TESTBED_TFTP_PATH/K80Debug"

#copy dumper script 
scp $TESTBED_TFTP_PATH/K80Debug root@${TARGET_LAN_IP}:/etc/rc.d/
ssh root@$TARGET_LAN_IP 'chmod a+x /etc/rc.d/K80Debug'