Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check PCP root datamodel:

  $ R "ubus -S call PCP _get"
  {"PCP.":{"OptionList":"1,3","PreferredVersion":2,"SupportedVersions":"0,1,2","Debug":false,"ClientNumberOfEntries":0}}

Add Client:

  $ R "ubus -S call PCP.Client _add '{\"parameters\":{\"WANInterface\":\"Device.IP.Interface.2.\"}}'" ; sleep 2
  {"object":"PCP.Client.cpe-Client-1.","index":1,"name":"cpe-Client-1","parameters":{"Alias":"cpe-Client-1"},"path":"PCP.Client.1."}

Check Client parameters:

  $ R "ubus call PCP.Client.1 _get | jsonfilter -e @[*].WANInterface -e @[*].Status | sort"
  Device.IP.Interface.2.
  Disabled

Add Server:

  $ R "ubus -S call PCP.Client.1.Server _add '{\"parameters\":{\"Origin\":\"DHCPv6\"}}'" ; sleep 2
  {"object":"PCP.Client.cpe-Client-1.Server.cpe-Server-1.","index":1,"name":"cpe-Server-1","parameters":{"Alias":"cpe-Server-1"},"path":"PCP.Client.1.Server.1."}

Check Server parameters:

  $ R "ubus call PCP.Client.1.Server.1 _get | jsonfilter -e @[*].Status -e @[*].Origin | sort"
  DHCPv6
  Disabled
