Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Get initial state of bridges:

  $ R "brctl show | sort | cut -d$'\t' -f1,4-"
  \t\t\t\t\tlan1 (esc)
  \t\t\t\t\tlan2 (esc)
  \t\t\t\t\tlan3 (esc)
  \t\t\t\t\tlan4 (esc)
  br-guest\tno (esc)
  br-lan\tno\t\tlan0 (esc)
  bridge name\tSTP enabled\tinterfaces (esc)

Remove lan4 from LAN bridge and add it to the Guest bridge:

  $ printf ' \
  > ubus-cli Bridging.Bridge.lan.Port.eth_port4-\n
  > ubus-cli Bridging.Bridge.guest.Port.+{Name="lan4", Alias="eth_port4", LowerLayers="Device.Ethernet.Interface.6."}\n
  > ubus-cli Bridging.Bridge.guest.Port.eth_port4.Enable=1\n
  > ' > /tmp/run
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/run)'" > /dev/null
  $ sleep 5

Check that lan4 is added to Guest bridge:

  $ R "brctl show | sort | cut -d$'\t' -f1,4-"
  \t\t\t\t\tlan1 (esc)
  \t\t\t\t\tlan2 (esc)
  \t\t\t\t\tlan3 (esc)
  br-guest\tno\t\tlan4 (esc)
  br-lan\tno\t\tlan0 (esc)
  bridge name\tSTP enabled\tinterfaces (esc)

Remove lan4 from the Guest bridge and add it back to the LAN bridge:

  $ printf '\
  > ubus-cli Bridging.Bridge.guest.Port.eth_port4-\n
  > ubus-cli Bridging.Bridge.lan.Port.+{Name="lan4", Alias="eth_port4", LowerLayers="Device.Ethernet.Interface.6."}\n
  > ubus-cli Bridging.Bridge.lan.Port.eth_port4.Enable=1\n
  > ' > /tmp/run
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/run)'" > /dev/null
  $ sleep 5

Check for initial state of bridges again:

  $ R "brctl show | sort | cut -d$'\t' -f1,4-"
  \t\t\t\t\tlan1 (esc)
  \t\t\t\t\tlan2 (esc)
  \t\t\t\t\tlan3 (esc)
  \t\t\t\t\tlan4 (esc)
  br-guest\tno (esc)
  br-lan\tno\t\tlan0 (esc)
  bridge name\tSTP enabled\tinterfaces (esc)
