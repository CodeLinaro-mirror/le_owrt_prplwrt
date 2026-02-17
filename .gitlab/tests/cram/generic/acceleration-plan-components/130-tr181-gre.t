Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check GRE root datamodel:

  $ R "ubus -S call GRE _get"
  {"GRE.":{"FilterNumberOfEntries":0,"TunnelNumberOfEntries":0}}
  {}
  {"amxd-error-code":0}

Make sure we start with no custom GRE devices:

  $ R "ip link show | grep \"gre.*-t.*\""

Create a GRE tunnel instance with invalid configuration:

  $ R "ba-cli 'GRE.Tunnel.+{Alias=\"test_tunnel\", Enable=1, DeliveryHeaderProtocol=\"IPv6\", RemoteEndpoints=\"203.0.113.5\"}'" > /dev/null 2>&1
  $ R "ba-cli 'GRE.Tunnel.test_tunnel.Status?'" | tail -n 2
  GRE.Tunnel.1.Status="Error"

Provide valid tunnel configuration:

  $ R "ba-cli 'GRE.Tunnel.test_tunnel.DeliveryHeaderProtocol=\"IPv4\"'" > /dev/null 2>&1
  $ R "ba-cli 'GRE.Tunnel.test_tunnel.Status?'" | tail -n 2
  GRE.Tunnel.1.Status="Enabled"

Create underlying traffic flow:

  $ R "ba-cli 'GRE.Tunnel.test_tunnel.Interface.+{Alias=\"test_interface\", Enable=1}'" > /dev/null 2>&1
  $ R "ba-cli 'GRE.Tunnel.test_tunnel.Interface.test_interface.Name?'" | tail -n 2
  GRE.Tunnel.1.Interface.1.Name="gre1-t1"
  $ R "ba-cli 'GRE.Tunnel.test_tunnel.Interface.test_interface.Status?'" | tail -n 2
  GRE.Tunnel.1.Interface.1.Status="Unknown"

Ensure GRE device is created:

  $ R "ip link show | grep \"gre.*-t.*\" | sed 's/^[0-9]*: //'"
  gre1-t1@NONE: <POINTOPOINT,NOARP,UP,LOWER_UP> mtu 1476 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000

Check DSCP marking rule:

  $ R "iptables -t mangle -L POSTROUTING_class | grep 'DSCP set'"
  DSCP       gre  --  anywhere             anywhere             DSCP set 0x00

Update default DSCP mark and track it in the created marking rule:

  $ R "ba-cli 'GRE.Tunnel.test_tunnel.DefaultDSCPMark=23'" > /dev/null 2>&1
  $ R "iptables -t mangle -L POSTROUTING_class | grep 'DSCP set'"
  DSCP       gre  --  anywhere             anywhere             DSCP set 0x17

Create GRE filter and apply it to the traffic flow we just created:

  $ R "ba-cli 'GRE.Filter.+{Alias=\"test_filter\", Enable=1, Interface=\"GRE.Tunnel.1.Interface.1.\", DSCPMarkPolicy=47}'" > /dev/null 2>&1
  $ R "iptables -t mangle -L POSTROUTING_class | grep 'DSCP set'"
  DSCP       gre  --  anywhere             anywhere             DSCP set 0x2f

Ensure DSCP mark falls back to default value when filter is disabled:

  $ R "ba-cli 'GRE.Filter.test_filter.Enable=0'" > /dev/null 2>&1
  $ R "iptables -t mangle -L POSTROUTING_class | grep 'DSCP set'"
  DSCP       gre  --  anywhere             anywhere             DSCP set 0x17

Create a second interface:

  $ R "ba-cli 'GRE.Tunnel.test_tunnel.Interface.+{Alias=\"test_interface2\", Enable=1}'" > /dev/null 2>&1
  $ R "ba-cli 'GRE.Tunnel.test_tunnel.Interface.test_interface2.Name?'" | tail -n 2
  GRE.Tunnel.1.Interface.2.Name="gre2-t1"
  $ R "ba-cli 'GRE.Tunnel.test_tunnel.Interface.test_interface2.Status?'" | tail -n 2
  GRE.Tunnel.1.Interface.2.Status="NotPresent"

Provide a unique key identifier:

  $ R "ba-cli 'GRE.Tunnel.test_tunnel.Interface.test_interface2.KeyIdentifierGenerationPolicy=\"Provisioned\"'" > /dev/null 2>&1
  $ R "ba-cli 'GRE.Tunnel.test_tunnel.Interface.test_interface2.KeyIdentifier=1'" > /dev/null 2>&1
  $ R "ba-cli 'GRE.Tunnel.test_tunnel.Interface.test_interface2.Status?'" | tail -n 2
  GRE.Tunnel.1.Interface.2.Status="Unknown"

Ensure GRE device is created

  $ R "ip link show | grep \"gre2-t1\" | sed 's/^[0-9]*: //'"
  gre2-t1@NONE: <POINTOPOINT,NOARP,UP,LOWER_UP> mtu 1472 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
