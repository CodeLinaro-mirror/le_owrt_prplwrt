Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check the GRE datamodel starts empty:

  $ R "ba-cli 'GRE.FilterNumberOfEntries?'" | grep -v '>' | grep -F 'NumberOfEntries='
  GRE.FilterNumberOfEntries=0
  $ R "ba-cli 'GRE.TunnelNumberOfEntries?'" | grep -v '>' | grep -F 'NumberOfEntries='
  GRE.TunnelNumberOfEntries=0

Make sure we start with no custom GRE devices:

  $ R "ip link show | grep -w \"gre[0-9]\+-t[0-9]\+\" | wc -l"
  0

Create a GRE tunnel instance with invalid configuration:

  $ R "ba-cli 'GRE.Tunnel.+{Alias=\"test_tunnel\", Enable=1, DeliveryHeaderProtocol=\"IPv6\", RemoteEndpoints=\"203.0.113.5\"}'" > /dev/null 2>&1
  $ R "ba-cli 'GRE.Tunnel.test_tunnel.Status?'" | sed -n 2p
  GRE.Tunnel.[0-9]+.Status="Error" (re)

Ensure no GRE device is created for an invalid tunnel configuration:

  $ R "ip link show | grep -w \"gre[0-9]\+-t[0-9]\+\" | wc -l"
  0

Provide valid tunnel configuration:

  $ R "ba-cli 'GRE.Tunnel.test_tunnel.DeliveryHeaderProtocol=\"IPv4\"'" > /dev/null 2>&1
  $ R "ba-cli 'GRE.Tunnel.test_tunnel.Status?'" | sed -n 2p
  GRE.Tunnel.[0-9]+.Status="Enabled" (re)

Create L3 GRE interface:

  $ R "ba-cli 'IP.Interface.+{Alias=\"test_tunnel\", Enable=1, IPv4Enable=1, LowerLayers=\"Device.${TUNOBJ}Interface.1\"}'" > /dev/null 2>&1
  $ R "ba-cli 'GRE.Tunnel.test_tunnel.Interface.+{Alias=\"test_interface\", Enable=1}'" > /dev/null 2>&1
  $ sleep 5
  $ R "ba-cli 'GRE.Tunnel.test_tunnel.Interface.test_interface.Name?'" | sed -n 2p
  GRE.Tunnel.[0-9]+.Interface.1.Name="gre1-t[0-9]+" (re)
  $ R "ba-cli 'GRE.Tunnel.test_tunnel.Interface.test_interface.Status?'" | sed -n 2p
  GRE.Tunnel.[0-9]+.Interface.1.Status="Unknown" (re)

Ensure L3 GRE device is created:

  $ R "ip link show | grep -w 'gre1-t[0-9]\+' | sed 's/^[0-9]*: //'"
  gre1-t[0-9]+@NONE: <POINTOPOINT,NOARP,UP,LOWER_UP> mtu 1476 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000 (re)

Verify NetModel interface status:

  $ R "ba-cli 'NetModel.Intf.gre-test_interface.Status_ext?'" | sed -n 2p
  NetModel.Intf.[0-9]+.Status_ext="Unknown" (re)

Bind L3 GRE device to wan interface:

  $ R "ba-cli 'GRE.Tunnel.test_tunnel.Interface.test_interface.LowerLayers=\"Device.IP.Interface.2\"'" > /dev/null 2>&1
  $ sleep 5
  $ R "ba-cli 'GRE.Tunnel.test_tunnel.Interface.test_interface.Name?'" | sed -n 2p
  GRE.Tunnel.[0-9]+.Interface.1.Name="gre1-t[0-9]+" (re)
  $ R "ba-cli 'GRE.Tunnel.test_tunnel.Interface.test_interface.Status?'" | sed -n 2p
  GRE.Tunnel.[0-9]+.Interface.1.Status="Unknown" (re)
  $ LOIF=$(R "ip link show | sed -n 's/^[0-9]*: gre1-t[0-9]\+@\([^:]\+\).*$/\1/p'")
  $ [ "$LOIF" = "$WAN" ]

Create L2 GRE interface:

  $ R "ba-cli 'Bridging.Bridge.1.Port.+{Alias=\"test_tunnel\", Enable=1, LowerLayers=\"Device.${TUNOBJ}Interface.2\"}'" > /dev/null 2>&1
  $ R "ba-cli 'GRE.Tunnel.test_tunnel.Interface.+{Alias=\"test_interface2\", Enable=1}'" > /dev/null 2>&1
  $ sleep 5
  $ R "ba-cli 'GRE.Tunnel.test_tunnel.Interface.test_interface2.Name?'" | sed -n 2p
  GRE.Tunnel.[0-9]+.Interface.2.Name="gre2-t[0-9]+" (re)

Provide a unique key identifier:

  $ R "ba-cli 'GRE.Tunnel.test_tunnel.Interface.test_interface2.KeyIdentifierGenerationPolicy=\"Provisioned\"'" > /dev/null 2>&1
  $ R "ba-cli 'GRE.Tunnel.test_tunnel.Interface.test_interface2.KeyIdentifier=1'" > /dev/null 2>&1
  $ R "ba-cli 'GRE.Tunnel.test_tunnel.Interface.test_interface2.Status?'" | sed -n 2p
  GRE.Tunnel.[0-9]+.Interface.2.Status="Unknown" (re)

Ensure L2 GRE device is created:

  $ R "ip link show | grep -w 'gre2-t[0-9]\+' | sed 's/^[0-9]*: //'"
  gre2-t[0-9]+@NONE: <BROADCAST,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc noqueue master br-lan state UNKNOWN mode DEFAULT group default qlen 1000 (re)

Verify NetModel interface status:

  $ R "ba-cli 'NetModel.Intf.gre-test_interface2.Status_ext?'" | sed -n 2p
  NetModel.Intf.[0-9]+.Status_ext="Unknown" (re)

Bind L2 GRE device to wan interface:

  $ R "ba-cli 'GRE.Tunnel.test_tunnel.Interface.test_interface2.LowerLayers=\"Device.IP.Interface.2\"'" > /dev/null 2>&1
  $ sleep 5
  $ R "ba-cli 'GRE.Tunnel.test_tunnel.Interface.test_interface2.Name?'" | sed -n 2p
  GRE.Tunnel.[0-9]+.Interface.2.Name="gre2-t[0-9]+" (re)
  $ R "ba-cli 'GRE.Tunnel.test_tunnel.Interface.test_interface2.Status?'" | sed -n 2p
  GRE.Tunnel.[0-9]+.Interface.2.Status="Unknown" (re)
  $ LOIF=$(R "ip link show | sed -n 's/^[0-9]*: gre2-t[0-9]\+@\([^:]\+\).*$/\1/p'")
  $ [ "$LOIF" = "$WAN" ]

Cleanup:
  $ R "ba-cli 'IP.Interface.test_tunnel-'" >/dev/null 2>&1
  $ R "ba-cli 'Bridging.Bridge.1.Port.test_tunnel-'" >/dev/null 2>&1
  $ R "ba-cli 'GRE.Tunnel.test_tunnel-'" >/dev/null 2>&1
