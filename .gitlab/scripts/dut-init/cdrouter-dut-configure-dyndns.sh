#!/bin/bash

ssh "root@$TARGET_LAN_IP" "sed -i 's/CHECK_SECONDS=300/CHECK_SECONDS=30/g' /usr/lib/ddns/dynamic_dns_updater.sh"
ssh "root@$TARGET_LAN_IP" "ubus -t 200 wait_for DynamicDNS.Client"

ssh "root@$TARGET_LAN_IP" "ba-cli 'DynamicDNS.Server.[Name==\"uci_dyndns.org\"].CheckInterval=60'"

# Get server index from name because path search is not possible while adding a paramater
# "DynamicDNS.Server.[Name=='uci_dyndns.org']." -> "DynamicDNS.Server.9."
dnsServerPath="$(ssh "root@$TARGET_LAN_IP" "ba-cli \"DynamicDNS.Server.[Name=='uci_dyndns.org'].?\" | grep -v \"^>\" | head -1")"
ssh "root@$TARGET_LAN_IP" "\
	ba-cli 'DynamicDNS.Client.+{ \
		\"Alias\"=\"cdrouter\", \
		\"Server\"=\"${dnsServerPath}\", \
		\"Interface\"=\"Device.IP.Interface.2.\", \
		\"Username\"=\"qacafe\", \
		\"Password\"=\"qacafe123\", \
		\"Enable\"=1}' \
"
ssh "root@$TARGET_LAN_IP" "\
	ba-cli 'DynamicDNS.Client.[Alias==\"cdrouter\"].Hostname.+{ \
		\"Name\"=\"cpe01.prplOS.prplfoundation.org\", \
		\"Enable\"=1}' \
"
ssh "root@$TARGET_LAN_IP" "ba-cli 'DynamicDNS.Client.[Alias==\"cdrouter\"].?2'"
