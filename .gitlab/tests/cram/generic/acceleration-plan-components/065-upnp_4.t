Allowed values for NewInternalPort parameter of AddPortMapping and AddAnyPortMapping actions (UPNPIGD_0041)

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

Add port mapping with InternalPort=0 with AddPortMapping:

  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/AddPortMapping NewRemoteHost=1.1.1.1 NewExternalPort=12345 NewProtocol=TCP NewInternalPort=0 NewInternalClient=$CLIENT_IP NewEnabled=1 NewPortMappingDescription="UPnP-Test" NewLeaseDuration=0 2>&1 | sed -n 's/.*upnp error: \([0-9]\+\) (.*/\1/p'
  732

Add port mapping with InternalPort=1 with AddPortMapping:

  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/AddPortMapping NewRemoteHost=1.1.1.1 NewExternalPort=12345 NewProtocol=TCP NewInternalPort=1 NewInternalClient=$CLIENT_IP NewEnabled=1 NewPortMappingDescription="UPnP-Test" NewLeaseDuration=0 2>&1 | sed -n 's/.*upnp error: \([0-9]\+\) (.*/\1/p'
  606

Add port mapping with InternalPort=1023 with AddPortMapping:

  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/AddPortMapping NewRemoteHost=1.1.1.1 NewExternalPort=12345 NewProtocol=TCP NewInternalPort=1023 NewInternalClient=$CLIENT_IP NewEnabled=1 NewPortMappingDescription="UPnP-Test" NewLeaseDuration=0 2>&1 | sed -n 's/.*upnp error: \([0-9]\+\) (.*/\1/p'
  606

Add port mapping with InternalPort=12345 with AddPortMapping:

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

Clean up:

  $ upnp-client call-action $DESC_URL WANIPConn1/DeletePortMapping NewRemoteHost=1.1.1.1 NewExternalPort=23456 NewProtocol=TCP >/dev/null

Add port mapping with InternalPort=0 with AddAnyPortMapping:

  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/AddAnyPortMapping NewRemoteHost=1.1.1.1 NewExternalPort=12345 NewProtocol=TCP NewInternalPort=0 NewInternalClient=$CLIENT_IP NewEnabled=1 NewPortMappingDescription="UPnP-Test" NewLeaseDuration=0 2>&1 | sed -n 's/.*upnp error: \([0-9]\+\) (.*/\1/p'
  732

Add port mapping with InternalPort=1 with AddAnyPortMapping:

  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/AddAnyPortMapping NewRemoteHost=1.1.1.1 NewExternalPort=12345 NewProtocol=TCP NewInternalPort=1 NewInternalClient=$CLIENT_IP NewEnabled=1 NewPortMappingDescription="UPnP-Test" NewLeaseDuration=0 2>&1 | sed -n 's/.*upnp error: \([0-9]\+\) (.*/\1/p'
  606

Add port mapping with InternalPort=1023 with AddAnyPortMapping:

  $ upnp-client --pprint call-action $DESC_URL WANIPConn1/AddAnyPortMapping NewRemoteHost=1.1.1.1 NewExternalPort=12345 NewProtocol=TCP NewInternalPort=1023 NewInternalClient=$CLIENT_IP NewEnabled=1 NewPortMappingDescription="UPnP-Test" NewLeaseDuration=0 2>&1 | sed -n 's/.*upnp error: \([0-9]\+\) (.*/\1/p'
  606

Add port mapping with InternalPort=12345 with AddAnyPortMapping:

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

Clean up:

  $ upnp-client call-action $DESC_URL WANIPConn1/DeletePortMapping NewRemoteHost=1.1.1.1 NewExternalPort=23456 NewProtocol=TCP >/dev/null



