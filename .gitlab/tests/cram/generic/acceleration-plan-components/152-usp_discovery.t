Test skipped due to usp-discovery being available only on the extender-full profile
  $ exit 80

Setup the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

# Sub-option 30 (unassigned)                      = "0"
  $ DHCP4_OPTION_125_EMPTY="00000DE9031E0130"

# Sub-option 25 (URL or FQDN of the Controller)   = "ws://controller.cdroutertest.com:8080/ws/agent"
# Sub-option 26 (Provisioning code)               = "abc"
# Sub-option 27 (USP retry minimum wait interval) = "100"
# Sub-option 28 (USP retry interval multiplier)   = "1234"
# Sub-option 29 (Endpoint ID of the Controller)   = "cdrouterTestController"
  $ DHCP4_OPTION_125_WS="00000DE958192E77733A2F2F636F6E74726F6C6C65722E6364726F75746572746573742E636F6D3A383038302F77732F6167656E741A036162631B033130301C04313233341D166364726F7574657254657374436F6E74726F6C6C6572"

# Sub-option 25 (URL or FQDN of the Controller)   = "wss://controller.cdroutertest.com:8080/ws/agent"
# Sub-option 26 (Provisioning code)               = "abc"
# Sub-option 27 (USP retry minimum wait interval) = "100"
# Sub-option 28 (USP retry interval multiplier)   = "1234"
# Sub-option 29 (Endpoint ID of the Controller)   = "cdrouterTestController"
  $ DHCP4_OPTION_125_WS_ENCRYPTED="00000DE959192F7773733A2F2F636F6E74726F6C6C65722E6364726F75746572746573742E636F6D3A383038302F77732F6167656E741A036162631B033130301C04313233341D166364726F7574657254657374436F6E74726F6C6C6572"

# Sub-option 25 (URL or FQDN of the Controller)   = "ws://controller.cdroutertest.com:8080/ws/agent"
# Sub-option 26 (Provisioning code)               = "abc"
# Sub-option 27 (USP retry minimum wait interval) = "100"
# Sub-option 28 (USP retry interval multiplier)   = "1234"
# Sub-option 29 (Endpoint ID of the Controller)   = "cdrouterTestControllerNEW"
  $ DHCP4_OPTION_125_WS_SECOND="00000DE95B192E77733A2F2F636F6E74726F6C6C65722E6364726F75746572746573742E636F6D3A383038302F77732F6167656E741A036162631B033130301C04313233341D196364726F7574657254657374436F6E74726F6C6C65724E4557"

# Sub-option 25 (URL or FQDN of the Controller)   = "mqtt://controller.cdroutertest.com"
# Sub-option 29 (Endpoint ID of the Controller)   = "cdrouterTestControllerNEW"
  $ DHCP4_OPTION_125_MQTT="00000DE93C19226D7174743A2F2F636F6E74726F6C6C65722E6364726F75746572746573742E636F6D1D166364726F7574657254657374436F6E74726F6C6C6572"

# Sub-option 25 (URL or FQDN of the Controller)   = "stomp://controller.cdroutertest.com"
# Sub-option 29 (Endpoint ID of the Controller)   = "cdrouterTestControllerNEW"
  $ DHCP4_OPTION_125_STOMP="00000DE940192373746F6D703A2F2F636F6E74726F6C6C65722E6364726F75746572746573742E636F6D1D196364726F7574657254657374436F6E74726F6C6C65724E4557"
  $ USP_DISCOVERY_ODL="/etc/amx/usp_discovery/usp_discovery.odl"
  $ USP_DISCOVERY_CONTROLLER_CONFIGURE_TIMEOUT="1"
  $ DHCP4_CLIENT_REF="DHCPv4Client.Client.wan."
  $ if R "grep 'NetModelIntfName = \"ip-lan\";' '${USP_DISCOVERY_ODL}'"; then DHCP4_CLIENT_REF="DHCPv4Client.Client.lan."; fi

Prepare DHCP request option-125:
  $ if [ -z $(R "ba-cli '${DHCP4_CLIENT_REF}.ReqOption.?'" | grep 'Tag=125') ]; then R "ba-cli '${DHCP4_CLIENT_REF}.ReqOption+ {Tag=125,Enable=1}'" > /dev/null; fi
  $ DHCP4_OPTION_125_REF=$(R "ba-cli '${DHCP4_CLIENT_REF}.ReqOption.[Tag==125].?' | awk 'NR==2'")

Prepare:
  $ R "/etc/init.d/usp_discovery stop"
  $ R "ba-cli '${DHCP4_OPTION_125_REF}.Value=\"${DHCP4_OPTION_125_EMPTY}\"'" > /dev/null
  $ R "obuspa -f /etc/obuspa.db -c verbose 0" > /dev/null
  $ R "/etc/init.d/usp_discovery start"

Check that no USP controller configured after boot:
  $ R "obuspa -f /etc/obuspa.db -c get Device. | grep usp_discovery_" | wc -l
  0

Check that USP controller is configured after option-125 has changed:
  $ R "ba-cli '${DHCP4_OPTION_125_REF}.Value=\"${DHCP4_OPTION_125_WS}\"'" > /dev/null
  $ R "sleep ${USP_DISCOVERY_CONTROLLER_CONFIGURE_TIMEOUT}"
  $ R "obuspa -f /etc/obuspa.db -c get Device.LocalAgent.Controller.[Alias==usp_discovery_cdrouterTestController]." | grep -v CurrentRetryCount | awk -F'Device.LocalAgent.Controller.[0-9]+.' '{print $2}'
  Alias => usp_discovery_cdrouterTestController
  Enable => true
  EndpointID => cdrouterTestController
  InheritedRole => 
  AssignedRole => 
  PeriodicNotifInterval => 86400
  PeriodicNotifTime => 0001-01-01T00:00:00Z
  USPNotifRetryMinimumWaitInterval => 100
  USPNotifRetryIntervalMultiplier => 1234
  ControllerCode => 
  ProvisioningCode => abc
  MTPNumberOfEntries => 1
  BootParameterNumberOfEntries => 0
  MTP.1.Alias => usp_discovery_cdrouterTestController
  MTP.1.Enable => true
  MTP.1.Protocol => WebSocket
  MTP.1.STOMP.Reference => 
  MTP.1.STOMP.Destination => 
  MTP.1.MQTT.Reference => 
  MTP.1.MQTT.Topic => 
  MTP.1.WebSocket.Host => controller.cdroutertest.com
  MTP.1.WebSocket.Port => 8080
  MTP.1.WebSocket.Path => /ws/agent
  MTP.1.WebSocket.EnableEncryption => false
  MTP.1.WebSocket.KeepAliveInterval => 30
  MTP.1.WebSocket.SessionRetryMinimumWaitInterval => 5
  MTP.1.WebSocket.SessionRetryIntervalMultiplier => 2000
  MTP.1.UDS.UnixDomainSocketRef => 
  MTP.1.UDS.USPServiceRef => 

Check that USP controller is updated after option-125 has changed:
  $ R "ba-cli '${DHCP4_OPTION_125_REF}.Value=\"${DHCP4_OPTION_125_WS_ENCRYPTED}\"'" > /dev/null
  $ R "sleep ${USP_DISCOVERY_CONTROLLER_CONFIGURE_TIMEOUT}"
  $ R "obuspa -f /etc/obuspa.db -c get Device.LocalAgent.Controller.[Alias==usp_discovery_cdrouterTestController]." | grep -v CurrentRetryCount | awk -F'Device.LocalAgent.Controller.[0-9]+.' '{print $2}'
  Alias => usp_discovery_cdrouterTestController
  Enable => true
  EndpointID => cdrouterTestController
  InheritedRole => 
  AssignedRole => 
  PeriodicNotifInterval => 86400
  PeriodicNotifTime => 0001-01-01T00:00:00Z
  USPNotifRetryMinimumWaitInterval => 100
  USPNotifRetryIntervalMultiplier => 1234
  ControllerCode => 
  ProvisioningCode => abc
  MTPNumberOfEntries => 1
  BootParameterNumberOfEntries => 0
  MTP.1.Alias => usp_discovery_cdrouterTestController
  MTP.1.Enable => true
  MTP.1.Protocol => WebSocket
  MTP.1.STOMP.Reference => 
  MTP.1.STOMP.Destination => 
  MTP.1.MQTT.Reference => 
  MTP.1.MQTT.Topic => 
  MTP.1.WebSocket.Host => controller.cdroutertest.com
  MTP.1.WebSocket.Port => 8080
  MTP.1.WebSocket.Path => /ws/agent
  MTP.1.WebSocket.EnableEncryption => true
  MTP.1.WebSocket.KeepAliveInterval => 30
  MTP.1.WebSocket.SessionRetryMinimumWaitInterval => 5
  MTP.1.WebSocket.SessionRetryIntervalMultiplier => 2000
  MTP.1.UDS.UnixDomainSocketRef => 
  MTP.1.UDS.USPServiceRef => 

Check that USP controller is removed when DHCP option does not configure USP controller:
  $ R "ba-cli '${DHCP4_OPTION_125_REF}.Value=\"${DHCP4_OPTION_125_EMPTY}\"'" > /dev/null
  $ R "sleep ${USP_DISCOVERY_CONTROLLER_CONFIGURE_TIMEOUT}"
  $ R "obuspa -f /etc/obuspa.db -c get Device. | grep usp_discovery_" | wc -l
  0

Check that USP controller is configured on boot:
  $ R "/etc/init.d/usp_discovery stop"
  $ R "ba-cli '${DHCP4_OPTION_125_REF}.Value=\"${DHCP4_OPTION_125_WS_ENCRYPTED}\"'" > /dev/null
  $ R "/etc/init.d/usp_discovery start"
  $ R "sleep ${USP_DISCOVERY_CONTROLLER_CONFIGURE_TIMEOUT}"
  $ R "obuspa -f /etc/obuspa.db -c get Device.LocalAgent.Controller.[Alias==usp_discovery_cdrouterTestController]." | grep -v CurrentRetryCount | awk -F'Device.LocalAgent.Controller.[0-9]+.' '{print $2}'
  Alias => usp_discovery_cdrouterTestController
  Enable => true
  EndpointID => cdrouterTestController
  InheritedRole => 
  AssignedRole => 
  PeriodicNotifInterval => 86400
  PeriodicNotifTime => 0001-01-01T00:00:00Z
  USPNotifRetryMinimumWaitInterval => 100
  USPNotifRetryIntervalMultiplier => 1234
  ControllerCode => 
  ProvisioningCode => abc
  MTPNumberOfEntries => 1
  BootParameterNumberOfEntries => 0
  MTP.1.Alias => usp_discovery_cdrouterTestController
  MTP.1.Enable => true
  MTP.1.Protocol => WebSocket
  MTP.1.STOMP.Reference => 
  MTP.1.STOMP.Destination => 
  MTP.1.MQTT.Reference => 
  MTP.1.MQTT.Topic => 
  MTP.1.WebSocket.Host => controller.cdroutertest.com
  MTP.1.WebSocket.Port => 8080
  MTP.1.WebSocket.Path => /ws/agent
  MTP.1.WebSocket.EnableEncryption => true
  MTP.1.WebSocket.KeepAliveInterval => 30
  MTP.1.WebSocket.SessionRetryMinimumWaitInterval => 5
  MTP.1.WebSocket.SessionRetryIntervalMultiplier => 2000
  MTP.1.UDS.UnixDomainSocketRef => 
  MTP.1.UDS.USPServiceRef => 

Check that USP controller is configured after restart of usp_discovery if option exists:
  $ R "/etc/init.d/usp_discovery stop"
  $ R "obuspa -f /etc/obuspa.db -c get Device. | grep usp_discovery_" | wc -l
  0
  $ R "/etc/init.d/usp_discovery start"
  $ R "sleep ${USP_DISCOVERY_CONTROLLER_CONFIGURE_TIMEOUT}"
  $ R "obuspa -f /etc/obuspa.db -c get Device.LocalAgent.Controller.[Alias==usp_discovery_cdrouterTestController]." | grep -v CurrentRetryCount | awk -F'Device.LocalAgent.Controller.[0-9]+.' '{print $2}'
  Alias => usp_discovery_cdrouterTestController
  Enable => true
  EndpointID => cdrouterTestController
  InheritedRole => 
  AssignedRole => 
  PeriodicNotifInterval => 86400
  PeriodicNotifTime => 0001-01-01T00:00:00Z
  USPNotifRetryMinimumWaitInterval => 100
  USPNotifRetryIntervalMultiplier => 1234
  ControllerCode => 
  ProvisioningCode => abc
  MTPNumberOfEntries => 1
  BootParameterNumberOfEntries => 0
  MTP.1.Alias => usp_discovery_cdrouterTestController
  MTP.1.Enable => true
  MTP.1.Protocol => WebSocket
  MTP.1.STOMP.Reference => 
  MTP.1.STOMP.Destination => 
  MTP.1.MQTT.Reference => 
  MTP.1.MQTT.Topic => 
  MTP.1.WebSocket.Host => controller.cdroutertest.com
  MTP.1.WebSocket.Port => 8080
  MTP.1.WebSocket.Path => /ws/agent
  MTP.1.WebSocket.EnableEncryption => true
  MTP.1.WebSocket.KeepAliveInterval => 30
  MTP.1.WebSocket.SessionRetryMinimumWaitInterval => 5
  MTP.1.WebSocket.SessionRetryIntervalMultiplier => 2000
  MTP.1.UDS.UnixDomainSocketRef => 
  MTP.1.UDS.USPServiceRef => 

Check that second USP controller is configured after option-125 updated with new EndpointID:
  $ R "ba-cli '${DHCP4_OPTION_125_REF}.Value=\"${DHCP4_OPTION_125_WS_SECOND}\"'" > /dev/null
  $ R "sleep ${USP_DISCOVERY_CONTROLLER_CONFIGURE_TIMEOUT}"
  $ R "obuspa -f /etc/obuspa.db -c get Device.LocalAgent.Controller.[Alias==usp_discovery_cdrouterTestController]." | grep -v CurrentRetryCount | awk -F'Device.LocalAgent.Controller.[0-9]+.' '{print $2}'
  Alias => usp_discovery_cdrouterTestController
  Enable => true
  EndpointID => cdrouterTestController
  InheritedRole => 
  AssignedRole => 
  PeriodicNotifInterval => 86400
  PeriodicNotifTime => 0001-01-01T00:00:00Z
  USPNotifRetryMinimumWaitInterval => 100
  USPNotifRetryIntervalMultiplier => 1234
  ControllerCode => 
  ProvisioningCode => abc
  MTPNumberOfEntries => 1
  BootParameterNumberOfEntries => 0
  MTP.1.Alias => usp_discovery_cdrouterTestController
  MTP.1.Enable => true
  MTP.1.Protocol => WebSocket
  MTP.1.STOMP.Reference => 
  MTP.1.STOMP.Destination => 
  MTP.1.MQTT.Reference => 
  MTP.1.MQTT.Topic => 
  MTP.1.WebSocket.Host => controller.cdroutertest.com
  MTP.1.WebSocket.Port => 8080
  MTP.1.WebSocket.Path => /ws/agent
  MTP.1.WebSocket.EnableEncryption => true
  MTP.1.WebSocket.KeepAliveInterval => 30
  MTP.1.WebSocket.SessionRetryMinimumWaitInterval => 5
  MTP.1.WebSocket.SessionRetryIntervalMultiplier => 2000
  MTP.1.UDS.UnixDomainSocketRef => 
  MTP.1.UDS.USPServiceRef => 
  $ R "obuspa -f /etc/obuspa.db -c get Device.LocalAgent.Controller.[Alias==usp_discovery_cdrouterTestControllerNEW]." | grep -v CurrentRetryCount | awk -F'Device.LocalAgent.Controller.[0-9]+.' '{print $2}'
  Alias => usp_discovery_cdrouterTestControllerNEW
  Enable => true
  EndpointID => cdrouterTestControllerNEW
  InheritedRole => 
  AssignedRole => 
  PeriodicNotifInterval => 86400
  PeriodicNotifTime => 0001-01-01T00:00:00Z
  USPNotifRetryMinimumWaitInterval => 100
  USPNotifRetryIntervalMultiplier => 1234
  ControllerCode => 
  ProvisioningCode => abc
  MTPNumberOfEntries => 1
  BootParameterNumberOfEntries => 0
  MTP.1.Alias => usp_discovery_cdrouterTestControllerNEW
  MTP.1.Enable => true
  MTP.1.Protocol => WebSocket
  MTP.1.STOMP.Reference => 
  MTP.1.STOMP.Destination => 
  MTP.1.MQTT.Reference => 
  MTP.1.MQTT.Topic => 
  MTP.1.WebSocket.Host => controller.cdroutertest.com
  MTP.1.WebSocket.Port => 8080
  MTP.1.WebSocket.Path => /ws/agent
  MTP.1.WebSocket.EnableEncryption => false
  MTP.1.WebSocket.KeepAliveInterval => 30
  MTP.1.WebSocket.SessionRetryMinimumWaitInterval => 5
  MTP.1.WebSocket.SessionRetryIntervalMultiplier => 2000
  MTP.1.UDS.UnixDomainSocketRef => 
  MTP.1.UDS.USPServiceRef => 

Check that USP controllers are removed on start of the usp_discovery:
  $ R "pkill -9 usp_discovery > /dev/null"
  $ R "ba-cli '${DHCP4_OPTION_125_REF}.Value=\"${DHCP4_OPTION_125_EMPTY}\"'" > /dev/null
  $ R "sed -i '/UseSingleControllerInstance = false;/c\\UseSingleControllerInstance = true;' ${USP_DISCOVERY_ODL}"
  $ R "/etc/init.d/usp_discovery start"
  $ R "sleep ${USP_DISCOVERY_CONTROLLER_CONFIGURE_TIMEOUT}"
  $ R "obuspa -f /etc/obuspa.db -c get Device. | grep usp_discovery_" | wc -l
  0

Check that USP controller is configured with 'UseSingleControllerInstance' enabled:
  $ R "ba-cli '${DHCP4_OPTION_125_REF}.Value=\"${DHCP4_OPTION_125_MQTT}\"'" > /dev/null
  $ R "sleep ${USP_DISCOVERY_CONTROLLER_CONFIGURE_TIMEOUT}"
  $ R "obuspa -f /etc/obuspa.db -c get Device.LocalAgent.Controller.[Alias==usp_discovery]." | grep -v CurrentRetryCount | awk -F'Device.LocalAgent.Controller.[0-9]+.' '{print $2}'
  Alias => usp_discovery
  Enable => true
  EndpointID => cdrouterTestController
  InheritedRole => 
  AssignedRole => 
  PeriodicNotifInterval => 86400
  PeriodicNotifTime => 0001-01-01T00:00:00Z
  USPNotifRetryMinimumWaitInterval => 5
  USPNotifRetryIntervalMultiplier => 2000
  ControllerCode => 
  ProvisioningCode => 
  MTPNumberOfEntries => 1
  BootParameterNumberOfEntries => 0
  MTP.1.Alias => usp_discovery
  MTP.1.Enable => true
  MTP.1.Protocol => MQTT
  MTP.1.STOMP.Reference => 
  MTP.1.STOMP.Destination => 
  MTP.1.MQTT.Reference => Device.MQTT.Client.1.
  MTP.1.MQTT.Topic => /usp/controller
  MTP.1.WebSocket.Host => 
  MTP.1.WebSocket.Port => 80
  MTP.1.WebSocket.Path => 
  MTP.1.WebSocket.EnableEncryption => true
  MTP.1.WebSocket.KeepAliveInterval => 30
  MTP.1.WebSocket.SessionRetryMinimumWaitInterval => 5
  MTP.1.WebSocket.SessionRetryIntervalMultiplier => 2000
  MTP.1.UDS.UnixDomainSocketRef => 
  MTP.1.UDS.USPServiceRef => 
  $ R "obuspa -f /etc/obuspa.db -c get Device.LocalAgent.MTP.[Alias==usp_discovery]." | awk -F'Device.LocalAgent.MTP.[0-9]+.' '{print $2}'
  Alias => usp_discovery
  Protocol => MQTT
  Enable => true
  Status => Down
  STOMP.Reference => 
  STOMP.Destination => 
  STOMP.DestinationFromServer => 
  MQTT.Reference => Device.MQTT.Client.1.
  MQTT.ResponseTopicConfigured => /usp/agent
  MQTT.ResponseTopicDiscovered => 
  MQTT.PublishQoS => 0
  WebSocket.Port => 5683
  WebSocket.Path => 
  WebSocket.EnableEncryption => true
  WebSocket.KeepAliveInterval => 30
  UDS.UnixDomainSocketRef => 
  $ R "obuspa -f /etc/obuspa.db -c get Device.MQTT.Client.[Alias==usp_discovery]." | awk -F'Device.MQTT.Client.[0-9]+.' '{print $2}'
  Alias => usp_discovery
  Enable => true
  BrokerAddress => controller.cdroutertest.com
  BrokerPort => 1883
  Username => 
  Password => 
  KeepAliveTime => 60
  ProtocolVersion => 5.0
  ClientID => 
  Name => cpe-1
  TransportProtocol => TCP/IP
  CleanSession => true
  CleanStart => true
  RequestResponseInfo => false
  ALPN => 
  ConnectRetryTime => 5
  ConnectRetryIntervalMultiplier => 2000
  ConnectRetryMaxInterval => 30720
  ResponseInformation => 
  Status => Error_BrokerUnreachable
  SubscriptionNumberOfEntries => 0

Check that second USP controller is replaced with 'UseSingleControllerInstance' enabled:
  $ R "ba-cli '${DHCP4_OPTION_125_REF}.Value=\"${DHCP4_OPTION_125_STOMP}\"'" > /dev/null
  $ R "sleep ${USP_DISCOVERY_CONTROLLER_CONFIGURE_TIMEOUT}"
  $ R "obuspa -f /etc/obuspa.db -c get Device.LocalAgent.Controller.[Alias==usp_discovery]." | grep -v CurrentRetryCount | awk -F'Device.LocalAgent.Controller.[0-9]+.' '{print $2}'
  Alias => usp_discovery
  Enable => true
  EndpointID => cdrouterTestControllerNEW
  InheritedRole => 
  AssignedRole => 
  PeriodicNotifInterval => 86400
  PeriodicNotifTime => 0001-01-01T00:00:00Z
  USPNotifRetryMinimumWaitInterval => 5
  USPNotifRetryIntervalMultiplier => 2000
  ControllerCode => 
  ProvisioningCode => 
  MTPNumberOfEntries => 1
  BootParameterNumberOfEntries => 0
  MTP.1.Alias => usp_discovery
  MTP.1.Enable => true
  MTP.1.Protocol => STOMP
  MTP.1.STOMP.Reference => Device.STOMP.Connection.2.
  MTP.1.STOMP.Destination => /usp/controller
  MTP.1.MQTT.Reference => 
  MTP.1.MQTT.Topic => 
  MTP.1.WebSocket.Host => 
  MTP.1.WebSocket.Port => 80
  MTP.1.WebSocket.Path => 
  MTP.1.WebSocket.EnableEncryption => true
  MTP.1.WebSocket.KeepAliveInterval => 30
  MTP.1.WebSocket.SessionRetryMinimumWaitInterval => 5
  MTP.1.WebSocket.SessionRetryIntervalMultiplier => 2000
  MTP.1.UDS.UnixDomainSocketRef => 
  MTP.1.UDS.USPServiceRef => 
  $ R "obuspa -f /etc/obuspa.db -c get Device.LocalAgent.MTP.[Alias==usp_discovery]." | awk -F'Device.LocalAgent.MTP.[0-9]+.' '{print $2}'
  Alias => usp_discovery
  Protocol => STOMP
  Enable => true
  Status => Down
  STOMP.Reference => Device.STOMP.Connection.2.
  STOMP.Destination => /usp/agent
  STOMP.DestinationFromServer => 
  MQTT.Reference => 
  MQTT.ResponseTopicConfigured => 
  MQTT.ResponseTopicDiscovered => 
  MQTT.PublishQoS => 0
  WebSocket.Port => 5683
  WebSocket.Path => 
  WebSocket.EnableEncryption => true
  WebSocket.KeepAliveInterval => 30
  UDS.UnixDomainSocketRef => 
  $ R "obuspa -f /etc/obuspa.db -c get Device.MQTT.Client.[Alias==usp_discovery]." | wc -l
  0
  $ R "obuspa -f /etc/obuspa.db -c get Device.STOMP.Connection.[Alias==usp_discovery]." | grep -v LastChangeDate | awk -F'Device.STOMP.Connection.[0-9]+.' '{print $2}'
  Alias => usp_discovery
  Status => ServerNotPresent
  Enable => true
  Host => controller.cdroutertest.com
  Port => 61613
  Username => 
  EnableEncryption => false
  X_ARRIS-COM_EnableEncryption => false
  Password => 
  VirtualHost => /
  EnableHeartbeats => false
  OutgoingHeartbeat => 0
  IncomingHeartbeat => 0
  ServerRetryInitialInterval => 60
  ServerRetryIntervalMultiplier => 2000
  ServerRetryMaxInterval => 30720
