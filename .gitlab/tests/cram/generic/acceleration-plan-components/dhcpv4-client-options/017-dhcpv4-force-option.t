Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Verify python can import scapy:

  $ python3 -c "import scapy.all" >/dev/null 2>&1

Pick test constants:

  $ TAG=42
  $ VALUE_HEX=74657374
  $ REQ_WITHOUT_TAG=1,3,6,15
  $ REQ_WITH_TAG=1,3,6,15,42
  $ PROBE_TIMEOUT=12
  $ PROBE_RETRIES=2

Create pool option with Force=true:

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.lan.Option.+{Alias=\"cpe-force-opt\",Enable=1,Tag=${TAG},Value=\"${VALUE_HEX}\",Force=1}'" | grep -Ev '^(>|$)'
  Device\.DHCPv4\.Server\.Pool\.1\.Option\.[0-9]+\. (re)
  Device\.DHCPv4\.Server\.Pool\.1\.Option\.[0-9]+\.Alias="cpe-force-opt" (re)
  $ sleep 1

Force=true, tag 42 absent from DHCPREQUEST PRL -> tag must be present in final DHCPACK:

  $ sudo -E python3 "$TESTDIR/dhcpv4_option_probe.py" --iface "$TESTBED_LAN_INTERFACE" --request-options "$REQ_WITHOUT_TAG" --timeout "$PROBE_TIMEOUT" --retries "$PROBE_RETRIES" 2>/dev/null
  CLIENT_MAC=aa:bb:cc:dd:ee:ff
  RECEIVED_TAGS=.*(=|,)42(,|$).* (re)

Set Force=false:

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.lan.Option.cpe-force-opt.Force=0'" | grep -Ev '^(>|$)'
  Device\.DHCPv4\.Server\.Pool\.1\.Option\.[0-9]+\. (re)
  Device\.DHCPv4\.Server\.Pool\.1\.Option\.[0-9]+\.Force=0 (re)
  $ sleep 1

Force=false, tag 42 absent from DHCPREQUEST PRL -> tag must be absent from final DHCPACK:

  $ sudo -E python3 "$TESTDIR/dhcpv4_option_probe.py" --iface "$TESTBED_LAN_INTERFACE" --request-options "$REQ_WITHOUT_TAG" --timeout "$PROBE_TIMEOUT" --retries "$PROBE_RETRIES" 2>/dev/null
  CLIENT_MAC=aa:bb:cc:dd:ee:ff
  RECEIVED_TAGS=(?!.*(=|,)42(,|$)).* (re)

Force=false, tag 42 present in DHCPREQUEST PRL -> tag must be present in final DHCPACK:

  $ sudo -E python3 "$TESTDIR/dhcpv4_option_probe.py" --iface "$TESTBED_LAN_INTERFACE" --request-options "$REQ_WITH_TAG" --timeout "$PROBE_TIMEOUT" --retries "$PROBE_RETRIES" --release 2>/dev/null
  CLIENT_MAC=aa:bb:cc:dd:ee:ff
  RECEIVED_TAGS=.*(=|,)42(,|$).* (re)
  RELEASED=.* (re)


Cleanup:

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.lan.Option.cpe-force-opt.-'" | grep -Ev '^(>|$)'
  Device\.DHCPv4\.Server\.Pool\.1\.Option\.[0-9]+\. (re)
