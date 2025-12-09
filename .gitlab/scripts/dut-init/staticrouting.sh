#!/bin/sh

ssh -o StrictHostKeyChecking=no root@192.168.1.1 "ip route replace 172.16.5.0/24 via 192.168.1.150"

if [ $? -ne 0 ]; then
	echo "Failed to set static route on DUT."
	exit 1
else
	echo "Static route set on DUT for LAN."
fi

ssh -o StrictHostKeyChecking=no root@192.168.1.1 "ip route replace 7.1.1.0/24 via 80.81.82.83"

if [ $? -ne 0 ]; then
	echo "Failed to set static route on DUT."
	exit 1
else
	echo "Static route set on DUT for WAN."
fi
