Index continuity for NAT rules (UPNPIGD_0036)

Install upnp-client (Installing via Dockerfile does not work):

  $ pip install async-upnp-client >/dev/null 2>&1
  $ export PATH="$PATH:$HOME/.local/bin"

Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

upnp-client definitions:

  $ export SCHEMA_DEVICE_IGDv2='urn:schemas-upnp-org:device:InternetGatewayDevice:2'
  $ export CLIENT_IP="$(ip -4 route get "192.168.1.1" 2>/dev/null | sed -n 's/.* src \([0-9.]*\).*/\1/p')"
  $ disc_igd_desc() { upnp-client search --target 192.168.1.1 | jq "select(.ST==\"$SCHEMA_DEVICE_IGDv2\")" | jq -rs ".[0].LOCATION"; }

Allow Reserved WAN IP Addresses:

  $ R "ba-cli 'Device.UPnP.X_PRPLWARE-COM_IGDConfig.AllowReservedAddr=1'" | grep -v '^>'
  Device.UPnP.X_PRPLWARE-COM_IGDConfig.
  Device.UPnP.X_PRPLWARE-COM_IGDConfig.AllowReservedAddr=1
  
  $ sleep 3

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

Check there are no NAT PortMapping rules:

  $ R "ba-cli 'Device.NAT.PortMapping.?'" | grep -v '^>'
  No data found
  

Create NAT PortMapping rules:

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

Retrieve NAT PortMapping with index 2:

  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/GetGenericPortMappingEntry NewPortMappingIndex=2 2>/dev/null
  [1]

Retrieve NAT PortMapping with index 3:

  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/GetGenericPortMappingEntry NewPortMappingIndex=3 2>/dev/null
  [1]

Clean up:

  $ R "ba-cli 'Device.NAT.PortMapping.testrule1.-'" | grep -v '^>' |  sed -E 's/\.PortMapping\.[0-9]+\./.PortMapping.X./'
  Device.NAT.PortMapping.X.
  

  $ R "ba-cli 'Device.NAT.PortMapping.testrule3.-'" | grep -v '^>' |  sed -E 's/\.PortMapping\.[0-9]+\./.PortMapping.X./'
  Device.NAT.PortMapping.X.
  

  $ R "ba-cli 'Device.NAT.PortMapping.testrule4.-'" | grep -v '^>' |  sed -E 's/\.PortMapping\.[0-9]+\./.PortMapping.X./'
  Device.NAT.PortMapping.X.
  
