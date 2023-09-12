Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Get initial state of bridges:

  $ R "brctl show | grep -E '(br-lan|br-guest)' | sort | cut -d$'\t' -f1,6" | tr '\t' ' '
  br-guest wlan0.2
  br-lan eth0_(1|2|3|4|5) (re)

Remove eth0_1 from LAN bridge and add it to the Guest bridge:

  $ printf ' \
  > ubus-cli Bridging.Bridge.lan.Port.ETH0_1-\n
  > ubus-cli Bridging.Bridge.guest.Port.+{Name="eth0_1", Alias="ETH0_1", LowerLayers="Device.Ethernet.Interface.2."}\n
  > ubus-cli Bridging.Bridge.guest.Port.ETH0_1.Enable=1\n
  > ' > /tmp/run
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/run)'" > /dev/null
  $ sleep 10

Check that eth0_1 is added to Guest bridge:

  $ R "brctl show | grep -E '(br-lan|br-guest)' | sort | cut -d$'\t' -f1,6" | tr '\t' ' '
  br-guest eth0_1
  br-lan eth0_(2|3|4|5) (re)

Remove eth0_1 from the Guest bridge and add it back to the LAN bridge:

  $ printf '\
  > ubus-cli Bridging.Bridge.guest.Port.ETH0_1-\n
  > ubus-cli Bridging.Bridge.lan.Port.+{Name="eth0_1", Alias="ETH0_1", LowerLayers="Device.Ethernet.Interface.2."}\n
  > ubus-cli Bridging.Bridge.lan.Port.ETH0_1.Enable=1\n
  > ' > /tmp/run
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/run)'" > /dev/null
  $ sleep 20

Check for initial state of bridges again:

  $ R "brctl show | grep -E '(br-lan|br-guest)' | sort | cut -d$'\t' -f1,6" | tr '\t' ' '
  br-guest wlan0.2
  br-lan eth0_(1|2|3|4|5) (re)
