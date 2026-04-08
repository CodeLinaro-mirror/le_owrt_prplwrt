Verify that a Wake-on-LAN packet is transmitted (broadcast UDP/9)
This test only verifies that the DUT sends a WoL packet; no receiver is required.

  $ rm -f "$CRAMTMP/wol.cap"
  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Start local capture on testbed PC:

  $ sudo tcpdump -p -i "$TESTBED_LAN_INTERFACE" -c 1 -nn -e udp port 9 >"$CRAMTMP/wol.cap" 2>&1 &
  $ TCPDUMP_PID="$!"
  $ sleep 1

Trigger WoL RPC first try:

  $ R "ba-cli 'Device.Ethernet.WoL.SendMagicPacket(MACAddress=\"02:00:00:00:00:01\", Password=\"\")' >/dev/null 2>&1 || true"
  $ sleep 1

Retry only if UDP is not yet captured:

  $ if ! grep -q 'UDP' "$CRAMTMP/wol.cap" 2>/dev/null; then R "ba-cli 'Device.Ethernet.WoL.SendMagicPacket(MACAddress=\"02:00:00:00:00:01\", Password=\"\")' >/dev/null 2>&1 || true"; fi
  $ sleep 1
  $ if ! grep -q 'UDP' "$CRAMTMP/wol.cap" 2>/dev/null; then R "ba-cli 'Device.Ethernet.WoL.SendMagicPacket(MACAddress=\"02:00:00:00:00:01\", Password=\"\")' >/dev/null 2>&1 || true"; fi
  $ sleep 1

Cleanup capture process if still running:

  $ sudo kill -9 "$TCPDUMP_PID" >/dev/null 2>&1 || true

Assert that a UDP packet was sent:

  $ grep -m1 'UDP' "$CRAMTMP/wol.cap"
  .*UDP.* (re)
