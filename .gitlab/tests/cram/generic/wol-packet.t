Verify that a Wake-on-LAN packet is transmitted (broadcast UDP/9)
This test only verifies that the DUT sends a WoL packet; no receiver is required.

  $ rm -f "$CRAMTMP/wol.cap"

Trigger WoL and wait until packet is captured or timeout is reached
  $ sh -c ' \
  > sudo tcpdump -p -i "$1" -c 1 -nn -e udp port 9 >"$2" 2>&1 & \
  > TCPDUMP_PID=$!; \
  > sleep 1; \
  > ba-cli "Device.Ethernet.WoL.SendMagicPacket(MACAddress=\"02:00:00:00:00:01\", Password=\"\")" >/dev/null 2>&1 || true; \
  > ATTEMPT=0; \
  > MAX_WAIT=10; \
  > RPC_RETRIED=0; \
  > while [ "$ATTEMPT" -lt "$MAX_WAIT" ]; do \
  >   grep -q "UDP" "$2" 2>/dev/null && break; \
  >   if [ "$RPC_RETRIED" -eq 0 ] && [ "$ATTEMPT" -eq 1 ]; then \
  >     ba-cli "Device.Ethernet.WoL.SendMagicPacket(MACAddress=\"02:00:00:00:00:01\", Password=\"\")" >/dev/null 2>&1 || true; \
  >     RPC_RETRIED=1; \
  >   fi; \
  >   sleep 1; \
  >   ATTEMPT=$((ATTEMPT + 1)); \
  > done; \
  > kill "$TCPDUMP_PID" >/dev/null 2>&1 || true; \
  > wait "$TCPDUMP_PID" >/dev/null 2>&1 || true \
  > ' sh "$TESTBED_LAN_INTERFACE" "$CRAMTMP/wol.cap"

Assert that a UDP packet was sent
  $ grep -m1 "UDP" "$CRAMTMP/wol.cap"
  .*UDP.* (re)
