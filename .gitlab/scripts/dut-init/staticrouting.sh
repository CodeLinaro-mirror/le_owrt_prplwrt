#!/bin/sh

ssh -o StrictHostKeyChecking=no root@192.168.1.1 "ubus-cli Routing.Router.1.IPv4Forwarding.+{DestIPAddress=\"172.16.5.0\",DestSubnetMask=\"255.255.255.0\",Enable=1,GatewayIPAddress=\"192.168.1.150\", Interface=\"Device.IP.Interface.3\"}"

if [ $? -ne 0 ]; then
	echo "Failed to set static route on DUT for LAN."
	exit 1
else
	echo "Static route set on DUT for LAN."
fi

ssh -o StrictHostKeyChecking=no root@192.168.1.1 "ubus-cli NAT.InterfaceSetting.1.SourceNetwork=\"\""
ssh -o StrictHostKeyChecking=no root@192.168.1.1 "ubus-cli Firewall.InterfaceSetting.3.IPv4SpoofingProtection=0"

#ssh -o StrictHostKeyChecking=no root@192.168.1.1 "ip route replace 7.1.1.0/24 via 80.81.82.83"
#
#if [ $? -ne 0 ]; then
#	echo "Failed to set static route on DUT for WAN."
#	exit 1
#else
#	echo "Static route set on DUT for WAN."
#fi
