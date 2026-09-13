Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check the WireGuard datamodel starts empty:

  $ R "ba-cli 'WireGuard.PeerNumberOfEntries?'" | grep -v '>' | grep -F 'NumberOfEntries='
  WireGuard.PeerNumberOfEntries=0
  $ R "ba-cli 'WireGuard.TunnelNumberOfEntries?'" | grep -v '>' | grep -F 'NumberOfEntries='
  WireGuard.TunnelNumberOfEntries=0

Create a Wireguard tunnel interface:

  $ R "ba-cli 'WireGuard.Tunnel.+{Alias=\"t1\"}'" > /dev/null 2>&1
  $ R "ba-cli 'WireGuard.Tunnel.t1.Interface.+{Alias=\"i1\"}'" > /dev/null 2>&1
  $ WGIFACE=`R "ba-cli 'WireGuard.Tunnel.t1.Interface.i1.Name?'" | sed -ne 2p | awk -F= '{print $2}' | sed -e s/'\"'//g`
  $ R "ba-cli 'WireGuard.Tunnel.t1.Interface.i1.Status?'" | sed -ne 2p
  WireGuard.Tunnel.*.Interface.1.Status="Down" (glob)

Verify status in NetModel:

  $ R "ba-cli 'NetModel.Intf.[Name ~= \""$WGIFACE"\"].Status_ext?'" | grep -v '>' | grep -F 'Status_ext='
  NetModel.Intf.*.Status_ext="Down" (glob)

Now enable the interface

  $ R "ba-cli 'WireGuard.Tunnel.t1.Interface.i1.Enable=1'" > /dev/null 2>&1
  $ R "ba-cli 'WireGuard.Tunnel.t1.Enable=1'" > /dev/null 2>&1
  $ R "ba-cli 'WireGuard.Tunnel.t1.Interface.i1.Status?'" | sed -ne 2p
  WireGuard.Tunnel.*.Interface.1.Status="Unknown" (glob)

Verify status in NetModel:

  $ R "ba-cli 'NetModel.Intf.[Name ~= \""$WGIFACE"\"].Status_ext?'" | grep -v '>' | grep -F 'Status_ext='
  NetModel.Intf.*.Status_ext="Unknown" (glob)

Cleanup:

  $ R "ba-cli 'WireGuard.Tunnel.t1-'" >/dev/null 2>&1
