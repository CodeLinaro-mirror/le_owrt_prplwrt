Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting Generic Network Interface tests"

Read GenericNetworkInterface (GNI) object
  $ InitialGNIInstance=$(R "ba-cli -j -l Device.GenericNetworkInterface.?")
  $ R logger -t cram 'Initial GenericNetworkInterface instance read: $InitialGNIInstance'

Create bridge and associate a virtual interface to it
  $ R "(brctl addbr  br100; ip link add gni-1 type veth; ip link set gni-1 master br100; ip link set br100 up; ip link set gni-1 up; ip link set veth0 up) 2>&1 > /dev/null"

Sleep 2 seconds for the linux interfaces to come up
  $ sleep 2

Create a Generic Network Interface Instance
  $ InstanceId=$(R "ba-cli -a  Device.GenericNetworkInterface.Interface+{Name='gni-1',Alias='gni-1-alias',Enable=1} | sed -n 's/.*Interface\.\([0-9]*\)\..*/\1/p' | tail -n 1")
  $ R logger -t cram "Generic Network Created with Instance ID: $InstanceId "

Get the Generic Network Instance and verify parameters
  $ R "ba-cli -j -l 'Device.GenericNetworkInterface.Interface.$InstanceId.?' | sed '/^$/d' | jsonfilter -e @[0]'[*].Name' -e @[0]'[*].Alias' -e @[0]'[*].Status'"
  gni-1
  gni-1-alias
  Up

Get the IP Instance of associated Generic Network Interface
  $ IPInstanceId=$(R "ba-cli Device.IP.Interface.*.Name? | grep gni-1 | sed 's/.*Device\.IP\.Interface\.\([0-9]*\)\..*/\1/'")
  $ R logger -t cram "Instance Id of Generic Network Interface under Device.IP.Interface  $IPInstanceId"

Assign IPv4 address to Interface
  $ R "ba-cli -l Device.IP.Interface.$IPInstanceId.IPv4Address.1.IPAddress=192.168.199.1 | sed /^$/d"
  192.168.199.1

  $ R "ba-cli -l Device.IP.Interface.$IPInstanceId.IPv4Address.1.SubnetMask=255.255.255.0 | sed /^$/d"
  255.255.255.0

Verify the IPv4 address with mask set
  $ R "ba-cli Device.IP.Interface.$IPInstanceId.IPv4Address.1.? | grep IPAddress | sed -n 's/.*Device\.IP\.Interface\.$IPInstanceId\.IPv4Address\.1\.IPAddress=.\([^\"]*\).*/\1/p'"
  192.168.199.1

  $ R "ba-cli Device.IP.Interface.$IPInstanceId.IPv4Address.1.? | grep SubnetMask | sed -n 's/.*Device\.IP\.Interface\.$IPInstanceId\.IPv4Address\.1\.SubnetMask=.\([^\"]*\).*/\1/p'"
  255.255.255.0

Make the linux interface down and verify Generic Network Interface Status is down
  $ R "ip link set gni-1 down"

Wait 1 second for the changes to reflect
  $ sleep 1

Verify Generic Network Interface Status is down
  $ R "ba-cli -j -l 'Device.GenericNetworkInterface.Interface.$InstanceId.?' | sed '/^$/d' | jsonfilter -e @[0]'[*].Status'"
  Down

Make the interface UP and veirfy status is UP
  $ R "ip link set gni-1 up"

Wait 1 seocnds for the changes to reflect and verify
  $ sleep 1
  $ R "ba-cli -j -l 'Device.GenericNetworkInterface.Interface.$InstanceId.?' | sed '/^$/d' | jsonfilter -e @[0]'[*].Status'"
  Up

Clean-up, Delete Generic Network Interface
  $ R "ba-cli -l -j 'Device.GenericNetworkInterface.Interface.$InstanceId._del()' |  sed '/^$/d' | tail -n 2| grep -c 'Device\.GenericNetworkInterface\.Interface\.'"
  2

  $ R "(ip link del gni-1; ip link del br100) 2>&1 > /dev/null"

  $ R logger -t cram "Test finished!"

