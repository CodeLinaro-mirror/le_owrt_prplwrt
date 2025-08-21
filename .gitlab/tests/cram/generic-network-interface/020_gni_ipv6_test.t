Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting Generic Network Interface tests"

Read GenericNetworkInterface (GNI) object
  $ InitialGNIInstance=$(R "ba-cli -j -l Device.GenericNetworkInterface.?")
  $ R logger -t cram 'Initial GenericNetworkInterface instance read: $InitialGNIInstance'

Create bridge and associate a virtual interface to it
  $ R "(brctl addbr  br100; ip link add gni-2 type veth; ip link set gni-2 master br100; ip link set br100 up; ip link set gni-2 up; ip link set veth0 up) 2>&1 > /dev/null"

Sleep 2 seconds for the linux interfaces to come up
  $ sleep 2

Create a Generic Network Interface Instance
  $ InstanceId=$(R "ba-cli -a  Device.GenericNetworkInterface.Interface+{Name='gni-2',Alias='gni-2-alias',Enable=1} | sed -n 's/.*Interface\.\([0-9]*\)\..*/\1/p' | tail -n 1")
  $ R logger -t cram "Generic Network Created with Instance ID: $InstanceId "

Get the Generic Network Instance and verify parameters
  $ R "ba-cli -j -l 'Device.GenericNetworkInterface.Interface.$InstanceId.?' | sed '/^$/d' | jsonfilter -e @[0]'[*].Name' -e @[0]'[*].Alias' -e @[0]'[*].Status'"
  gni-2
  gni-2-alias
  Up

Get the IP Instance of associated Generic Network Interface
  $ IPInstanceId=$(R "ba-cli Device.IP.Interface.*.Name? | grep gni-2 | sed 's/.*Device\.IP\.Interface\.\([0-9]*\)\..*/\1/'")
  $ R logger -t cram "Instance Id of Generic Network Interface under Device.IP.Interface  $IPInstanceId"

Assign IPv6 address to Interface
  $ R "ba-cli -l Device.IP.Interface.$IPInstanceId.IPv6Address.3.IPAddress=2001:0db8:85a3:0000:0000:8a2e:0370:7334 | sed /^$/d"
  2001:0db8:85a3:0000:0000:8a2e:0370:7334

  $ R "ba-cli -l Device.IP.Interface.$IPInstanceId.IPv6Prefix.4.ChildPrefixBits=0:0::/32 | sed /^$/d"
  0:0::/32

Verify the IPv6 address with mask set
  $ R "ba-cli Device.IP.Interface.$IPInstanceId.IPv6Address.3.? | grep IPAddress= | sed -n 's/.*Device\.IP\.Interface\.$IPInstanceId\.IPv6Address\.3\.IPAddress=.\([^\"]*\).*/\1/p'"
  2001:0db8:85a3:0000:0000:8a2e:0370:7334

  $ R "ba-cli Device.IP.Interface.$IPInstanceId.IPv6Prefix.4.? | grep ChildPrefixBit |  sed -n 's/.*Device\.IP\.Interface\.$IPInstanceId\.IPv6Prefix\.4\.ChildPrefixBits=.\([^\"]*\).*/\1/p'"
  0:0::/32

Make the linux interface down and verify Generic Network Interface Status is down
  $ R "ip link set gni-2 down"

Wait 1 second for the changes to reflect
  $ sleep 1

Verify Generic Network Interface Status is down
  $ R "ba-cli -j -l 'Device.GenericNetworkInterface.Interface.$InstanceId.?' | sed '/^$/d' | jsonfilter -e @[0]'[*].Status'"
  Down

Make the interface UP and veirfy status is UP
  $ R "ip link set gni-2 up"

Wait 1 seocnds for the changes to reflect
  $ sleep 1
  $ R "ba-cli -j -l 'Device.GenericNetworkInterface.Interface.$InstanceId.?' | sed '/^$/d' | jsonfilter -e @[0]'[*].Status'"
  Up

  $ R logger -t cram "Test finished!"

Clean-up, Delete Generic Network Interface
  $ R "ba-cli -l -j 'Device.GenericNetworkInterface.Interface.$InstanceId._del()' |  sed '/^$/d' | tail -n 2| grep -c 'Device\.GenericNetworkInterface\.Interface\.'"
  2

  $ R "(ip link del gni-2; ip link del br100) 2>&1 > /dev/null"

  $ R logger -t cram "Test finished!"

