Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Get initial state of bridges:

  $ R "brctl show | sort | cut -d$'\t' -f1,4-"
  br-guest\tno (esc)
  br-lan\tno\t\teth0 (esc)
  bridge name\tSTP enabled\tinterfaces (esc)

Add eth1 to the Guest bridge:

  $ printf ' \
  > ubus-cli Bridging.Bridge.guest.Port.+{Name="eth1", Alias="ETH1"}\n
  > ubus-cli Bridging.Bridge.guest.Port.ETH1.Enable=1\n
  > ' > /tmp/run
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/run)'" > /dev/null
  $ sleep 5

Check that eth1 is added to br-guest bridge:

  $ R "brctl show | sort | cut -d$'\t' -f1,4-"
  br-guest\tno\t\teth1 (esc)
  br-lan\tno\t\teth0 (esc)
  bridge name\tSTP enabled\tinterfaces (esc)

Remove eth1 from the Guest bridge:

  $ printf '\
  > ubus-cli Bridging.Bridge.guest.Port.ETH1-\n
  > ' > /tmp/run
  $ script --command "ssh -t root@$TARGET_LAN_IP '$(cat /tmp/run)'" > /dev/null
  $ sleep 5

Check for initial state of bridges again:

  $ R "brctl show | sort | cut -d$'\t' -f1,4-"
  br-guest\tno (esc)
  br-lan\tno\t\teth0 (esc)
  bridge name\tSTP enabled\tinterfaces (esc)
