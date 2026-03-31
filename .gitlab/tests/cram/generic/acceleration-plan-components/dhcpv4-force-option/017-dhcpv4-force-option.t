Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Install scapy with pip:

  $ pip install scapy >/dev/null

Verify python can import scapy:

  $ python3 -c "import scapy.all" >/dev/null 2>&1

Pick test constants:

  $ TAG=42
  $ VALUE_HEX=74657374

Ensure clean state (remove old option alias if present):

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.lan.Option.cpe-force-opt.-'" >/dev/null 2>&1 || true

Create pool option with Force=true:

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.lan.Option.+{Alias=\"cpe-force-opt\",Enable=1,Tag=${TAG},Value=\"${VALUE_HEX}\",Force=1}'" | grep -Ev '^>|^$'
  Device.DHCPv4.Server.Pool.1.Option.[0-9]+. (re)
  Device.DHCPv4.Server.Pool.1.Option.[0-9]+.Alias="cpe-force-opt" (re)

Force=true, client does not request tag 42 -> tag must be present:

  $ sudo -E python3 "$TESTDIR/dhcpv4_option_probe.py" --iface "$TESTBED_LAN_INTERFACE" --request-options "1,3,6,15"
  RECEIVED_TAGS=.*42.* (re)

Set Force=false:

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.lan.Option.cpe-force-opt.Force=0'" | grep -Ev '^>|^$'
  Device.DHCPv4.Server.Pool.1.Option.[0-9]+. (re)
  Device.DHCPv4.Server.Pool.1.Option.[0-9]+.Force=0 (re)

Force=false, client does not request tag 42 -> tag must be absent:

  $ sudo -E python3 "$TESTDIR/dhcpv4_option_probe.py" --iface "$TESTBED_LAN_INTERFACE" --request-options "1,3,6,15"
  RECEIVED_TAGS=(?!.*42).* (re)

Force=false, client requests tag 42 -> tag must be present:

  $ sudo -E python3 "$TESTDIR/dhcpv4_option_probe.py" --iface "$TESTBED_LAN_INTERFACE" --request-options "1,3,6,15,42"
  RECEIVED_TAGS=.*42.* (re)

Cleanup:

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.lan.Option.cpe-force-opt.-'" | grep -Ev '^>|^$'
  Device.DHCPv4.Server.Pool.1.Option.[0-9]+. (re)
