Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Get initial state of bridges:

  $ R "brctl show | cut -d$'\t' -f1,4-"
  bridge name\tSTP enabled\tinterfaces (esc)
  br-guest\tno\t\t (esc)
  br-lan\tno\t\teth0_1 (esc)
  \t\t\t\t\teth0_2 (esc)
  \t\t\t\t\teth0_3 (esc)
  \t\t\t\t\teth0_4 (esc)

Remove eth0_1 from LAN bridge and add it to the Guest bridge:

  $ printf ' \
  > ubus-cli Bridging.Bridge.lan.Port.ETH0_1-\n
  > ubus-cli Bridging.Bridge.guest.Port.+{Name="eth0_1", Alias="ETH0_1"}\n
  > ubus-cli Bridging.Bridge.guest.Port.ETH0_1.Enable=1\n
  > ' > /tmp/run
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/run)'" > /dev/null
  $ sleep 10

Check that eth0_1 is added to Guest bridge:

  $ R "brctl show | cut -d$'\t' -f1,4-"
  bridge name\tSTP enabled\tinterfaces (esc)
  br-guest\tno\t\teth0_1 (esc)
  br-lan\tno\t\teth0_2 (esc)
  \t\t\t\t\teth0_3 (esc)
  \t\t\t\t\teth0_4 (esc)

Remove eth0_1 from the Guest bridge and add it back to the LAN bridge:

  $ printf '\
  > ubus-cli Bridging.Bridge.guest.Port.ETH0_1-\n
  > ubus-cli Bridging.Bridge.lan.Port.+{Name="eth0_1", Alias="ETH0_1"}\n
  > ubus-cli Bridging.Bridge.lan.Port.ETH0_1.Enable=1\n
  > ' > /tmp/run
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/run)'" > /dev/null
  $ sleep 10

Check for initial state of bridges again:

  $ R "brctl show | cut -d$'\t' -f1,4-"
  bridge name\tSTP enabled\tinterfaces (esc)
  br-guest\tno\t\t (esc)
  br-lan\tno\t\teth0_1 (esc)
  \t\t\t\t\teth0_2 (esc)
  \t\t\t\t\teth0_3 (esc)
  \t\t\t\t\teth0_4 (esc)
