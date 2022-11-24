Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that miniupnpd is enabled and running by default:

  $ R "pgrep --count miniupnpd"
  1

  $ R "uci show upnpd.config.enabled"
  upnpd.config.enabled='1'

  $ R "ubus -S call UPnP.Device _get '{\"rel_path\":\"UPnPIGD\"}'"
  {"UPnP.Device.":{"UPnPIGD":true}}

Disable miniupnpd:

  $ R "ubus -S call UPnP.Device _set '{\"parameters\":{\"UPnPIGD\":False}}'" ; sleep 1
  {"UPnP.Device.":{"UPnPIGD":false}}

Check that miniupnpd is disabled and not running:

  $ R "pgrep --count miniupnpd"
  0
  [1]

  $ R "uci show upnpd.config.enabled"
  upnpd.config.enabled='0'

  $ R "ubus -S call UPnP.Device _get '{\"rel_path\":\"UPnPIGD\"}'"
  {"UPnP.Device.":{"UPnPIGD":false}}

Enable miniupnpd:

  $ R "ubus -S call UPnP.Device _set '{\"parameters\":{\"UPnPIGD\":True}}'" ; sleep 1
  {"UPnP.Device.":{"UPnPIGD":true}}

Check that miniupnpd is enabled and running again:

  $ R "pgrep --count miniupnpd"
  1

  $ R "uci show upnpd.config.enabled"
  upnpd.config.enabled='1'

  $ R "ubus -S call UPnP.Device _get '{\"rel_path\":\"UPnPIGD\"}'"
  {"UPnP.Device.":{"UPnPIGD":true}}
