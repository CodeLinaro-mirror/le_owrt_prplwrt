Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting Generic Network Interface IPv6 test"

Read GenericNetworkInterface (GNI) object and log it:

  $ InitialGNIInstance=$(R "ba-cli -j -l GenericNetworkInterface.?")

  $ R logger -t cram "Initial GenericNetworkInterface instance read: "$InitialGNIInstance

Create a bridge and associate it with a virtual interface:

  $ R "(brctl addbr  br100; ip link add gni-2 type veth; ip link set gni-2 master br100; ip link set br100 up; ip link set gni-2 up; ip link set veth0 up) 2>&1 > /dev/null"

Sleep 2 seconds for the linux interfaces to come up:

  $ sleep 2

Create a Generic Network Interface Instance:

  $ InstanceId=$(R "ba-cli -a  GenericNetworkInterface.Interface+{Name='gni-2',Alias='gni-2-alias',Enable=1} | sed -n 's/.*Interface\.\([0-9]*\)\..*/\1/p' | tail -n 1")

  $ R logger -t cram "Generic Network Created with Instance ID: "$InstanceId

Get the Generic Network Instance and verify parameters:

  $ R "ba-cli -j -l 'GenericNetworkInterface.Interface.$InstanceId.?' | sed '/^$/d' | jsonfilter -e @[0]'[*].Name' -e @[0]'[*].Alias' -e @[0]'[*].Status'"
  gni-2
  gni-2-alias
  Up

Get the IP Instance of associated Generic Network Interface:

  $ IPInstanceId=$(R "ba-cli Device.IP.Interface.*.Name? | grep gni-2 | sed 's/.*Device\.IP\.Interface\.\([0-9]*\)\..*/\1/'")

  $ if [ -z "$IPInstanceId" ]; then \
  >  IPInstanceId=$( \
  >      R "ba-cli IP.Interface.+\{ \
  >          Alias=\"gni-ip-instance-alias\",Enable=1,Name=\"gni-2\", \
  >          LowerLayers=\"GenericNetworkInterface.Interface.$InstanceId.\", \
  >          Router=\"Device.Routing.Router.1.\",IPv6Enable=1\}" | \
  >      grep 'IP.Interface.[0-9]\+\.Alias' | sed -n 's/.*Interface\.\([0-9]\+\)\..*/\1/p' \
  >  ); \
  > fi;

  $ R logger -t cram "Instance Id of Generic Network Interface under Device.IP.Interface  "$IPInstanceId

Create IPv6 Prefix object for IPv6 Interface:

  $ PrefixId=$(R "ba-cli IP.Interface.$IPInstanceId.IPv6Prefix+\{Alias=\"gni-ipv6-prefix-alias\",Enable=1,PrefixStatus=\"Preferred\"} | grep -v \{ | grep Alias | sed -n 's/.*IPv6Prefix\.\([0-9]*\)\..*/\1/p'")

  $ R logger -t cram "IPv6 Prefix object Id: "$PrefixId

Create IPv6 Address object for IPv6 Interface:

  $ AddressInstanceId=$(R "ba-cli IP.Interface.$IPInstanceId.IPv6Address.+\{Alias=\"gni_static_address\",Enable=1\} | grep -v { | grep Alias | sed -n 's/.*IPv6Address\.\([0-9]\+\)\..*/\1/p'")

  $ R logger -t cram "IPv6 Address object for IPv6 interface: "$AddressInstanceId

Assign IPv6 prefix for IPv6 Interface:

  $ R "ba-cli -l Device.IP.Interface.$IPInstanceId.IPv6Prefix.$PrefixId.ChildPrefixBits=\"0:0::/32\" | sed /^$/d"
  0:0::/32

  $ R "ba-cli -l Device.IP.Interface.$IPInstanceId.IPv6Prefix.$PrefixId.Prefix=\"0:0::/32\" | sed /^$/d"
  0:0::/32

Configure IPv6 address for the Interface and associate with IPv6 Prefix object:

  $ R "ba-cli -l Device.IP.Interface.$IPInstanceId.IPv6Address.$AddressInstanceId.IPAddress=\"2001:0db8:85a3:0000:0000:8a2e:0370:7334\" | sed '/^$/d'"
  2001:0db8:85a3:0000:0000:8a2e:0370:7334

  $ R "ba-cli -l Device.IP.Interface.$IPInstanceId.IPv6Address.$AddressInstanceId.Prefix=\"Device.IP.Interface.$IPInstanceId.IPv6Prefix.$PrefixId\" | sed '/^$/d' | grep -c Device.IP.Interface.$IPInstanceId.IPv6Prefix.$PrefixId"
  1

Make the linux interface down and verify Generic Network Interface Status is down:

  $ R "ip link set gni-2 down"

Wait 1 second for the changes to reflect:

  $ sleep 1

Verify Generic Network Interface Status is down:

  $ R "ba-cli -j -l 'GenericNetworkInterface.Interface.$InstanceId.?' | sed '/^$/d' | jsonfilter -e @[0]'[*].Status'"
  Down

Make the interface UP and veirfy status is UP:
  $ R "ip link set gni-2 up"

Wait 1 seocnds for the changes to reflect:

  $ sleep 1

  $ R "ba-cli -j -l 'GenericNetworkInterface.Interface.$InstanceId.?' | sed '/^$/d' | jsonfilter -e @[0]'[*].Status'"
  Up

Delete the linux interface and verify Generic Network Interface status as NotPresent:

  $ R "(ip link del gni-2; ip link del br100) 2>&1 > /dev/null"

  $ sleep 1

  $ R "ba-cli -j -l 'GenericNetworkInterface.Interface.$InstanceId.?' | sed '/^$/d' | jsonfilter -e @[0]'[*].Status'"
  NotPresent

Clean-up, Delete IP interface and Generic Network Interface:

  $ R "ba-cli -l IP.Interface.$IPInstanceId.- | sed '/^$/d'"
  IP.Interface.\d+. (re)
  IP.Interface.\d+.Stats. (re)
  IP.Interface.\d+.X_PRPLWARE-COM_IPv4Config. (re)
  IP.Interface.\d+.X_PRPLWARE-COM_IPv6Config. (re)
  IP.Interface.\d+.IPv4Address. (re)
  IP.Interface.\d+.IPv6Address. (re)
  IP.Interface.\d+.IPv6Address.\d+. (re)
  IP.Interface.\d+.IPv6Prefix. (re)
  IP.Interface.\d+.IPv6Prefix.\d+. (re)

  $ R "ba-cli -l -j 'GenericNetworkInterface.Interface.$InstanceId._del()' |  sed '/^$/d' | tail -n 1"
  \[\["GenericNetworkInterface.Interface.\d+.","GenericNetworkInterface.Interface.\d+.Stats."\]\] (re)

  $ R logger -t cram "Generice Network Interface IPv6 test finished"