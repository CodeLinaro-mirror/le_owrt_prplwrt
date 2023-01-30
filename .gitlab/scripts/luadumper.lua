#!/usr/bin/env lua

-- Ensure lamx.so can be imported from /usr/local/lib
package.cpath = "/usr/local/lib/lua/" .. (_VERSION):gsub("Lua ", "") .. "/?.so;" .. package.cpath
local lamx = require 'lamx'
lamx.auto_connect("protected")

local components = {"ACLManager.","Bridging.","Cthulhu.","DHCPv4.","DHCPv6.","DNS.","DNSSD.","DSLite.","Device.","DeviceInfo.","Devices.","DynamicDNS.","Ethernet.","Firewall.","Hosts.","IP.","Logical.","ManagementServer.","NAT.","NeighborDiscovery.","NetDev.","NetModel.","PCP.","PPP.","PacketInterception.","ProxyManager.","QoS.","Rlyeh.","RouterAdvertisement.","Routing.","SSH.","SoftwareModules.","Time.","Timingila.","UPnP.","UserInterface.","Users.","WiFi.","XPON.","X_PRPL-COM_MultiSettings.","X_PRPL-COM_PersistentConfiguration.","X_PRPL-COM_WANAutoSensing.","X_PRPL-COM_WANManager."}

for i,component in pairs(components) do
	local data = lamx.bus.get(component) 

	for object,params in pairs(data) do
		for name, value in pairs(params) do
			print(tostring(object) .. tostring(name) .. " = " .. tostring(value))
		end
	end

end
lamx.disconnect_all()