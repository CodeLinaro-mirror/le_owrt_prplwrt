Verify that a Wake-on-LAN packet is transmitted (broadcast UDP/9)
This test only verifies that the DUT sends a WoL packet; no receiver is required.

  $ rm -f "$CRAMTMP/wol-run.sh" "$CRAMTMP/wol.cap"
  $ R="${CRAM_REMOTE_COMMAND:-}"

Create helper script:

  $ cat >"$CRAMTMP/wol-run.sh" <<'EOS'
  > IFACE="$1"
  > CAPFILE="$2"
  > sudo tcpdump -p -i "$IFACE" -c 1 -nn -e udp port 9 >"$CAPFILE" 2>&1 &
  > TCPDUMP_PID=$!
  > sleep 1
  > ba-cli "Device.Ethernet.WoL.SendMagicPacket(MACAddress=\"02:00:00:00:00:01\", Password=\"\")" >/dev/null 2>&1 || true
  > ATTEMPT=0
  > MAX_WAIT=10
  > RPC_RETRY=0
  > MAX_RPC_RETRY=3
  > while [ "$ATTEMPT" -lt "$MAX_WAIT" ]; do
  >   if grep -q "UDP" "$CAPFILE" 2>/dev/null; then
  >     break
  >   fi
  >   if [ "$RPC_RETRY" -lt "$MAX_RPC_RETRY" ]; then
  >     ba-cli "Device.Ethernet.WoL.SendMagicPacket(MACAddress=\"02:00:00:00:00:01\", Password=\"\")" >/dev/null 2>&1 || true
  >     RPC_RETRY=$((RPC_RETRY + 1))
  >   fi
  >   sleep 1
  >   ATTEMPT=$((ATTEMPT + 1))
  > done
  > kill -9 "$TCPDUMP_PID" >/dev/null 2>&1 || true
  > EOS

Run helper script on remote DUT:

  $ "$R" "sh -s -- \"$TESTBED_LAN_INTERFACE\" /tmp/wol.cap" < "$CRAMTMP/wol-run.sh"

Fetch capture result:

  $ "$R" "cat /tmp/wol.cap" >"$CRAMTMP/wol.cap"

Assert that a UDP packet was sent:

  $ grep -m1 'UDP' "$CRAMTMP/wol.cap"
  .*UDP.* (re)
