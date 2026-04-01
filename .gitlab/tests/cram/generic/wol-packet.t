Verify that a Wake-on-LAN packet is transmitted (broadcast UDP/9)
This test only verifies that the DUT sends a WoL packet; no receiver is required.

  $ rm -f "$CRAMTMP/wol.cap"

Trigger WoL and capture packet
  $ sh -c ' \
  > timeout 6s sudo tcpdump -p -i "$1" -nn -e udp port 9 >"$2" 2>&1 & \
  > TCPDUMP_PID=$!; \
  > sleep 1; \
  > ba-cli "Device.Ethernet.WoL.SendMagicPacket(MACAddress=\"02:00:00:00:00:01\", Password=\"\")" >/dev/null 2>&1 || true; \
  > sleep 1; \
  > ba-cli "Device.Ethernet.WoL.SendMagicPacket(MACAddress=\"02:00:00:00:00:01\", Password=\"\")" >/dev/null 2>&1 || true; \
  > sleep 1; \
  > ba-cli "Device.Ethernet.WoL.SendMagicPacket(MACAddress=\"02:00:00:00:00:01\", Password=\"\")" >/dev/null 2>&1 || true; \
  > sleep 2; \
  > kill "$TCPDUMP_PID" >/dev/null 2>&1 || true; \
  > wait "$TCPDUMP_PID" >/dev/null 2>&1 || true \
  > ' sh "$TESTBED_LAN_INTERFACE" "$CRAMTMP/wol.cap"

Assert that a UDP packet was sent
  $ grep -m1 "UDP" "$CRAMTMP/wol.cap"
  .*UDP.* (re)
