Test skipped due to tr069-discovery being available only on the extender-full profile
  $ exit 80

Setup the test configuration:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
# Encoded empty DHCPv4 option 125
  $ DHCP4_OPTION_125_EMPTY="00000DE900"
# Encoded DHCPv4 option 125 with suboptions acs_url(11)="http://192.168.1.1:10001", provisioning_code(12)="extender1"
  $ DHCP4_OPTION_125_FIRST="00000de9250b18687474703a2f2f3139322e3136382e312e313a31303030310c09657874656e64657231"
# Encoded DHCPv4 option 125 with suboptions acs_url(11)="http://192.168.1.1:10002", provisioning_code(12)="extender2"
  $ DHCP4_OPTION_125_SECOND="00000de9250b18687474703a2f2f3139322e3136382e312e313a31303030320c09657874656e64657232"
  $ TR069_DISCOVERY_ODL="/etc/amx/tr069-discovery/tr069-discovery.odl"
  $ DHCP4_CLIENT_REF=$(R "grep DHCPv4ClientReference '${TR069_DISCOVERY_ODL}'" | awk -F'"' '{print $2}')

Prepare DHCP request option-125:

  $ if [ -z $(R "ba-cli '${DHCP4_CLIENT_REF}.ReqOption.?'" | grep 'Tag=125') ]; then R "ba-cli '${DHCP4_CLIENT_REF}.ReqOption+ {Tag=125,Enable=1}'" > /dev/null; fi
  $ DHCP4_OPTION_125_REF=$(R "ba-cli '${DHCP4_CLIENT_REF}.ReqOption.[Tag==125].?' | awk 'NR==2'")

Stop service and set test value for DHCPv4 option 125:

  $ R "service tr069-discovery stop"
  $ R "rm /etc/config/tr069-discovery/odl/tr069-discovery.odl"
  $ R "ba-cli '${DHCP4_OPTION_125_REF}Value=\"${DHCP4_OPTION_125_FIRST}\"'" > /dev/null
  $ R "sed -i '/DHCPv6WaitTime/c\DHCPv6WaitTime = 0;' '${TR069_DISCOVERY_ODL}'"
  $ R "ba-cli 'ManagementServer.URL=\"http://acs-download.qacafe.com\"'" > /dev/null

Check that DHCP provisioning is not enabled during startup if ManagementServer.URL is non-empty:

  $ R "service tr069-discovery start"
  $ R "ba-cli -jl 'X_PRPLWARE-COM_TR069Discovery.State._get()'" | awk 'NF && NR > 2'
  [{"X_PRPLWARE-COM_TR069Discovery.State.":{"DHCPProvisionInUse":0,"FirstSuccessfulProvision":"None"}}]
  $ R "ba-cli -l 'ManagementServer.URL?'" | awk 'NF'
  http://acs-download.qacafe.com
  $ R "ba-cli -jl 'ManagementServer.InternalSettings._get(parameters=[\"ACSAddrFamily\", \"PreferredIPVersion\"])'" | awk 'NF && NR > 2'
  [{"ManagementServer.InternalSettings.":{"PreferredIPVersion":"IPANY","ACSAddrFamily":0}}]

Check that DHCP provisioning is enabled after the user sets empty value for ManagementServer.URL:

  $ R "ba-cli 'ManagementServer.URL=\"\"'" > /dev/null
  $ R "ba-cli -jl 'X_PRPLWARE-COM_TR069Discovery.State._get()'" | awk 'NF && NR > 2'
  [{"X_PRPLWARE-COM_TR069Discovery.State.":{"DHCPProvisionInUse":1,"FirstSuccessfulProvision":"None"}}]
  $ R "ba-cli -l 'ManagementServer.URL?'" | awk 'NF'
  http://192.168.1.1:10001
  $ R "ba-cli -l 'Device.DeviceInfo.ProvisioningCode?'" | awk 'NF'
  extender1
  $ R "ba-cli -jl 'ManagementServer.InternalSettings._get(parameters=[\"ACSAddrFamily\", \"PreferredIPVersion\"])'" | awk 'NF && NR > 2'
  [{"ManagementServer.InternalSettings.":{"PreferredIPVersion":"IPV4ONLY","ACSAddrFamily":4}}]

Check that the DHCPv4 Option 125 update is applied when DHCP provisioning is enabled:

  $ R "ba-cli '${DHCP4_OPTION_125_REF}Value=\"${DHCP4_OPTION_125_SECOND}\"'" > /dev/null
  $ R "ba-cli -jl 'X_PRPLWARE-COM_TR069Discovery.State._get()'" | awk 'NF && NR > 2'
  [{"X_PRPLWARE-COM_TR069Discovery.State.":{"DHCPProvisionInUse":1,"FirstSuccessfulProvision":"None"}}]
  $ R "ba-cli -l 'ManagementServer.URL?'" | awk 'NF'
  http://192.168.1.1:10002
  $ R "ba-cli -l 'Device.DeviceInfo.ProvisioningCode?'" | awk 'NF'
  extender2
  $ R "ba-cli -jl 'ManagementServer.InternalSettings._get(parameters=[\"ACSAddrFamily\", \"PreferredIPVersion\"])'" | awk 'NF && NR > 2'
  [{"ManagementServer.InternalSettings.":{"PreferredIPVersion":"IPV4ONLY","ACSAddrFamily":4}}]

Check that ManagementServer.URL is set to an empty value as a result of stopping the service when DHCP provisioning is active:

  $ R "service tr069-discovery stop"
  $ R "ba-cli -l 'ManagementServer.URL?'" | awk 'NF'
  $ R "cat /etc/config/tr069-discovery/odl/tr069-discovery.odl"
  %populate {
  \tobject 'X_PRPLWARE-COM_TR069Discovery' { (esc)
  \t\tobject 'State' { (esc)
  \t\t\tparameter 'DHCPProvisionInUse' = false { (esc)
  \t\t\t\tuserflags  %upc; (esc)
  \t\t\t} (esc)
  \t\t\tparameter 'FirstSuccessfulProvision' = "None" { (esc)
  \t\t\t\tuserflags  %upc; (esc)
  \t\t\t} (esc)
  \t\t} (esc)
  \t} (esc)
  }

Check that DHCP provisioning is enabled after the service starts with an empty ManagementServer.URL:

  $ R "service tr069-discovery start"
  $ R "ba-cli -jl 'X_PRPLWARE-COM_TR069Discovery.State._get()'" | awk 'NF && NR > 2'
  [{"X_PRPLWARE-COM_TR069Discovery.State.":{"DHCPProvisionInUse":1,"FirstSuccessfulProvision":"None"}}]
  $ R "ba-cli -l 'ManagementServer.URL?'" | awk 'NF'
  http://192.168.1.1:10002
  $ R "ba-cli -l 'Device.DeviceInfo.ProvisioningCode?'" | awk 'NF'
  extender2
  $ R "ba-cli -jl 'ManagementServer.InternalSettings._get(parameters=[\"ACSAddrFamily\", \"PreferredIPVersion\"])'" | awk 'NF && NR > 2'
  [{"ManagementServer.InternalSettings.":{"PreferredIPVersion":"IPV4ONLY","ACSAddrFamily":4}}]

Check handling empty DHCPv4 config (emulate lease timeout):

  $ R "ba-cli '${DHCP4_OPTION_125_REF}Value=\"${DHCP4_OPTION_125_EMPTY}\"'" > /dev/null
  $ R "ba-cli -l 'ManagementServer.URL?'" | awk 'NF'

Check that DHCP provisioning is disabled after the user sets a non-empty ManagementServer.URL:

  $ R "ba-cli 'ManagementServer.URL=\"http://acs-download.qacafe.com\"'" > /dev/null
  $ R "ba-cli -jl 'X_PRPLWARE-COM_TR069Discovery.State._get()'" | awk 'NF && NR > 2'
  [{"X_PRPLWARE-COM_TR069Discovery.State.":{"DHCPProvisionInUse":0,"FirstSuccessfulProvision":"None"}}]
  $ R "ba-cli -jl 'ManagementServer.InternalSettings._get(parameters=[\"ACSAddrFamily\", \"PreferredIPVersion\"])'" | awk 'NF && NR > 2'
  [{"ManagementServer.InternalSettings.":{"PreferredIPVersion":"IPANY","ACSAddrFamily":0}}]
