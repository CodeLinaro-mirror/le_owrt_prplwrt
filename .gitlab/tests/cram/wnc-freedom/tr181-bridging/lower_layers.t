Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check lan bridge ports:

  $ R ip link show | grep 'master br-lan' | cut -d: -f2 | sort
   lan1
   lan2
   lan3
   lan4
   wlan0
   wlan0.1
   wlan1
   wlan1.1
   wlan2
   wlan2.1

Replace a port with WAN interface:

  $ R ba-cli 'Device.Bridging.Bridge.lan.Port.12.LowerLayers=Device.Ethernet.Interface.1' >/dev/null
  $ R ba-cli 'Device.Bridging.Bridge.lan.Port.12.Name?' | grep -Ev '^(>|$)'
  Device.Bridging.Bridge.1.Port.12.Name="wan"

Check lan bridge ports:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"
  $ R ip link show | grep 'master br-lan' | cut -d: -f2 | sort
   lan1
   lan2
   lan3
   wan
   wlan0
   wlan0.1
   wlan1
   wlan1.1
   wlan2
   wlan2.1


Restore:

  $ R ba-cli 'Device.Bridging.Bridge.lan.Port.12.LowerLayers=Device.Ethernet.Interface.5' | grep -Ev '^(>|$)'
  Device.Bridging.Bridge.1.Port.12.
  Device.Bridging.Bridge.1.Port.12.LowerLayers="Device.Ethernet.Interface.5"
