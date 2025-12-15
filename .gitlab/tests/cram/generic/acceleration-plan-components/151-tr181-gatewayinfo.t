Setup the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Skip the test because it should be run only on extender device:

  $ exit 80

# Empty DHCPv4 option 125
  $ DHCP4_OPTION_125_EMPTY="00000DE900"
# DHCPv4 option 125 with suboptions {manufacture(4)="manufactureroui4", deviceserialnumber(5)='deviceserialnumber4", deviceproductclass(6)="deviceproductclass4"}
  $ DHCP4_OPTION_125_FIRST="00000DE93C04106D616E7566616374757265726F756934051364657669636573657269616C6E756D62657234061364657669636570726F64756374636C61737334"
# DHCPv4 option 125 with suboptions {manufacture(4)="manufactureroui4_1", deviceserialnumber(5)='deviceserialnumber4_1", deviceproductclass(6)="deviceproductclass4_1"}
  $ DHCP4_OPTION_125_SECOND="00000DE94204126D616E7566616374757265726F7569345F31051564657669636573657269616C6E756D626572345F31061564657669636570726F64756374636C617373345F31"
  $ WAN_IFACES=$(R "jsonfilter -i /etc/networklayout.json -e '@.Interfaces[@.Upstream = \"true\"].Alias' | wc -l")
  $ IFACE=$([ ${WAN_IFACES} -gt 0 ] && echo "wan" || echo "lan")
  $ DHCP4_CLIENT_REF="DHCPv4Client.Client.${IFACE}"
  $ START_TIME=$(R "date +\"%Y %b %d %H:%M:%S\"")
  $ R "obuspa -f /etc/obuspa.db -c prototrace 1" > /dev/null
  $ event_subscription=$(R "obuspa -f /etc/obuspa.db -c add Device.LocalAgent.Subscription. | cut -d' ' -f2")
  $ R "obuspa -f /etc/obuspa.db -c set ${event_subscription}.NotifType Event" > /dev/null
  $ R "obuspa -f /etc/obuspa.db -c set ${event_subscription}.ReferenceList Device.GatewayInfo.CWMPGatewayDiscovered!" > /dev/null
  $ R "obuspa -f /etc/obuspa.db -c set ${event_subscription}.Enable true" > /dev/null

Prepare DHCP request option-125:

  $ if [ -z $(R "ba-cli '${DHCP4_CLIENT_REF}.ReqOption.?'" | grep 'Tag=125') ]; then R "ba-cli '${DHCP4_CLIENT_REF}.ReqOption+ {Tag=125,Enable=1}'" > /dev/null; fi
  $ DHCP4_OPTION_125_REF=$(R "ba-cli '${DHCP4_CLIENT_REF}.ReqOption.[Tag==125].?' | awk 'NR==2'")

Check that changes from DHCPv4 Option 125 are applied:

  $ R "ba-cli '${DHCP4_OPTION_125_REF}Value=\"${DHCP4_OPTION_125_FIRST}\"'" > /dev/null
  $ R "ba-cli 'GatewayInfo.?' | awk 'NF && NR>2'"
  GatewayInfo.EndpointID=""
  GatewayInfo.MACAddress=""
  GatewayInfo.ManagementProtocol="CWMP"
  GatewayInfo.ManufacturerOUI="manufactureroui4"
  GatewayInfo.ProductClass="deviceproductclass4"
  GatewayInfo.SerialNumber="deviceserialnumber4"
  $ R "ba-cli Device.GatewayInfo.? | awk 'NF && NR > 2'"
  Device.GatewayInfo.ManufacturerOUI="manufactureroui4"
  Device.GatewayInfo.ProductClass="deviceproductclass4"
  Device.GatewayInfo.SerialNumber="deviceserialnumber4"
  $ R "obuspa -f /etc/obuspa.db -c get Device.GatewayInfo."
  Device.GatewayInfo.ManufacturerOUI => manufactureroui4
  Device.GatewayInfo.EndpointID => 
  Device.GatewayInfo.SerialNumber => deviceserialnumber4
  Device.GatewayInfo.ProductClass => deviceproductclass4
  Device.GatewayInfo.MACAddress => 
  Device.GatewayInfo.ManagementProtocol => CWMP

Check notification:

  $ R "logread | grep obuspa | grep -A15 \"event {\" | cut -d']' -f2"
  :       event {
  :         obj_path: "Device.GatewayInfo."
  :         event_name: "CWMPGatewayDiscovered!"
  :         params {
  :           key: "ManufacturerOUI"
  :           value: "manufactureroui4"
  :         }
  :         params {
  :           key: "SerialNumber"
  :           value: "deviceserialnumber4"
  :         }
  :         params {
  :           key: "ProductClass"
  :           value: "deviceproductclass4"
  :         }
  :       }

Check that parameters are reset when an empty Option 125 is received:

  $ R "ba-cli '${DHCP4_OPTION_125_REF}Value=\"${DHCP4_OPTION_125_EMPTY}\"'" > /dev/null
  $ R "ba-cli 'GatewayInfo.?' | awk 'NF && NR>2'"
  GatewayInfo.EndpointID=""
  GatewayInfo.MACAddress=""
  GatewayInfo.ManagementProtocol=""
  GatewayInfo.ManufacturerOUI=""
  GatewayInfo.ProductClass=""
  GatewayInfo.SerialNumber=""
  $ R "obuspa -f /etc/obuspa.db -c get Device.GatewayInfo."
  Device.GatewayInfo.ManufacturerOUI => 
  Device.GatewayInfo.EndpointID => 
  Device.GatewayInfo.SerialNumber => 
  Device.GatewayInfo.ProductClass => 
  Device.GatewayInfo.MACAddress => 
  Device.GatewayInfo.ManagementProtocol => 

Check that changes from DHCPv4 Option 125 are applied at the service startup:

  $ R "pkill -f tr181-gatewayinfo" # TODO: replace with `service tr181-gatewayinfo stop` after fix https://prplfoundationcloud.atlassian.net/browse/PPW-625
  $ R "ba-cli '${DHCP4_OPTION_125_REF}Value=\"${DHCP4_OPTION_125_SECOND}\"'" > /dev/null
  $ R "service tr181-gatewayinfo start"
  $ R "ba-cli 'GatewayInfo.?' | awk 'NF && NR>2'"
  GatewayInfo.EndpointID=""
  GatewayInfo.MACAddress=""
  GatewayInfo.ManagementProtocol="CWMP"
  GatewayInfo.ManufacturerOUI="manufactureroui4_1"
  GatewayInfo.ProductClass="deviceproductclass4_1"
  GatewayInfo.SerialNumber="deviceserialnumber4_1"
  $ R "ba-cli Device.GatewayInfo.? | awk 'NF && NR > 2'"
  Device.GatewayInfo.ManufacturerOUI="manufactureroui4_1"
  Device.GatewayInfo.ProductClass="deviceproductclass4_1"
  Device.GatewayInfo.SerialNumber="deviceserialnumber4_1"
  $ R "obuspa -f /etc/obuspa.db -c get Device.GatewayInfo."
  Device.GatewayInfo.ManufacturerOUI => manufactureroui4_1
  Device.GatewayInfo.EndpointID => 
  Device.GatewayInfo.SerialNumber => deviceserialnumber4_1
  Device.GatewayInfo.ProductClass => deviceproductclass4_1
  Device.GatewayInfo.MACAddress => 
  Device.GatewayInfo.ManagementProtocol => CWMP

Cleanup:
  $ R "obuspa -f /etc/obuspa.db -c prototrace 0" > /dev/null
  $ R "obuspa -f /etc/obuspa.db -c del ${event_subscription}" > /dev/null
