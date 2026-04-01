
Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check initial DHCPv6Client configuration:

  $ R "ba-cli 'DHCPv6Client.Client.1.Enable?' | grep -v '>' | grep 'Enable'"
  DHCPv6Client.Client.1.Enable=1

Check current ForceSolicitPolicy value:

  $ R "ba-cli 'DHCPv6Client.Client.1.X_PRPLWARE-COM_ForceSolicitPolicy?' | grep -v '>' | grep 'ForceSolicitPolicy'"
  DHCPv6Client.Client.1.X_PRPLWARE-COM_ForceSolicitPolicy=0

Start tcpdump in background to capture DHCPv6 packets on testbed WAN interface:

  $ sudo timeout 15 tcpdump -i $TESTBED_WAN_INTERFACE -n -l 'udp port 547 or udp port 546' > /tmp/dhcpv6_capture.log 2>&1 &
  $ sleep 2

Verify DHCPv6 Solicit message was not captured by tcpdump:

  $ grep -i 'solicit' /tmp/dhcpv6_capture.log | head -1

Enable ForceSolicitPolicy to trigger DHCPv6 Solicit message ( a restart of the client is needed):

  $ R "ba-cli 'DHCPv6Client.Client.1.X_PRPLWARE-COM_ForceSolicitPolicy=1'" > /dev/null
  $ R "ba-cli 'DHCPv6Client.Client.1.Enable=0'" > /dev/null
  $ R "ba-cli 'DHCPv6Client.Client.1.Enable=1'" > /dev/null
  $ sleep 1

Verify the parameter was set correctly:

  $ R "ba-cli 'DHCPv6Client.Client.1.X_PRPLWARE-COM_ForceSolicitPolicy?' | grep -v '>' | grep 'ForceSolicitPolicy'"
  DHCPv6Client.Client.1.X_PRPLWARE-COM_ForceSolicitPolicy=1

Wait for DHCPv6 Solicit message to be sent and captured:

  $ sleep 8

Verify DHCPv6 Solicit message was captured by tcpdump:

  $ grep -i 'solicit' /tmp/dhcpv6_capture.log | head -1
  *solicit* (glob)

Cleanup tcpdump capture file:

  $ rm -f /tmp/dhcpv6_capture.log

Reset ForceSolicitPolicy to original value:

  $ R "ba-cli 'DHCPv6Client.Client.1.X_PRPLWARE-COM_ForceSolicitPolicy=0'" > /dev/null

Verify reset:

  $ R "ba-cli 'DHCPv6Client.Client.1.X_PRPLWARE-COM_ForceSolicitPolicy?' | grep -v '>' | grep 'ForceSolicitPolicy'"
  DHCPv6Client.Client.1.X_PRPLWARE-COM_ForceSolicitPolicy=0
