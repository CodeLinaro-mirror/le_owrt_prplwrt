Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check PCP root datamodel:

  $ R "ba-cli -l 'PCP.Enable?;PCP.OptionList?;PCP.PreferredVersion?;PCP.SupportedVersions?;PCP.Debug?;PCP.ClientNumberOfEntries?' | grep -v '^$'"
  1
  1,3
  2
  0,1,2
  false
  false

Add Client:

  $ R "ubus-cli PCP.Client+{WANInterface = \"Device.Logical.Interface.1.\"}" > /dev/null; sleep 2

Check Client parameters:

  $ R "ba-cli -l 'PCP.Client.2.WANInterface?;PCP.Client.2.Status?' | grep -v '^$' | sort"
  Device.Logical.Interface.1.
  StackDisabled

Add Server:

  $ R "ubus-cli PCP.Client.2.Server+{Origin = \"DHCPv6\"}" > /dev/null; sleep 2

Check Server parameters:

  $ R "ba-cli -l 'PCP.Client.2.Server.1.Status?;PCP.Client.2.Server.1.Origin?' | grep -v '^$' | sort"
  DHCPv6
  Disabled
