Verify that a Wake-on-LAN packet is transmitted (broadcast UDP/9)
This test only verifies that the DUT sends a WoL packet; no receiver is required.

  $ IFACE=$TESTBED_LAN_INTERFACE
  $ rm -f "$CRAMTMP/wol.cap"
  $ sudo tcpdump -p -i "$IFACE" -c 1 -nn -e udp port 9 >"$CRAMTMP/wol.cap" 2>/dev/null &
  $ TCPDUMP_PID=$!
  $ echo "tcpdump_pid=$TCPDUMP_PID"
  tcpdump_pid=[0-9]+ (re)
  $ sleep 2

Trigger WoL via data model RPC
  $ ba-cli "Device.Ethernet.WoL.SendMagicPacket(MACAddress=\"02:00:00:00:00:01\", Password=\"\")" >/dev/null 2>&1 || true

Stop capture
  $ sleep 3
  $ [ -n "$TCPDUMP_PID" ] && kill "$TCPDUMP_PID" >/dev/null 2>&1 || true
  $ [ -n "$TCPDUMP_PID" ] && wait "$TCPDUMP_PID" >/dev/null 2>&1 || true

Assert that a UDP packet was sent
  $ grep -m1 "UDP" "$CRAMTMP/wol.cap"
  .*UDP.* (re)
