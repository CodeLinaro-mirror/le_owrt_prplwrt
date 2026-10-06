Create alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting with Backup and restore config restore testcase"

Create configuration under DNS:

  $ DnsId1=$(R "ba-cli -l -j DNS.X_PRPLWARE-COM_Host+"\
  > "{Enable=1,Name=TestDnsInstance} | sed '/^$/d' | "\
  > "sed -n 's/.*Host\.\([0-9][0-9]*\)\..*/\1/p'")

Create a route entry in routing table using br-lan as egress interface:

  $ RouteId1=$(R "ba-cli -l -j Routing.Router.1.IPv4Forwarding+{DestIPAddress="\
  > "\"192.168.168.0\",DestSubnetMask=\"255.255.255.0\",Enable=1,"\
  > "GatewayIPAddress=$TARGET_LAN_IP} | "\
  > "sed -n 's/.*IPv4Forwarding\.\([0-9][0-9]*\)\..*/\1/p'")

Create additional User test-user under Users.user:

  $ UserId1=$(R "ba-cli -l -j Users.User.+{Username=\"test-user\",Enable=1,"\
  > "GroupParticipation=\"Users.Group.9\",RoleParticipation=\"Users.Role.4\""\
  > ",Shell=\"Users.SupportedShell.1\"} | sed '/^$/d' | "\
  > "sed -n 's/.*Users\.User\.\([0-9]\+\)\..*/\1/p'")

Skip device-info manager until PPW-1787 and PPW-1715 is fixed:
#Enable CPU and Memory monitoring:

#  $ R "ba-cli -l -j DeviceInfo.ProcessStatus.CPU.1.Enable=1 | sed '/^$/d'"
#  [{"DeviceInfo.ProcessStatus.CPU.1.":{"Enable":1}}]

#  $ R "ba-cli -l -j DeviceInfo.MemoryStatus.MemoryMonitor.Enable=1 | sed '/^$/d'"
#  [{"DeviceInfo.MemoryStatus.MemoryMonitor.":{"Enable":1}}]

Create Backup of the current configuration:

  $ R "ba-cli -l -j 'PersistentConfiguration.Backup()' | sed '/^$/d'"
  PersistentConfiguration.Backup() returned
  [""]

Delete or disable the created configuration entries:

  $ R "ba-cli -l -j DNS.X_PRPLWARE-COM_Host.$DnsId1.- | sed '/^$/d'"
  \["DNS.X_PRPLWARE-COM_Host.\d+.","DNS.X_PRPLWARE-COM_Host.\d+.IPAddress."\] (re)

  $ R "ba-cli -l -j Routing.Router.1.IPv4Forwarding.$RouteId1.- | sed '/^$/d'"
  \["Routing.Router.1.IPv4Forwarding.\d+."\] (re)

  $ R "ba-cli -l -j Users.User.$UserId1.- | sed '/^$/d'"
  \["Users.User.\d+."\] (re)

Skip device-info manager until PPW-1787 and PPW-1715 is fixed:
#  $ R "ba-cli -l -j DeviceInfo.ProcessStatus.CPU.1.Enable=0 | sed '/^$/d'"
#  [{"DeviceInfo.ProcessStatus.CPU.1.":{"Enable":0}}]

#  $ R "ba-cli -l -j DeviceInfo.MemoryStatus.MemoryMonitor.Enable=0 | sed '/^$/d'"
#  [{"DeviceInfo.MemoryStatus.MemoryMonitor.":{"Enable":0}}]

Restore the configuration from backup generated earlier:
  $ R "ba-cli -l -j 'PersistentConfiguration.Restore()' | sed '/^$/d'"
  PersistentConfiguration.Restore() returned
  [""]

Get the new Instance Ids for the configuration after restore:

  $ DnsId2=$(R "ba-cli DNS.X_PRPLWARE-COM_Host.*.Name\? | "\
  > "grep \"TestDnsInstance\" | sed -n 's/.*Host\.\([0-9]\+\)\.Name.*/\1/p'")

  $ RouteId2=$(R "ba-cli Routing.Router.1.IPv4Forwarding.\? | "\
  > "grep 192.168.168.0 | sed -n 's/.*IPv4Forwarding\.\([0-9]\+\)\..*/\1/p'")

  $ UserId2=$(R "ba-cli Users.User.*.Username\? | grep test-user "\
  > " | sed -n 's/.*Users\.User\.\([0-9]\+\)\..*/\1/p'")

Verify restored configuration:

  $ R "ba-cli -l -j DNS.X_PRPLWARE-COM_Host.$DnsId2.\?" | jq --sort-keys '.[0]'
  {
    "DNS.X_PRPLWARE-COM_Host.\d+.": { (re)
      "Alias": "cpe-X_PRPLWARE-COM_Host-\d+", (re)
      "Enable": 1,
      "IPAddressNumberOfEntries": 0,
      "Interface": "",
      "Name": "TestDnsInstance",
      "Origin": "Static"
    }
  }

  $ R "ba-cli -l -j Routing.Router.1.IPv4Forwarding.$RouteId2.\?" | \
  > jq --sort-keys '.[0]'
  {
    "Routing.Router.1.IPv4Forwarding.\d+.": { (re)
      "Alias": "cpe-IPv4Forwarding-\d+", (re)
      "DestIPAddress": "192.168.168.0",
      "DestSubnetMask": "255.255.255.0",
      "Enable": 1,
      "ForwardingMetric": -1,
      "ForwardingPolicy": -1,
      "GatewayIPAddress": .* (re)
      "Interface": "",
      "MTU": 0,
      "Origin": "Static",
      "StaticRoute": 1,
      "Status": "Enabled"
    }
  }

  $ R "ba-cli -l -j Users.User.$UserId2.\?" | jq --sort-keys '.[0]'
  {
    "Users.User.\d+.": { (re)
      "Alias": "cpe-User-\d+", (re)
      "Enable": 1,
      "GroupParticipation": "Users.Group.9",
      "Language": "",
      "Password": "",
      "RoleParticipation": "Users.Role.4",
      "Shell": "Users.SupportedShell.1",
      "StaticUser": 0,
      "UserID": 1001,
      "Username": "test-user",
      "X_PRPLWARE-COM_HashedPassword": "",
      "X_PRPLWARE-COM_HomeDirectory": "/var"
    }
  }

Skip device-info manager until PPW-1787 and PPW-1715 is fixed:
#  $ R "ba-cli -l -j DeviceInfo.ProcessStatus.CPU.1.Enable\? | sed '/^$/d'"
#  [{"DeviceInfo.ProcessStatus.CPU.1.":{"Enable":1}}]

#  $ R "ba-cli -l -j DeviceInfo.MemoryStatus.MemoryMonitor.Enable\?| sed '/^$/d'"
#  [{"DeviceInfo.MemoryStatus.MemoryMonitor.":{"Enable":1}}]

Create Backup of the current configuration again:

  $ R "ba-cli -l -j 'PersistentConfiguration.Backup()' | sed '/^$/d'"
  PersistentConfiguration.Backup() returned
  [""]

Delete or disable the configurations again:

  $ R "ba-cli -l -j DNS.X_PRPLWARE-COM_Host.$DnsId2.- | sed '/^$/d'"
  \["DNS.X_PRPLWARE-COM_Host.\d+.","DNS.X_PRPLWARE-COM_Host.\d+.IPAddress."\] (re)

  $ R "ba-cli -l -j Routing.Router.1.IPv4Forwarding.$RouteId2.- | "\
  > "sed '/^$/d'"
  \["Routing.Router.1.IPv4Forwarding.\d+."\] (re)

  $ R "ba-cli -l -j Users.User.$UserId2.- | sed '/^$/d'"
  \["Users.User.\d+."\] (re)

Skip device-info manager until PPW-1787 and PPW-1715 is fixed:
#  $ R "ba-cli -l -j DeviceInfo.ProcessStatus.CPU.1.Enable=0 | sed '/^$/d'"
#  [{"DeviceInfo.ProcessStatus.CPU.1.":{"Enable":0}}]

#  $ R "ba-cli -l -j DeviceInfo.MemoryStatus.MemoryMonitor.Enable=0 | sed '/^$/d'"
#  [{"DeviceInfo.MemoryStatus.MemoryMonitor.":{"Enable":0}}]

Verify configuration restore by deleting the plugin configs:

Set the PersistentConfiguration ImportStatus to None to trigger config apply:

  $ R "ba-cli PersistentConfiguration.Service.*.ImportStatus=None > /dev/null"

Delete the /etc/config/ for all services:

  $ R "rm -rf /etc/config/tr181-dns/*"
  $ R "rm -rf /etc/config/routing-manager/*"
  $ R "rm -rf /etc/config/tr181-usermanagement/*"
Skip device-info manager until PPW-1787 and PPW-1715 is fixed:
#  $ R "rm -rf /etc/config/deviceinfo-manager/*"

Stop and restart the services:

  $ R "/etc/init.d/tr181-dns stop > /dev/null 2>&1"
  $ R "/etc/init.d/tr181-usermanagement stop > /dev/null 2>&1"
  $ R "/etc/init.d/tr181-dns start > /dev/null 2>&1"
  $ R "/etc/init.d/tr181-usermanagement start > /dev/null 2>&1"
  $ R "/etc/init.d/routing-manager stop > /dev/null 2>&1"
Skip device-info manager until PPW-1787 and PPW-1715 is fixed:
#  $ R "/etc/init.d/deviceinfo-manager stop > /dev/null 2>&1"
  $ R "/etc/init.d/routing-manager start > /dev/null 2>&1"
Skip device-info manager until PPW-1787 and PPW-1715 is fixed:
#  $ R "/etc/init.d/deviceinfo-manager start > /dev/null 2>&1"

Wait few seconds for the configuration restore:

  $ sleep 7

Get the new Instance Ids for the configuration after restore:

  $ RouteId3=$(R "ba-cli Routing.Router.1.IPv4Forwarding.\? | "\
  > "grep 192.168.168.0 | sed -n 's/.*IPv4Forwarding\.\([0-9]\+\)\..*/\1/p'")

  $ UserId3=$(R "ba-cli Users.User.*.Username\? | grep test-user "\
  > " | sed -n 's/.*Users\.User\.\([0-9]\+\)\..*/\1/p'")

  $ DnsId3=$(R "ba-cli DNS.X_PRPLWARE-COM_Host.*.Name\? | "\
  > "grep \"TestDnsInstance\" | sed -n 's/.*Host\.\([0-9]\+\)\.Name.*/\1/p'")

Verify restored configuration after restart:

  $ R "ba-cli -l -j DNS.X_PRPLWARE-COM_Host.$DnsId3.\?" | jq --sort-keys '.[0]'
  {
    "DNS.X_PRPLWARE-COM_Host.\d+.": { (re)
      "Alias": "cpe-X_PRPLWARE-COM_Host-\d+", (re)
      "Enable": 1,
      "IPAddressNumberOfEntries": 0,
      "Interface": "",
      "Name": "TestDnsInstance",
      "Origin": "Static"
    }
  }

  $ R "ba-cli -l -j Routing.Router.1.IPv4Forwarding.$RouteId3.\?" | \
  > jq --sort-keys '.[0]'
  {
    "Routing.Router.1.IPv4Forwarding.\d+.": { (re)
      "Alias": "cpe-IPv4Forwarding-\d+", (re)
      "DestIPAddress": "192.168.168.0",
      "DestSubnetMask": "255.255.255.0",
      "Enable": 1,
      "ForwardingMetric": -1,
      "ForwardingPolicy": -1,
      "GatewayIPAddress": .* (re)
      "Interface": "",
      "MTU": 0,
      "Origin": "Static",
      "StaticRoute": 1,
      "Status": "Enabled"
    }
  }

  $ R "ba-cli -l -j Users.User.$UserId3.\?"| jq --sort-keys '.[0]'
  {
    "Users.User.\d+.": { (re)
      "Alias": "cpe-User-\d+", (re)
      "Enable": 1,
      "GroupParticipation": "Users.Group.9",
      "Language": "",
      "Password": "",
      "RoleParticipation": "Users.Role.4",
      "Shell": "Users.SupportedShell.1",
      "StaticUser": 0,
      "UserID": 1001,
      "Username": "test-user",
      "X_PRPLWARE-COM_HashedPassword": "",
      "X_PRPLWARE-COM_HomeDirectory": "/var"
    }
  }

Skip device-info manager until PPW-1787 and PPW-1715 is fixed:
#  $ R "ba-cli -l -j DeviceInfo.ProcessStatus.CPU.1.Enable\? | sed '/^$/d'"
#  [{"DeviceInfo.ProcessStatus.CPU.1.":{"Enable":1}}]

#  $ R "ba-cli -l -j DeviceInfo.MemoryStatus.MemoryMonitor.Enable\?| sed '/^$/d'"
#  [{"DeviceInfo.MemoryStatus.MemoryMonitor.":{"Enable":1}}]

Delete or disable the configurations again:

  $ R "ba-cli -l -j DNS.X_PRPLWARE-COM_Host.$DnsId3.- | sed '/^$/d'"
  \["DNS.X_PRPLWARE-COM_Host.\d+.","DNS.X_PRPLWARE-COM_Host.\d+.IPAddress."\] (re)

  $ R "ba-cli -l -j Routing.Router.1.IPv4Forwarding.$RouteId3.- | "\
  > "sed '/^$/d'"
  \["Routing.Router.1.IPv4Forwarding.\d+."\] (re)

  $ R "ba-cli -l -j Users.User.$UserId3.- | sed '/^$/d'"
  \["Users.User.\d+."\] (re)

Skip device-info manager until PPW-1787 and PPW-1715 is fixed:
#  $ R "ba-cli -l -j DeviceInfo.ProcessStatus.CPU.1.Enable=0 | sed '/^$/d'"
#  [{"DeviceInfo.ProcessStatus.CPU.1.":{"Enable":0}}]

#  $ R "ba-cli -l -j DeviceInfo.MemoryStatus.MemoryMonitor.Enable=0 | sed '/^$/d'"
#  [{"DeviceInfo.MemoryStatus.MemoryMonitor.":{"Enable":0}}]

Adding additional sleep for Deviceinfo manager to come fully functional:

  $ sleep 70

  $ R logger -t cram "Backup and restore config restore testcase finished"
