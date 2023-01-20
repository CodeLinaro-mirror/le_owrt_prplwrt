#!/bin/bash

ssh "root@$TARGET_LAN_IP" "ubus -t 200 wait_for DHCPv4.Client.1"
ssh "root@$TARGET_LAN_IP" "ubus -t 200 wait_for NAT.InterfaceSetting.1"
ssh "root@$TARGET_LAN_IP" "ubus -t 200 wait_for DSLite.InterfaceSetting.2"

ssh "root@$TARGET_LAN_IP" "iptables -P FORWARD ACCEPT"
ssh "root@$TARGET_LAN_IP" "ubus -S call DHCPv4.Client.1 _set '{\"parameters\":{\"Enable\":0}}'"
ssh "root@$TARGET_LAN_IP" "ubus -S call NAT.InterfaceSetting.1 _set '{\"parameters\":{\"Enable\":0}}'"
ssh "root@$TARGET_LAN_IP" "ubus -S call DSLite _set '{\"parameters\":{\"Enable\":1}}'"
ssh "root@$TARGET_LAN_IP" "\
	ubus call DSLite.InterfaceSetting.2 _set \
	'{\"parameters\":{ \
		\"EndpointAddressTypePrecedence\":\"FQDN\", \
		\"EndpointName\":\"aftr.prplfoundation.org\", \
		\"Enable\":1} \
	}' \
"
ssh "root@$TARGET_LAN_IP" "ubus call DSLite _get '{\"depth\":2}'"
ssh "root@$TARGET_LAN_IP" "iptables -L FORWARD | grep Chain"
