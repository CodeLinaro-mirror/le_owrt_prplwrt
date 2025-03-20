Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check DHCPv6Client root datamodel:

  $ R "ba-cli 'DHCPv6Client._get()' | grep -v '>'"
  DHCPv6Client._get() returned
  [
      {
          DHCPv6Client. = {
              ClientNumberOfEntries = [0-9]+, (re)
              ClientSupportedControllers = "mod-odhcp6c",
              SupportedFWControllers = "mod-fw-amx"
          }
      }
  ]
  

Get initial values of Renew and Reply parameters in datamodel:

  $ initial_renew=$(R "ba-cli 'DHCPv6Client.Client.wan.Stats.Renew?' | grep '=' | sed 's/.*=//'")
  $ initial_reply=$(R "ba-cli 'DHCPv6Client.Client.wan.Stats.Reply?' | grep '=' | sed 's/.*=//'")

Send Renew command:

  $ R "ba-cli 'DHCPv6Client.Client.wan.Renew=1' | grep -v '>' | grep 'DHCPv6Client'"
  DHCPv6Client.Client.1.
  DHCPv6Client.Client.1.Renew=1

Get final values of Renew and Reply parameters in datamodel:

  $ final_renew=$(R "ba-cli 'DHCPv6Client.Client.wan.Stats.Renew?' | grep '=' | sed 's/.*=//'")
  $ final_reply=$(R "ba-cli 'DHCPv6Client.Client.wan.Stats.Reply?' | grep '=' | sed 's/.*=//'")

  $ sleep 5

Check if Stats have changed by comparing initial and final stats:

  $ stats_has_changed=true

  $ if [ "$initial_renew" -eq "$final_renew" ] || [ "$initial_reply" -eq "$final_reply" ]; then
  >   stats_has_changed=false
  > fi

  $ if [ "$stats_has_changed" = true ]; then
  >   echo "Stats has changed"
  > else
  >   echo "Stats didn't changed, initial_renew=$initial_renew, final_renew=$final_renew, initial_reply=$initial_reply, final_reply=$final_reply"
  > fi
  Stats has changed
