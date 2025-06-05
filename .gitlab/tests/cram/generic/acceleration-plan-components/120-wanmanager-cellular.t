Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

If test is running on a Mozart, Turris, OSPv1 or Haze, lets skip the test as there is no USB storage device attached:

  $ if echo "$CI_JOB_NAME" | grep -q -E "(Mozart|Turris|Haze|HDK-3)"; then exit 80; fi

Create helper functions:

  $ check_ips() { R "i=60 ; while [ \$i -gt 1 ]; do (ip -4 a show dev ${1} | grep -q 'inet ' && ip -6 a show dev ${1} | grep -q 'inet6 fe80::' && ip -6 a show dev ${1} | grep -q 'inet6 2') && break; i=\$(( i-1 )); sleep 1 ; done";}

Create alias for wan interface:

  $ export WAN_INTF=$(if echo "$CI_JOB_NAME" | grep -q -E "Freedom"; then echo "wan"; else echo "eth1"; fi)

Make sure WANManager is registered in the Datamodel:

  $ R "ba-cli -ajl WANManager.?1"| jq -r '.[0] | keys[0]'
  WANManager.

Make sure a Modem is found:

  $ R "mmcli -L | head -n 1"
  .*\/org\/freedesktop\/ModemManager[0-9]\/Modem\/[0-9]+.+ (re)

Make sure a Cellular Interface is present in the Cellular DM:

  $ R "ba-cli -al Cellular.InterfaceNumberOfEntries? | awk NF"
  .*[1-9][0-9]*.* (re)

Set Cellular WANMode:

  $ R "ba-cli -ajl 'WANManager.setWANMode(WANMode = Cellular)' | awk NF"
  WANManager.setWANMode() returned
  [{"status":1}]

Wait for IP Adresses on wwan0 interface (timeout of 60 seconds):

  $ check_ips "wwan0"

Check IPv4 Address is actually set on wwan0 interface (check times out after 60 seconds but no guarantee that ip is obtained);

  $ R "ip a s wwan0 | grep -w inet"
  .*inet ((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}\/[0-9]+.*wwan0 (re)

Check IPv6 GUA and LLA Address is set on wwan0 interface (check times out after 60 seconds but no guarantee that ip is obtained);

  $ R "ip a s wwan0 | grep -w inet6"
  .*inet6 [0-9a-f:]+\/[0-9]+ scope global.* (re)
  .*inet6 [0-9a-f:]+\/[0-9]+ scope link.* (re)

Check datamodel parameters:

  $ R "ba-cli -al Routing.Router.1.IPv4Forwarding.1.Origin? | awk NF"
  3GPP-NAS

  $ R "ba-cli -al Routing.Router.1.IPv4Forwarding.1.Interface? | awk NF"
  Device.IP.Interface.12

  $ R "ba-cli -al Logical.Interface.1.LowerLayers? | awk NF"
  Device.IP.Interface.12.

  $ R "ba-cli -al IP.Interface.12.IPv4Address.1.AddressingType? | awk NF"
  3GPP-NAS

  $ R "ba-cli -al IP.Interface.12.IPv4Address.1.Enable? | awk NF"
  1

Check IPv4 Address is set on wwan0 interface:

  $ R "ip a s wwan0 | grep -w inet"
  .*inet ((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}\/[0-9]+.*wwan0 (re)

Check IPv6 GUA and LLA Address is set on wwan0 interface:

  $ R "ip a s wwan0 | grep -w inet6"
  .*inet6 [0-9a-f:]+\/[0-9]+ scope global.* (re)
  .*inet6 [0-9a-f:]+\/[0-9]+ scope link.* (re)

Make sure there is only 1 IPv4 default route on wwan0 interface:

  $ R "ip r | grep default | grep wwan0"
  .*default via ((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4} dev wwan0 proto static mtu [0-9]+.* (re)

Next to the IPv4 default route there should be a route defined that uses wwan0:

  $ R "ip r | grep 'dev wwan0'"
  .*default via ((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4} dev wwan0 proto static mtu [0-9]+.* (re)
  .*((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}\/[0-9]+ dev wwan0 proto kernel scope link src ((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}.* (re)

Make sure there is only 1 IPv6 default route on wwan0 interface:

  $ R "ip -6 r | grep wwan0 | grep default"
  .*default via [0-9a-f:]+ dev wwan0.* (re)

Next to the IPv6 default route there should be a route for LLA and GUA Address:

  $ R "ip -6 r | grep 'dev wwan0'"
  .*[0-9a-f:]+\/[0-9]+ dev wwan0.* (re)
  .*[0-9a-f:]+\/[0-9]+ dev wwan0.* (re)
  default via [0-9a-f:]+ dev wwan0 (re)

Disable Cellular.Interface:

  $ R "ba-cli -ajl 'Cellular.Interface.1.Enable=0' | awk NF"
  [{"Cellular.Interface.1.":{"Enable":0}}]

Check Cellular.Interface DM is cleared and Status is Down:

  $ R "ba-cli -al Cellular.Interface.1.Status? | awk NF"
  Down

  $ R "echo protected\; Cellular.Interface.1.Bearer.InternalName? | xargs ba-cli -a | grep -v '> ' | awk NF"
  Cellular.Interface.1.Bearer.InternalName=""

  $ R "echo protected\; Cellular.Interface.1.Bearer.DNSServers? | xargs ba-cli -a | grep -v '> ' | awk NF"
  Cellular.Interface.1.Bearer.DNSServers=""

  $ R "echo protected\; Cellular.Interface.1.Bearer.IPv4.? | xargs ba-cli -a | grep -v '> ' | awk NF"
  Cellular.Interface.1.Bearer.IPv4.
  Cellular.Interface.1.Bearer.IPv4.Address=""
  Cellular.Interface.1.Bearer.IPv4.GatewayIPAddress=""
  Cellular.Interface.1.Bearer.IPv4.MTU=0
  Cellular.Interface.1.Bearer.IPv4.Method="Unknown"
  Cellular.Interface.1.Bearer.IPv4.SubnetMask=""

  $ R "echo protected\; Cellular.Interface.1.Bearer.IPv6.? | xargs ba-cli -a | grep -v '> ' | awk NF"
  Cellular.Interface.1.Bearer.IPv6.
  Cellular.Interface.1.Bearer.IPv6.Address=""
  Cellular.Interface.1.Bearer.IPv6.MTU=0
  Cellular.Interface.1.Bearer.IPv6.Method="Unknown"
  Cellular.Interface.1.Bearer.IPv6.NextHop=""
  Cellular.Interface.1.Bearer.IPv6.Prefix=""

Enable Cellular.Interface:

  $ R "ba-cli -ajl 'Cellular.Interface.1.Enable=1' | awk NF"
  [{"Cellular.Interface.1.":{"Enable":1}}]

Check Cellular.Interface DM is set correctly:

  $ R "echo protected\; Cellular.Interface.1.Bearer.IPv6.Method? | xargs ba-cli -a | grep -v '> ' | awk NF"
  Cellular.Interface.1.Bearer.IPv6.Method="Static"

  $ R "echo protected\; Cellular.Interface.1.Bearer.IPv4.Method? | xargs ba-cli -a | grep -v '> ' | awk NF"
  Cellular.Interface.1.Bearer.IPv4.Method="Static"

  $ R "echo protected\; Cellular.Interface.1.Bearer.InternalName? | xargs ba-cli -a | grep -v '> ' | awk NF"
  Cellular\.Interface\.1\.Bearer\.InternalName="\/org\/freedesktop\/ModemManager[0-9]\/Bearer\/[0-9]+" (re)

Wait for IP Adresses on wwan0 interface (timeout of 60 seconds):

  $ check_ips "wwan0"

Check IPv4 Address is actually set on wwan0 interface (check times out after 60 seconds but no guarantee that ip is obtained);

  $ R "ip a s wwan0 | grep -w inet"
  .*inet ((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}\/[0-9]+.*wwan0 (re)

Check IPv6 GUA and LLA Address is set on wwan0 interface (check times out after 60 seconds but no guarantee that ip is obtained);

  $ R "ip a s wwan0 | grep -w inet6"
  .*inet6 [0-9a-f:]+\/[0-9]+ scope global.* (re)
  .*inet6 [0-9a-f:]+\/[0-9]+ scope link.* (re)

Cleanup: Change WANMode back to default:

  $ R "ba-cli -ajl 'WANManager.setWANMode(WANMode = demo_wanmode)' | awk NF"
  WANManager.setWANMode() returned
  [{"status":1}]

Wait for IP Adresses on wan interface (timeout of 60 seconds):

  $ check_ips $(echo $WAN_INTF)
