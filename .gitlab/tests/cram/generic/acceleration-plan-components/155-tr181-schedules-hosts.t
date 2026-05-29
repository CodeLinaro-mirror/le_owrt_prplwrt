Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that Hosts and Schedules datamodels are available:

  $ R "ba-cli -lj Device.Hosts.AccessControlNumberOfEntries?" | jq .
  [
    {
      "Device.Hosts.": {
        "AccessControlNumberOfEntries": \d+ (re)
      }
    }
  ]

  $ R "ba-cli -lj Device.Schedules.ScheduleNumberOfEntries?" | jq .
  [
    {
      "Device.Schedules.": {
        "ScheduleNumberOfEntries": \d+ (re)
      }
    }
  ]

Create an AccessControl entry:

  $ R "ba-cli 'Device.Hosts.AccessControl.+{Alias=\"test-access-control\"}'" > /dev/null 2>&1
  $ AC_PATH="Device.Hosts.AccessControl.test-access-control"

Check AccessControl initial state:

  $ R "ba-cli -lj ${AC_PATH}.?" | jq .
  [
    {
      "*": { (glob)
        "PhysAddressMask": "FF:FF:FF:FF:FF:FF",
        "AccessPolicy": "Allow",
        "ScheduleNumberOfEntries": 0,
        "Enable": 0,
        "ScheduleRef": "",
        "Origin": "User",
        "HostName": "",
        "Alias": "test-access-control",
        "PhysAddress": ""
      }
    }
  ]

Find the LAN test device in Hosts datamodel:

  $ R "ba-cli Device.Hosts.HostNumberOfEntries?" | grep -Ev '^(>|$)'
  Device.Hosts.HostNumberOfEntries=\d+ (re)

Get our LAN IP address from the LAN interface:

  $ MY_IP=$(ip -4 addr show $TESTBED_LAN_INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)

Get MAC address of this LAN test device from Hosts datamodel:

  $ HOST_MAC=$(R "ba-cli 'Device.Hosts.Host.[IPAddress==\"${MY_IP}\"].PhysAddress?' | grep -Ev '^(>|$)' | grep -v '^root' | grep -v '^$' | head -1 | cut -d'=' -f2 | tr -d '\"'" 2>/dev/null)

Set PhysAddress for the AccessControl using the discovered MAC:

  $ R "ba-cli ${AC_PATH}.PhysAddress='${HOST_MAC}'" > /dev/null 2>&1
  $ R "ba-cli ${AC_PATH}.PhysAddress?" | grep -Ev '^(>|$)'
  Device.Hosts.AccessControl.*.PhysAddress="([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}" (re)

Verify baseline connectivity before access control:

  $ R "iptables -L FORWARD_Hosts_Block -n | grep -ic ${HOST_MAC}"
  0
  [1]

Create a schedule for working hours:

  $ R "ba-cli 'Device.Schedules.Schedule.+{Alias=\"full\",Day=\"Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday\",Duration=86400,Enable=1,Description=\"Schedule active everytime\"}'" > /dev/null 2>&1

Get the Schedule instance path:

  $ SCHED_INSTANCE=$(R "ba-cli 'Device.Schedules.Schedule.[Alias==\"full\"].?'" | awk -F'.' '/^Device\.Schedules\.Schedule\.[0-9]+\./{print $4; exit}')
  $ SCHED_PATH="Device.Schedules.Schedule.${SCHED_INSTANCE}"

Link the schedule to AccessControl via ScheduleRef:

  $ R "ba-cli ${AC_PATH}.ScheduleRef='${SCHED_PATH}'" > /dev/null 2>&1

Verify ScheduleRef is set:

  $ R "ba-cli ${AC_PATH}.ScheduleRef?" | grep -Ev '^(>|$)'
  Device.Hosts.AccessControl.*.ScheduleRef="Device.Schedules.Schedule.*" (glob)

Enable the AccessControl:

  $ R "ba-cli ${AC_PATH}.Enable=1" > /dev/null 2>&1

Verify AccessControl is enabled with schedule:

  $ R "ba-cli -lj ${AC_PATH}.?" | jq 'del(.[0][].ScheduleNumberOfEntries)' | jq .
  [
    {
      "*": { (glob)
        "PhysAddressMask": "FF:FF:FF:FF:FF:FF",
        "AccessPolicy": "Allow",
        "Enable": 1,
        "ScheduleRef": "Device.Schedules.Schedule.*", (glob)
        "Origin": "User",
        "HostName": "",
        "Alias": "test-access-control",
        "PhysAddress": "([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}" (re)
      }
    }
  ]

Check Schedule status:

  $ R "ba-cli ${SCHED_PATH}.Status?" | grep -Ev '^(>|$)'
  Device.Schedules.Schedule.*.Status="Active" (glob)

Check Schedule TimeLeft:

  $ TIMELEFT=$(R "ba-cli ${SCHED_PATH}.TimeLeft?" | grep -Ev '^(>|$)' | cut -d= -f2)
  $ [ ${TIMELEFT} -ge 0 ]

Test connectivity with AccessControl and Schedule enabled:

  $ R "iptables -L FORWARD_Hosts_Block -n | grep -ic ${HOST_MAC}"
  0
  [1]

Test InverseMode effect on schedule and access:

  $ INITIAL_STATUS=$(R "ba-cli ${SCHED_PATH}.Status?" | grep -Ev '^(>|$)' | cut -d= -f2 | tr -d '"')
  $ R "ba-cli ${SCHED_PATH}.InverseMode=1" > /dev/null 2>&1
  $ sleep 5
  $ INVERSE_STATUS=$(R "ba-cli ${SCHED_PATH}.Status?" | grep -Ev '^(>|$)' | cut -d= -f2 | tr -d '"')
  $ [ "${INITIAL_STATUS}" != "${INVERSE_STATUS}" ]

Test ping after InverseMode enabled (should be blocked):

  $ R "iptables -L FORWARD_Hosts_Block -n | grep -ic ${HOST_MAC}"
  1

Reset InverseMode and verify connectivity restored:

  $ sleep 5
  $ R "ba-cli ${SCHED_PATH}.InverseMode=0" > /dev/null 2>&1
  $ sleep 5

  $ R "iptables -L FORWARD_Hosts_Block -n | grep -ic ${HOST_MAC}"
  0
  [1]

Change AccessPolicy to Deny and test:

  $ R "ba-cli ${AC_PATH}.AccessPolicy=Deny" > /dev/null 2>&1
  $ R "ba-cli ${AC_PATH}.AccessPolicy?" | grep -Ev '^(>|$)'
  Device.Hosts.AccessControl.*.AccessPolicy="Deny" (glob)
  $ sleep 5

Test ping with Deny policy during schedule active time:

  $ R "iptables -L FORWARD_Hosts_Block -n | grep -ic ${HOST_MAC}"
  1

Reset AccessPolicy back to Allow:

  $ sleep 5
  $ R "ba-cli ${AC_PATH}.AccessPolicy=Allow" > /dev/null 2>&1

Delete the schedule and verify cleanup:

  $ R "ba-cli '${SCHED_PATH}.-'" > /dev/null 2>&1

Verify ScheduleRef is cleared in AccessControl:

  $ R "ba-cli ${AC_PATH}.ScheduleRef?" | grep -Ev '^(>|$)'
  Device.Hosts.AccessControl.*.ScheduleRef="" (glob)

Verify ScheduleNumberOfEntries is back to 0:

  $ R "ba-cli Device.Schedules.ScheduleNumberOfEntries?" | grep -Ev '^(>|$)'
  Device.Schedules.ScheduleNumberOfEntries=0

Cleanup - Delete the AccessControl entry:

  $ R "ba-cli '${AC_PATH}.-'" > /dev/null 2>&1

Verify AccessControlNumberOfEntries is decremented:

  $ R "ba-cli Device.Hosts.AccessControlNumberOfEntries?" | grep -Ev '^(>|$)'
  Device.Hosts.AccessControlNumberOfEntries=0

Test if connectivity is back:

  $ R "iptables -L FORWARD_Hosts_Block -n | grep -ic ${HOST_MAC}"
  0
  [1]
