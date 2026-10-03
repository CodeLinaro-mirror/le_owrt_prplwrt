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

  $ OLD_PID=$(R "netstat -lunp | sed -n 's|.*:67 .* \([0-9]*\)/dnsmasq\$|\1|p' | tr '\n' ' '")

  $ R "ba-cli 'Device.DHCPv4.Server.Pool.lan.Option.cpe-force-opt.-'" | grep -Ev '^(>|$)'
  Device\.DHCPv4\.Server\.Pool\.1\.Option\.[0-9]+\. (re)

Removing the option restarts dnsmasq again. If the next test probes while the
old dnsmasq is still stopping, the DHCPOFFER and DHCPREQUEST end up on
different processes and the lease is lost, so wait until the same new dnsmasq
owns UDP port 67 on two polls in a row:

  $ R "i=0; prev=; while [ \$i -lt 60 ]; do pid=\$(netstat -lunp | sed -n 's|.*:67 .* \([0-9]*\)/dnsmasq\$|\1|p' | tr '\n' ' '); [ -n \"\$pid\" ] && [ \"\$pid\" != \"$OLD_PID\" ] && [ \"\$pid\" = \"\$prev\" ] && break; prev=\$pid; i=\$((i+1)); sleep 1; done; [ \$i -lt 60 ] && echo restarted || echo 'dnsmasq did not restart within 60s'"
  restarted
