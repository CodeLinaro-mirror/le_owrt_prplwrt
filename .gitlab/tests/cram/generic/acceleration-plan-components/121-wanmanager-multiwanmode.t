Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

If test is running on a Mozart, Turris, OSPv1 or Haze, lets skip the test as there is no USB storage device attached:

  $ if echo "$CI_JOB_NAME" | grep -q -E "(Mozart|Turris|Haze|HDK-3)"; then exit 80; fi

Create helper functions:

  $ check_ipv4() { R "i=60 ; while [ \$i -gt 1 ]; do (ip -4 a show dev ${1} | grep -q 'inet ') && break; i=\$(( i-1 )); sleep 1 ; done";}

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

Change Cellular_IPv4 WANMode to prepare for two active WANModes at same time:

  $ R "ba-cli -ajl 'WANManager.WAN.Cellular_IPv4.Intf.1.Name=wan-cellular' | awk NF"
  [{"WANManager.WAN.9.Intf.1.":{"Name":"wan-cellular"}}]

  $ R 'ba-cli -al WANManager.WAN.Cellular_IPv4.Intf.1.DefaultRouteReference="Device.Routing.Router.1.IPv4Forwarding.1." | awk NF'
  Device.Routing.Router.1.IPv4Forwarding.1.

Set ForwardingMetric for Cellular IPv4 route

  $ R "ba-cli -al 'Routing.Router.1.IPv4Forwarding.1.ForwardingMetric=30' | awk NF"
  30

Set Cellular_IPv4 WANMode:

  $ R "ba-cli -ajl 'WANManager.setWANMode(WANMode = Cellular_IPv4)' | awk NF"
  WANManager.setWANMode() returned
  [{"status":1}]

Wait for IPv4 Adresses on wwan0 interface (timeout of 60 seconds):

  $ check_ipv4 "wwan0"

Check IPv4 Address is actually set on wwan0 interface (check times out after 60 seconds but no guarantee that ip is obtained);

  $ R "ip a s wwan0 | grep -w inet"
  .*inet ((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}\/[0-9]+.*wwan0 (re)

Add IPv4 Default route for secondary WANMode (demo_wanmode) and save it:

  $ R 'ba-cli -al Device.Routing.Router.1.IPv4Forwarding.+{Interface="Device.IP.Interface.2.",Enable=1, ForwardingMetric=10} | awk NF > /tmp/new_route'

Check new route is saved correctly:

  $ R 'cat /tmp/new_route'
  cpe-IPv4Forwarding-[0-9]+ (re)

Set New Default Route on demo_wanmode:

  $ R 'ba-cli -al WANManager.WAN.demo_wanmode.Intf.1.DefaultRouteReference=$(ba-cli -a "Device.Routing.Router.1.IPv4Forwarding.$(cat /tmp/new_route).?" | grep -v "> " | head -n 1) | awk NF'
  Device.Routing.Router.1.IPv4Forwarding.[0-9]+. (re)

Enable demo_wanmode:

  $ R "ba-cli -ajl 'WANManager.WANModeEnable(WANMode = demo_wanmode)' | awk NF"
  WANManager.WANModeEnable() returned
  [{"status":1}]

Wait for IPv4 Adresses on wan interface (timeout of 60 seconds):

  $ check_ipv4 $(echo $WAN_INTF)

Make sure the IPv4 default route on wwan0 interface is set with metric 30:

  $ R "ip r | grep default | grep wwan0 | grep 'metric 30' | wc -l"
  1

Make sure the IPv4 default route on wan interface is set with metric 10:

  $ R "ip r | grep default | grep $(echo $WAN_INTF) | grep 'metric 10' | wc -l"
  1

Cleanup:

  $ R 'ba-cli -al Routing.Router.1.IPv4Forwarding.1.ForwardingMetric=-1 | awk NF'
  -1

  $ R 'ba-cli -a "Device.Routing.Router.1.IPv4Forwarding.$(cat /tmp/new_route).-" | grep -v "> " | awk NF'
  Device.Routing.Router.1.IPv4Forwarding.[0-9]+. (re)

  $ R 'ba-cli -al WANManager.WAN.demo_wanmode.Intf.1.DefaultRouteReference="Device.Routing.Router.1.IPv4Forwarding.1." | awk NF'
  Device.Routing.Router.1.IPv4Forwarding.1.

  $ R "ba-cli -ajl 'WANManager.setWANMode(WANMode = demo_wanmode)' | awk NF"
  WANManager.setWANMode() returned
  [{"status":1}]

  $ R "ba-cli -ajl 'WANManager.Reset()' | awk NF"
  WANManager.Reset() returned
  [""]

  $ R "ba-cli -ajl 'WANManager.WAN.Cellular_IPv4.Intf.1.Name=wan' | awk NF"
  [{"WANManager.WAN.9.Intf.1.":{"Name":"wan"}}]

  $ R "rm -f /tmp/new_route"
