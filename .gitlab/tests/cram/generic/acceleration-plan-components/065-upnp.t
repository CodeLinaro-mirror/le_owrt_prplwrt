Install upnp-client:

$ pip install async-upnp-client

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

upnp-client definitions:

  $ export SCHEMA_DEVICE_IGDv2='urn:schemas-upnp-org:device:InternetGatewayDevice:2'
  $ export SCHEMA_DEVICE_WANDEVv2="urn:schemas-upnp-org:device:WANDevice:2"
  $ export SCHEMA_DEVICE_WANCONNDEVv2="urn:schemas-upnp-org:device:WANConnectionDevice:2"
  $ export SCHEMA_SERVICE_WANIPCONNv2="urn:schemas-upnp-org:service:WANIPConnection:2"
  $ export SCHEMA_SERVICE_WANPPPCONNv1="urn:schemas-upnp-org:service:WANPPPConnection:1"
  $ export XMLPATH_WANDEVv2="/root/device[deviceType='$SCHEMA_DEVICE_IGDv2']/deviceList/device[deviceType='$SCHEMA_DEVICE_WANDEVv2']"
  $ export XMLPATH_WANCONNDEVv2="$XMLPATH_WANDEVv2/deviceList/device[deviceType='$SCHEMA_DEVICE_WANCONNDEVv2']"

  $ export CLIENT_IP="$(ip -4 route get "192.168.1.1" 2>/dev/null | sed -n 's/.* src \([0-9.]*\).*/\1/p')"

  $ disc_igd_desc() { upnp-client search --target 192.168.1.1 | jq "select(.ST==\"$SCHEMA_DEVICE_IGDv2\")" | jq -rs ".[0].LOCATION"; }
  $ igd_get_obj() { curl -s $1 | sed 's/xmlns="urn:schemas-upnp-org:device-1-0"//' | xmllint --xpath "$2" - | xmllint --format -; }
  $ igd_get_prop() { curl -s $1 | sed 's/xmlns="urn:schemas-upnp-org:device-1-0"//' | xmllint --xpath "$2/text()" -; }

Verify UPnP IGD is present in the network:

  $ upnp-client search --target 192.168.1.1 | jq -r '.ST' | grep urn | uniq
  urn:schemas-upnp-org:device:InternetGatewayDevice:2
  urn:schemas-upnp-org:device:WANConnectionDevice:2
  urn:schemas-upnp-org:device:WANDevice:2
  urn:schemas-upnp-org:service:WANIPConnection:2
  urn:schemas-upnp-org:service:DeviceProtection:1
  urn:schemas-upnp-org:service:WANIPv6FirewallControl:1
  urn:schemas-upnp-org:service:WANCommonInterfaceConfig:1
  urn:schemas-upnp-org:service:Layer3Forwarding:1

Ged Description URL:

  $ export DESC_URL=$(disc_igd_desc)

Check that tr181-upnp is enabled and running by default:

  $ R "pgrep --count tr181-upnp"
  1

Check that miniupnpd is enabled and running by default:

  $ R "pgrep --count miniupnpd"
  1

  $ R "ubus -S call UPnP.Device _get '{\"rel_path\":\"UPnPIGD\"}'"
  {"UPnP.Device.":{"UPnPIGD":true}}
  {}
  {"amxd-error-code":0}

  $ R "netstat -tulpn 2>&1 | grep miniupnpd | grep tcp"
  tcp        0      0 :::5000                 :::\*                    LISTEN      .*\/miniupnpd (re)

  $ R "netstat -tulpn 2>&1 | grep miniupnpd | grep \:1900 | sort"
  udp        0      0 0.0.0.0:1900            0.0.0.0:\*                           .*\/miniupnpd (re)
  udp        0      0 :::1900                 :::\*                                .*\/miniupnpd (re)

  $ R "netstat -tulpn 2>&1 | grep miniupnpd | grep \:5351"
  udp        0      0 192.168.1.1:5351        0.0.0.0:\*                           .*\/miniupnpd (re)
  udp        0      0 :::5351                 :::\*                                .*\/miniupnpd (re)

Disable miniupnpd:

  $ R "ubus -S call UPnP.Device _set '{\"parameters\":{\"UPnPIGD\":False}}'" ; sleep 2
  {"UPnP.Device.":{"UPnPIGD":false}}
  {}
  {"amxd-error-code":0}

Check that miniupnpd is disabled and not running:

  $ R "pgrep --count miniupnpd"
  0
  [1]

  $ R "ubus -S call UPnP.Device _get '{\"rel_path\":\"UPnPIGD\"}'"
  {"UPnP.Device.":{"UPnPIGD":false}}
  {}
  {"amxd-error-code":0}

  $ R "netstat -tulpn | grep miniupnpd"
  [1]

Enable miniupnpd:

  $ R "ubus -S call UPnP.Device _set '{\"parameters\":{\"UPnPIGD\":True}}'" ; sleep 3
  {"UPnP.Device.":{"UPnPIGD":true}}
  {}
  {"amxd-error-code":0}

Check that miniupnpd is enabled and running again:

  $ R "pgrep --count miniupnpd"
  1

  $ R "ubus -S call UPnP.Device _get '{\"rel_path\":\"UPnPIGD\"}'"
  {"UPnP.Device.":{"UPnPIGD":true}}
  {}
  {"amxd-error-code":0}

  $ R "netstat -tulpn 2>&1 | grep miniupnpd | grep tcp"
  tcp        0      0 :::5000                 :::\*                    LISTEN      .*\/miniupnpd (re)

  $ R "netstat -tulpn 2>&1 | grep miniupnpd | grep \:1900 | sort"
  udp        0      0 0.0.0.0:1900            0.0.0.0:\*                           .*\/miniupnpd (re)
  udp        0      0 :::1900                 :::\*                                .*\/miniupnpd (re)

  $ R "netstat -tulpn 2>&1 | grep miniupnpd | grep \:5351"
  udp        0      0 192.168.1.1:5351        0.0.0.0:\*                           .*\/miniupnpd (re)
  udp        0      0 :::5351                 :::\*                                .*\/miniupnpd (re)

Check that it is possible to setup WANAccessProvider option over bus

  $ R "ba-cli 'UPnP.X_PRPLWARE-COM_IGDConfig.WANAccessProvider=\"test_provider\"'" >/dev/null
  $ R "ba-cli -l 'UPnP.X_PRPLWARE-COM_IGDConfig.WANAccessProvider?'" | awk 'NF'
  test_provider


Index continuity for NAT rules (UPNPIGD_0036)

Check there are no NAT PortMapping rules

  $ R "ba-cli 'Device.NAT.PortMapping.?'" | grep -v '^>'
  No data found
  

Create NAT PortMapping rules

  $ R "ba-cli 'Device.NAT.PortMapping.+{Alias=testrule1,Enable=1,Interface=Device.IP.Interface.2,Origin=UPnP,RemoteHost=1.1.1.1,ExternalPort=12345,InternalPort=12345,InternalClient=192.168.1.123}'" | grep -v '^>' | sed -E 's/\.PortMapping\.[0-9]+\./.PortMapping.X./'
  Device.NAT.PortMapping.X.
  Device.NAT.PortMapping.X.Alias="testrule1"
  Device.NAT.PortMapping.X.ExternalPort=12345
  Device.NAT.PortMapping.X.Protocol="TCP"
  Device.NAT.PortMapping.X.RemoteHost="1.1.1.1"
  

  $ R "ba-cli 'Device.NAT.PortMapping.+{Alias=testrule2,Enable=1,Interface=Device.IP.Interface.2,Origin=UPnP,RemoteHost=1.1.1.1,ExternalPort=23456,InternalPort=23456,InternalClient=192.168.1.123}'" | grep -v '^>' | sed -E 's/\.PortMapping\.[0-9]+\./.PortMapping.X./'
  Device.NAT.PortMapping.X.
  Device.NAT.PortMapping.X.Alias="testrule2"
  Device.NAT.PortMapping.X.ExternalPort=23456
  Device.NAT.PortMapping.X.Protocol="TCP"
  Device.NAT.PortMapping.X.RemoteHost="1.1.1.1"
  

  $ R "ba-cli 'Device.NAT.PortMapping.+{Alias=testrule3,Enable=1,Interface=Device.IP.Interface.2,Origin=UPnP,RemoteHost=1.1.1.1,ExternalPort=34567,InternalPort=34567,InternalClient=192.168.1.123}'" | grep -v '^>' | sed -E 's/\.PortMapping\.[0-9]+\./.PortMapping.X./'
  Device.NAT.PortMapping.X.
  Device.NAT.PortMapping.X.Alias="testrule3"
  Device.NAT.PortMapping.X.ExternalPort=34567
  Device.NAT.PortMapping.X.Protocol="TCP"
  Device.NAT.PortMapping.X.RemoteHost="1.1.1.1"
  

  $ R "ba-cli 'Device.NAT.PortMapping.+{Alias=testrule4,Enable=1,Interface=Device.IP.Interface.2,Origin=Controller,RemoteHost=1.1.1.1,ExternalPort=45678,InternalPort=45678,InternalClient=192.168.1.123}'" | grep -v '^>' | sed -E 's/\.PortMapping\.[0-9]+\./.PortMapping.X./'
  Device.NAT.PortMapping.X.
  Device.NAT.PortMapping.X.Alias="testrule4"
  Device.NAT.PortMapping.X.ExternalPort=45678
  Device.NAT.PortMapping.X.Protocol="TCP"
  Device.NAT.PortMapping.X.RemoteHost="1.1.1.1"
  

Delete the second NAT PortMapping rules:

  $ R "ba-cli 'Device.NAT.PortMapping.testrule2.-'" | grep -v '^>' |  sed -E 's/\.PortMapping\.[0-9]+\./.PortMapping.X./'
  Device.NAT.PortMapping.X.
  

Rtrieve NAT PortMapping with index 0:

  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/GetGenericPortMappingEntry NewPortMappingIndex=0 | jq 'del(.timestamp, .service_id, .service_type)'
  {
    "action": "GetGenericPortMappingEntry",
    "in_parameters": {
      "NewPortMappingIndex": 0
    },
    "out_parameters": {
      "NewRemoteHost": "1.1.1.1",
      "NewExternalPort": 12345,
      "NewProtocol": "TCP",
      "NewInternalPort": 12345,
      "NewInternalClient": "192.168.1.123",
      "NewEnabled": true,
      "NewPortMappingDescription": "",
      "NewLeaseDuration": 0
    }
  }

Rtrieve NAT PortMapping with index 1:

  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/GetGenericPortMappingEntry NewPortMappingIndex=1 | jq 'del(.timestamp, .service_id, .service_type)'
  {
    "action": "GetGenericPortMappingEntry",
    "in_parameters": {
      "NewPortMappingIndex": 1
    },
    "out_parameters": {
      "NewRemoteHost": "1.1.1.1",
      "NewExternalPort": 34567,
      "NewProtocol": "TCP",
      "NewInternalPort": 34567,
      "NewInternalClient": "192.168.1.123",
      "NewEnabled": true,
      "NewPortMappingDescription": "",
      "NewLeaseDuration": 0
    }
  }

Retrieve NAT PortMapping with index 2

  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/GetGenericPortMappingEntry NewPortMappingIndex=2 2>/dev/null
  [1]

Retrieve NAT PortMapping with index 3

  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/GetGenericPortMappingEntry NewPortMappingIndex=3 2>/dev/null
  [1]

Clean up:

  $ R "ba-cli 'Device.NAT.PortMapping.testrule1.-'" | grep -v '^>' |  sed -E 's/\.PortMapping\.[0-9]+\./.PortMapping.X./'
  Device.NAT.PortMapping.X.
  

  $ R "ba-cli 'Device.NAT.PortMapping.testrule3.-'" | grep -v '^>' |  sed -E 's/\.PortMapping\.[0-9]+\./.PortMapping.X./'
  Device.NAT.PortMapping.X.
  

  $ R "ba-cli 'Device.NAT.PortMapping.testrule4.-'" | grep -v '^>' |  sed -E 's/\.PortMapping\.[0-9]+\./.PortMapping.X./'
  Device.NAT.PortMapping.X.
  


GetGenericPortMappingEntry action (UPNPIGD_0038)

Check there are no NAT PortMapping rules:

  $ R "ba-cli 'Device.NAT.PortMapping.?'" | grep -v '^>'
  No data found
  

Create 1 NAT PortMapping rule with non-UPnP origin

  $ R "ba-cli 'Device.NAT.PortMapping.+{Alias=testrule1,Enable=1,Interface=Device.IP.Interface.2,Origin=Controller,RemoteHost=1.1.1.1,ExternalPort=12345,InternalPort=12345,InternalClient=192.168.1.123}'" | grep -v '^>' | sed -E 's/\.PortMapping\.[0-9]+\./.PortMapping.X./'
  Device.NAT.PortMapping.X.
  Device.NAT.PortMapping.X.Alias="testrule1"
  Device.NAT.PortMapping.X.ExternalPort=12345
  Device.NAT.PortMapping.X.Protocol="TCP"
  Device.NAT.PortMapping.X.RemoteHost="1.1.1.1"
  

Retrieve NAT PortMapping with index 0:

  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/GetGenericPortMappingEntry NewPortMappingIndex=0 2>/dev/null
  [1]

Add port mapping:

  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/AddPortMapping NewRemoteHost=2.2.2.2 NewExternalPort=23456 NewProtocol=TCP NewInternalPort=23456 NewInternalClient=$CLIENT_IP NewEnabled=1 NewPortMappingDescription="UPnP-Test" NewLeaseDuration=0 | jq 'del(.timestamp, .service_id, .service_type, .in_parameters.NewInternalClient)'
  {
    "action": "AddPortMapping",
    "in_parameters": {
      "NewRemoteHost": "2.2.2.2",
      "NewExternalPort": 23456,
      "NewProtocol": "TCP",
      "NewInternalPort": 23456,
      "NewEnabled": true,
      "NewPortMappingDescription": "UPnP-Test",
      "NewLeaseDuration": 0
    },
    "out_parameters": {}
  }

Rtrieve NAT PortMapping with index 0:

  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/GetGenericPortMappingEntry NewPortMappingIndex=1 | jq 'del(.timestamp, .service_id, .service_type, .out_parameters.NewInternalClient)'
  {
    "action": "GetGenericPortMappingEntry",
    "in_parameters": {
      "NewPortMappingIndex": 1
    },
    "out_parameters": {
      "NewRemoteHost": "2.2.2.2",
      "NewExternalPort": 23456,
      "NewProtocol": "TCP",
      "NewInternalPort": 23456,
      "NewEnabled": true,
      "NewPortMappingDescription": "UPnP-Test",
      "NewLeaseDuration": 0
    }
  }

Clean up:

  $ R "ba-cli 'Device.NAT.PortMapping.testrule1.-'" | grep -v '^>' |  sed -E 's/\.PortMapping\.[0-9]+\./.PortMapping.X./'
  Device.NAT.PortMapping.X.
  

  $ upnp-client call-action $DESC_URL WANIPConn1/DeletePortMapping NewRemoteHost=2.2.2.2 NewExternalPort=23456 NewProtocol=TCP >/dev/null


Allowed values for NewRemoteHost parameter of AddPortMapping and AddAnyPortMapping action (UPNPIGD_0039)

Add port mapping with wildcard RemoteHost:

  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/AddPortMapping NewRemoteHost="" NewExternalPort=12345 NewProtocol=TCP NewInternalPort=12345 NewInternalClient=$CLIENT_IP NewEnabled=1 NewPortMappingDescription="UPnP-Test" NewLeaseDuration=0 | jq 'del(.timestamp, .service_id, .service_type, .in_parameters.NewInternalClient)'
  {
    "action": "AddPortMapping",
    "in_parameters": {
      "NewRemoteHost": "",
      "NewExternalPort": 12345,
      "NewProtocol": "TCP",
      "NewInternalPort": 12345,
      "NewEnabled": true,
      "NewPortMappingDescription": "UPnP-Test",
      "NewLeaseDuration": 0
    },
    "out_parameters": {}
  }

Add port mapping with RemoteHost as IP address:

  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/AddPortMapping NewRemoteHost=1.1.1.1 NewExternalPort=23456 NewProtocol=TCP NewInternalPort=23456 NewInternalClient=$CLIENT_IP NewEnabled=1 NewPortMappingDescription="UPnP-Test" NewLeaseDuration=0 | jq 'del(.timestamp, .service_id, .service_type, .in_parameters.NewInternalClient)'
  {
    "action": "AddPortMapping",
    "in_parameters": {
      "NewRemoteHost": "1.1.1.1",
      "NewExternalPort": 23456,
      "NewProtocol": "TCP",
      "NewInternalPort": 23456,
      "NewEnabled": true,
      "NewPortMappingDescription": "UPnP-Test",
      "NewLeaseDuration": 0
    },
    "out_parameters": {}
  }

Add port mapping with RemoteHost as hostname:

  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/AddPortMapping NewRemoteHost=example NewExternalPort=34567 NewProtocol=TCP NewInternalPort=34567 NewInternalClient=$CLIENT_IP NewEnabled=1 NewPortMappingDescription="UPnP-Test" NewLeaseDuration=0 2>&1 | sed -n 's/.*upnp error: \([0-9]\+\) (.*/\1/p'
  600

Clean up:

  $ upnp-client call-action $DESC_URL WANIPConn1/DeletePortMapping NewRemoteHost="" NewExternalPort=12345 NewProtocol=TCP >/dev/null

  $ upnp-client call-action $DESC_URL WANIPConn1/DeletePortMapping NewRemoteHost=1.1.1.1 NewExternalPort=23456 NewProtocol=TCP >/dev/null

Add port mapping with wildcard RemoteHost

  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/AddAnyPortMapping NewRemoteHost="" NewExternalPort=12345 NewProtocol=TCP NewInternalPort=12345 NewInternalClient=$CLIENT_IP NewEnabled=1 NewPortMappingDescription="UPnP-Test" NewLeaseDuration=0 | jq 'del(.timestamp, .service_id, .service_type, .in_parameters.NewInternalClient)'
  {
    "action": "AddAnyPortMapping",
    "in_parameters": {
      "NewRemoteHost": "",
      "NewExternalPort": 12345,
      "NewProtocol": "TCP",
      "NewInternalPort": 12345,
      "NewEnabled": true,
      "NewPortMappingDescription": "UPnP-Test",
      "NewLeaseDuration": 0
    },
    "out_parameters": {
      "NewReservedPort": 12345
    }
  }

Add port mapping with RemoteHost as IP address

  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/AddAnyPortMapping NewRemoteHost=1.1.1.1 NewExternalPort=23456 NewProtocol=TCP NewInternalPort=23456 NewInternalClient=$CLIENT_IP NewEnabled=1 NewPortMappingDescription="UPnP-Test" NewLeaseDuration=0 | jq 'del(.timestamp, .service_id, .service_type, .in_parameters.NewInternalClient)'
  {
    "action": "AddAnyPortMapping",
    "in_parameters": {
      "NewRemoteHost": "1.1.1.1",
      "NewExternalPort": 23456,
      "NewProtocol": "TCP",
      "NewInternalPort": 23456,
      "NewEnabled": true,
      "NewPortMappingDescription": "UPnP-Test",
      "NewLeaseDuration": 0
    },
    "out_parameters": {
      "NewReservedPort": 23456
    }
  }

Add port mapping with RemoteHost as hostname

  $ upnp-client call-action $DESC_URL WANIPConn1/AddAnyPortMapping NewRemoteHost=example.com NewExternalPort=34567 NewProtocol=TCP NewInternalPort=34567 NewInternalClient=$CLEINT_IP NewEnabled=1 NewPortMappingDescription="UPnP-Test" NewLeaseDuration=0  2>&1 | sed -n 's/.*upnp error: \([0-9]\+\) (.*/\1/p'
  606

Clean up

  $ upnp-client call-action $DESC_URL WANIPConn1/DeletePortMapping NewRemoteHost="" NewExternalPort=12345 NewProtocol=TCP >/dev/null

  $ upnp-client call-action $DESC_URL WANIPConn1/DeletePortMapping NewRemoteHost=1.1.1.1 NewExternalPort=23456 NewProtocol=TCP >/dev/null


Allowed values for NewInternalPort parameter of AddPortMapping and AddAnyPortMapping actions (UPNPIGD_0041)

Add port mapping with InternalPort=0

  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/AddPortMapping NewRemoteHost=1.1.1.1 NewExternalPort=12345 NewProtocol=TCP NewInternalPort=0 NewInternalClient=$CLIENT_IP NewEnabled=1 NewPortMappingDescription="UPnP-Test" NewLeaseDuration=0 2>&1 | sed -n 's/.*upnp error: \([0-9]\+\) (.*/\1/p'
  732

Add port mapping with InternalPort=1

  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/AddPortMapping NewRemoteHost=1.1.1.1 NewExternalPort=12345 NewProtocol=TCP NewInternalPort=1 NewInternalClient=$CLIENT_IP NewEnabled=1 NewPortMappingDescription="UPnP-Test" NewLeaseDuration=0 2>&1 | sed -n 's/.*upnp error: \([0-9]\+\) (.*/\1/p'
  606

Add port mapping with InternalPort=1023
  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/AddPortMapping NewRemoteHost=1.1.1.1 NewExternalPort=12345 NewProtocol=TCP NewInternalPort=1023 NewInternalClient=$CLIENT_IP NewEnabled=1 NewPortMappingDescription="UPnP-Test" NewLeaseDuration=0 2>&1 | sed -n 's/.*upnp error: \([0-9]\+\) (.*/\1/p'
  606

Add port mapping with InternalPort=12345

  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/AddPortMapping NewRemoteHost=1.1.1.1 NewExternalPort=23456 NewProtocol=TCP NewInternalPort=12345 NewInternalClient=$CLIENT_IP NewEnabled=1 NewPortMappingDescription="UPnP-Test" NewLeaseDuration=0 | jq 'del(.timestamp, .service_id, .service_type, .in_parameters.NewInternalClient)'
  {
    "action": "AddPortMapping",
    "in_parameters": {
      "NewRemoteHost": "1.1.1.1",
      "NewExternalPort": 23456,
      "NewProtocol": "TCP",
      "NewInternalPort": 12345,
      "NewEnabled": true,
      "NewPortMappingDescription": "UPnP-Test",
      "NewLeaseDuration": 0
    },
    "out_parameters": {}
  }

Clean up

  $ upnp-client call-action $DESC_URL WANIPConn1/DeletePortMapping NewRemoteHost=1.1.1.1 NewExternalPort=23456 NewProtocol=TCP >/dev/null

Add port mapping with InternalPort=0

  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/AddAnyPortMapping NewRemoteHost=1.1.1.1 NewExternalPort=12345 NewProtocol=TCP NewInternalPort=0 NewInternalClient=$CLIENT_IP NewEnabled=1 NewPortMappingDescription="UPnP-Test" NewLeaseDuration=0 2>&1 | sed -n 's/.*upnp error: \([0-9]\+\) (.*/\1/p'
  732

Add port mapping with InternalPort=1
  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/AddAnyPortMapping NewRemoteHost=1.1.1.1 NewExternalPort=12345 NewProtocol=TCP NewInternalPort=1 NewInternalClient=$CLIENT_IP NewEnabled=1 NewPortMappingDescription="UPnP-Test" NewLeaseDuration=0 2>&1 | sed -n 's/.*upnp error: \([0-9]\+\) (.*/\1/p'
  606

Add port mapping with InternalPort=1023
  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/AddAnyPortMapping NewRemoteHost=1.1.1.1 NewExternalPort=12345 NewProtocol=TCP NewInternalPort=1023 NewInternalClient=$CLIENT_IP NewEnabled=1 NewPortMappingDescription="UPnP-Test" NewLeaseDuration=0 2>&1 | sed -n 's/.*upnp error: \([0-9]\+\) (.*/\1/p'
  606

Add port mapping with InternalPort=12345
  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/AddAnyPortMapping NewRemoteHost=1.1.1.1 NewExternalPort=23456 NewProtocol=TCP NewInternalPort=12345 NewInternalClient=$CLIENT_IP NewEnabled=1 NewPortMappingDescription="UPnP-Test" NewLeaseDuration=0 | jq 'del(.timestamp, .service_id, .service_type, .in_parameters.NewInternalClient)'
  {
    "action": "AddAnyPortMapping",
    "in_parameters": {
      "NewRemoteHost": "1.1.1.1",
      "NewExternalPort": 23456,
      "NewProtocol": "TCP",
      "NewInternalPort": 12345,
      "NewEnabled": true,
      "NewPortMappingDescription": "UPnP-Test",
      "NewLeaseDuration": 0
    },
    "out_parameters": {
      "NewReservedPort": 23456
    }
  }

Clean up

  $ upnp-client call-action $DESC_URL WANIPConn1/DeletePortMapping NewRemoteHost=1.1.1.1 NewExternalPort=23456 NewProtocol=TCP >/dev/null


Static NAT rules persistency (UPNPIGD_0050)

Add port mapping

  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/AddPortMapping NewRemoteHost=1.1.1.1 NewExternalPort=12345 NewProtocol=TCP NewInternalPort=12345 NewInternalClient=$CLIENT_IP NewEnabled=1 NewPortMappingDescription="UPnP-Test" NewLeaseDuration=0 | jq 'del(.timestamp, .service_id, .service_type, .in_parameters.NewInternalClient)'
  {
    "action": "AddPortMapping",
    "in_parameters": {
      "NewRemoteHost": "1.1.1.1",
      "NewExternalPort": 12345,
      "NewProtocol": "TCP",
      "NewInternalPort": 12345,
      "NewEnabled": true,
      "NewPortMappingDescription": "UPnP-Test",
      "NewLeaseDuration": 0
    },
    "out_parameters": {}
  }

Get the port mapping

  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/GetSpecificPortMappingEntry NewRemoteHost=1.1.1.1 NewExternalPort=12345 NewProtocol=TCP | jq 'del(.timestamp, .service_id, .service_type, .out_parameters.NewInternalClient)'
  {
    "action": "GetSpecificPortMappingEntry",
    "in_parameters": {
      "NewRemoteHost": "1.1.1.1",
      "NewExternalPort": 12345,
      "NewProtocol": "TCP"
    },
    "out_parameters": {
      "NewInternalPort": 12345,
      "NewEnabled": true,
      "NewPortMappingDescription": "UPnP-Test",
      "NewLeaseDuration": 0
    }
  }

Reboot DUT

  $ R "reboot"
  $ sleep 120

Get Description URL:

  $ export DESC_URL=$(disc_igd_desc)

Get the port mapping

  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/GetSpecificPortMappingEntry NewRemoteHost=1.1.1.1 NewExternalPort=12345 NewProtocol=TCP 2>&1 | sed -n 's/.*upnp error: \([0-9]\+\) (.*/\1/p'
  714

Add port mapping

  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/AddAnyPortMapping NewRemoteHost=1.1.1.1 NewExternalPort=12345 NewProtocol=TCP NewInternalPort=12345 NewInternalClient=$CLIENT_IP NewEnabled=1 NewPortMappingDescription="UPnP-Test" NewLeaseDuration=0 | jq 'del(.timestamp, .service_id, .service_type, .in_parameters.NewInternalClient)'
  {
    "action": "AddAnyPortMapping",
    "in_parameters": {
      "NewRemoteHost": "1.1.1.1",
      "NewExternalPort": 12345,
      "NewProtocol": "TCP",
      "NewInternalPort": 12345,
      "NewEnabled": true,
      "NewPortMappingDescription": "UPnP-Test",
      "NewLeaseDuration": 0
    },
    "out_parameters": {
      "NewReservedPort": 12345
    }
  }

Get the port mapping

  $ lease=$(upnp-client --pprint call-action $DESC_URL WANIPConn1/GetSpecificPortMappingEntry NewRemoteHost=1.1.1.1 NewExternalPort=12345 NewProtocol=TCP | jq -r '.out_parameters.NewLeaseDuration')
  $ [ "$lease" -gt 600000 ] && echo OK || echo FAIL
  OK

Clean up

  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/DeletePortMapping NewRemoteHost=1.1.1.1 NewExternalPort=12345 NewProtocol=TCP >/dev/null

