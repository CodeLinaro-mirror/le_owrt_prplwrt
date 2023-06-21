Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Get initial state of bridges:

  $ R "brctl show | grep -E '(br-lan|br-guest)' | sort | cut -d$'\t' -f1,6" | tr '\t' ' '
  br-guest 
  br-lan lan(1|2|3) (re)

Remove lan1 from LAN bridge and add it to the Guest bridge:

  $ printf ' \
  > ubus-cli Bridging.Bridge.lan.Port.eth_port1-\n
  > ubus-cli Bridging.Bridge.guest.Port.+{Name="LAN1", Alias="eth_port1", LowerLayers="Device.Ethernet.Interface.2."}\n
  > ubus-cli Bridging.Bridge.guest.Port.eth_port1.Enable=1\n
  > ' > /tmp/run
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/run)'" > /dev/null
  $ sleep 5

Check that lan1 is added to Guest bridge:

  $ R "brctl show | grep -E '(br-lan|br-guest)' | sort | cut -d$'\t' -f1,6" | tr '\t' ' '
  br-guest lan1
  br-lan lan(2|3) (re)

Remove lan1 from the Guest bridge and add it back to the LAN bridge:

  $ printf '\
  > ubus-cli Bridging.Bridge.guest.Port.eth_port1-\n
  > ubus-cli Bridging.Bridge.lan.Port.+{Name="LAN1", Alias="eth_port1", LowerLayers="Device.Ethernet.Interface.2."}\n
  > ubus-cli Bridging.Bridge.lan.Port.eth_port1.Enable=1\n
  > ' > /tmp/run
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/run)'" > /dev/null
  $ sleep 5

Check for initial state of bridges again:

  $ R "brctl show | grep -E '(br-lan|br-guest)' | sort | cut -d$'\t' -f1,6" | tr '\t' ' '
  br-guest 
  br-lan lan(1|2|3) (re)
