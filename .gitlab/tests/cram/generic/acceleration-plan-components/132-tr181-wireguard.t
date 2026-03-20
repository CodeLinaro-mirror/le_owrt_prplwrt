Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check Wireguard root datamodel:

  $ R "ubus -S call WireGuard _get"
  {"WireGuard.":{"PeerNumberOfEntries":0,"TunnelNumberOfEntries":0}}
  {}
  {"amxd-error-code":0}

Create a Wireguard tunnel interface:

  $ R "ba-cli 'WireGuard.Tunnel.+{Alias=\"t1\"}'" > /dev/null 2>&1
  $ R "ba-cli 'WireGuard.Tunnel.t1.Interface.+{Alias=\"i1\"}'" > /dev/null 2>&1
  $ WGIFACE=`R "ba-cli 'WireGuard.Tunnel.t1.Interface.i1.Name?'" | sed -ne 2p | awk -F= '{print $2}' | sed -e s/'\"'//g`
  $ R "ba-cli 'WireGuard.Tunnel.t1.Interface.i1.Status?'" | sed -ne 2p
  WireGuard.Tunnel.*.Interface.1.Status="Down" (glob)

Verify status in NetModel:

  $ R "ba-cli 'NetModel.Intf.[Name ~= \""$WGIFACE"\"].Status_ext?'" | tail -n2 | head -n1
  NetModel.Intf.*.Status_ext="Down" (glob)

Now enable the interface

  $ R "ba-cli 'WireGuard.Tunnel.t1.Interface.i1.Enable=1'" > /dev/null 2>&1
  $ R "ba-cli 'WireGuard.Tunnel.t1.Enable=1'" > /dev/null 2>&1
  $ R "ba-cli 'WireGuard.Tunnel.t1.Interface.i1.Status?'" | sed -ne 2p
  WireGuard.Tunnel.*.Interface.1.Status="Unknown" (glob)

Verify status in NetModel:

  $ R "ba-cli 'NetModel.Intf.[Name ~= \""$WGIFACE"\"].Status_ext?'" | tail -n2 | head -n1
  NetModel.Intf.*.Status_ext="Unknown" (glob)

Cleanup:

  $ R "ba-cli 'WireGuard.Tunnel.t1-'" >/dev/null 2>&1
