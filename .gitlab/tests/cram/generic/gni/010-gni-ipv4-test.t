Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting Generic Network Interface IPv4 test"

Read GenericNetworkInterface (GNI) object and log it:

  $ InitialGNIInstance=$(R "ba-cli -j -l GenericNetworkInterface.?")

  $ R logger -t cram "Initial GenericNetworkInterface instance read: "$InitialGNIInstance

Create a bridge and associate it with a virtual interface:

  $ R "(brctl addbr  br100; ip link add gni-1 type veth; ip link set gni-1 master br100; ip link set br100 up; ip link set gni-1 up; ip link set veth0 up) 2>&1 > /dev/null"

Sleep 2 seconds for the linux interfaces to come up:

  $ sleep 2

Create a Generic Network Interface Instance:

  $ InstanceId=$(R "ba-cli -a  GenericNetworkInterface.Interface+{Name='gni-1',Alias='gni-1-alias',Enable=1} | sed -n 's/.*Interface\.\([0-9]*\)\..*/\1/p' | tail -n 1")

  $ R logger -t cram "Generic Network Created with Instance ID: "$InstanceId

Get the Generic Network Instance created and verify parameters:

  $ R "ba-cli -j -l 'GenericNetworkInterface.Interface.$InstanceId.?' | sed '/^$/d' | jsonfilter -e @[0]'[*].Name' -e @[0]'[*].Alias' -e @[0]'[*].Status'"
  gni-1
  gni-1-alias
  Up

Associate IP interface with Generic Network Interface instance:

  $ IPInstanceId=$(R "ba-cli Device.IP.Interface.*.Name? | grep gni-1 | sed 's/.*Device\.IP\.Interface\.\([0-9]*\)\..*/\1/'")

  $ if [ -z "$IPInstanceId" ]; then \
  >  IPInstanceId=$( \
  >      R "ba-cli IP.Interface.+\{ \
  >          Alias=\"gni\",Enable=1,Name=\"gni-1\", \
  >          LowerLayers=\"GenericNetworkInterface.Interface.$InstanceId.\", \
  >          Router=\"Device.Routing.Router.1.\",IPv4Enable=1\}" | \
  >      grep 'IP.Interface.[0-9]\+\.Alias' | sed -n 's/.*Interface\.\([0-9]\+\)\..*/\1/p' \
  >  ); \
  > fi;

  $ R logger -t cram "Instance Id of Generic Network Interface under Device.IP.Interface  "$IPInstanceId

Create IPv4Address object for the IP Interface:

  $ R "ba-cli -j -l IP.Interface.$IPInstanceId.IPv4Address.+\{Alias="gni_static_address", AddressingType="Static", Enable=1,IPAddress="192.200.200.200",SubnetMask="255.255.255.0"\} |   sed '/^$/d' "
  {"IP.Interface.\d+.IPv4Address.\d+.":{"Alias":"gni_static_address"}} (re)

Assign IPv4 address to the IP Interface:

  $ R "ba-cli -l Device.IP.Interface.$IPInstanceId.IPv4Address.1.IPAddress=192.168.199.1 | sed /^$/d"
  192.168.199.1

  $ R "ba-cli -l Device.IP.Interface.$IPInstanceId.IPv4Address.1.SubnetMask=255.255.255.0 | sed /^$/d"
  255.255.255.0

Verify the IPv4 address with mask set:

  $ R "ba-cli Device.IP.Interface.$IPInstanceId.IPv4Address.1.? | grep IPAddress | sed -n 's/.*Device\.IP\.Interface\.$IPInstanceId\.IPv4Address\.1\.IPAddress=.\([^\"]*\).*/\1/p'"
  192.168.199.1

  $ R "ba-cli Device.IP.Interface.$IPInstanceId.IPv4Address.1.? | grep SubnetMask | sed -n 's/.*Device\.IP\.Interface\.$IPInstanceId\.IPv4Address\.1\.SubnetMask=.\([^\"]*\).*/\1/p'"
  255.255.255.0

Make the linux interface down and verify Generic Network Interface Status is down:

  $ R "ip link set gni-1 down"

Wait 1 second for the changes to reflect:

  $ sleep 1

Verify Generic Network Interface Status is down:

  $ R "ba-cli -j -l 'GenericNetworkInterface.Interface.$InstanceId.?' | sed '/^$/d' | jsonfilter -e @[0]'[*].Status'"
  Down

Make the interface UP and veirfy status is UP:

  $ R "ip link set gni-1 up"

Wait 1 seocnds for the changes to reflect and verify:

  $ sleep 1

Verify Generic Network Interface Status is UP:

  $ R "ba-cli -j -l 'GenericNetworkInterface.Interface.$InstanceId.?' | sed '/^$/d' | jsonfilter -e @[0]'[*].Status'"
  Up

Delete the linux interface and verify Generic Network Interface status is updated:

  $ R "(ip link del gni-1; ip link del br100) 2>&1 > /dev/null"

Wait 1 seocnds for the changes to reflect and verify:

  $ sleep 1

Verify Generic Network Interface Status is NotPresent:

  $ R "ba-cli -j -l 'GenericNetworkInterface.Interface.$InstanceId.?' | sed '/^$/d' | jsonfilter -e @[0]'[*].Status'"
  NotPresent

Clean-up, Delete the IP interface and Generic Network Interface:

  $ R "ba-cli -l IP.Interface.$IPInstanceId.- | sed '/^$/d'"
  IP.Interface.\d+. (re)
  IP.Interface.\d+.Stats. (re)
  IP.Interface.\d+.X_PRPLWARE-COM_IPv4Config. (re)
  IP.Interface.\d+.X_PRPLWARE-COM_IPv6Config. (re)
  IP.Interface.\d+.IPv4Address. (re)
  IP.Interface.\d+.IPv4Address.\d+. (re)
  IP.Interface.\d+.IPv6Address. (re)
  IP.Interface.\d+.IPv6Prefix. (re)

  $ R "ba-cli -l -j 'GenericNetworkInterface.Interface.$InstanceId._del()' |  sed '/^$/d' | tail -n 1"
  \[\["GenericNetworkInterface.Interface.\d+.","GenericNetworkInterface.Interface.\d+.Stats."\]\] (re)

  $ R logger -t cram "Generice Network Interface IPv4 test finished"