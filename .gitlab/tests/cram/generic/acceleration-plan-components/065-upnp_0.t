Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check that tr181-upnp is enabled and running by default:

  $ R "pgrep -x --count tr181-upnp"
  1

Check that tr181-upnpdiscovery is enabled and running by default:

  $ R "pgrep --count tr181-upnpdisco"
  1

Check that miniupnpd is enabled and running by default:

  $ R "pgrep --count miniupnpd"
  1

  $ R "ba-cli -l 'UPnP.Device.UPnPIGD?'"
  1

  $ R "netstat -tulpn 2>&1 | grep miniupnpd | grep tcp"
  tcp        0      0 :::5000                 :::\*                    LISTEN      .*\/miniupnpd (re)

  $ R "netstat -tulpn 2>&1 | grep miniupnpd | grep \:1900 | sort"
  udp        0      0 0.0.0.0:1900            0.0.0.0:\*                           .*\/miniupnpd (re)
  udp        0      0 :::1900                 :::\*                                .*\/miniupnpd (re)

  $ R "netstat -tulpn 2>&1 | grep miniupnpd | grep \:5351"
  udp        0      0 192.168.1.1:5351        0.0.0.0:\*                           .*\/miniupnpd (re)
  udp        0      0 :::5351                 :::\*                                .*\/miniupnpd (re)

Disable miniupnpd:

  $ R "ba-cli 'UPnP.Device.UPnPIGD=false' > /dev/null" ; sleep 2

Check that miniupnpd is disabled and not running:

  $ R "pgrep --count miniupnpd"
  0
  [1]

  $ R "ba-cli -l 'UPnP.Device.UPnPIGD?'"
  0

  $ R "netstat -tulpn 2>&1 | grep miniupnpd"
  [1]

Enable miniupnpd:

  $ R "ba-cli 'UPnP.Device.UPnPIGD=true' > /dev/null" ; sleep 3

Check that miniupnpd is enabled and running again:

  $ R "pgrep --count miniupnpd"
  1

  $ R "ba-cli -l 'UPnP.Device.UPnPIGD?'"
  1

  $ R "netstat -tulpn 2>&1 | grep miniupnpd | grep tcp"
  tcp        0      0 :::5000                 :::\*                    LISTEN      .*\/miniupnpd (re)

  $ R "netstat -tulpn 2>&1 | grep miniupnpd | grep \:1900 | sort"
  udp        0      0 0.0.0.0:1900            0.0.0.0:\*                           .*\/miniupnpd (re)
  udp        0      0 :::1900                 :::\*                                .*\/miniupnpd (re)

  $ R "netstat -tulpn 2>&1 | grep miniupnpd | grep \:5351"
  udp        0      0 192.168.1.1:5351        0.0.0.0:\*                           .*\/miniupnpd (re)
  udp        0      0 :::5351                 :::\*                                .*\/miniupnpd (re)

Check that it is possible to setup WANAccessProvider option over bus:

  $ R "ba-cli 'UPnP.X_PRPLWARE-COM_IGDConfig.WANAccessProvider=\"test_provider\"'" >/dev/null
  $ R "ba-cli -l 'UPnP.X_PRPLWARE-COM_IGDConfig.WANAccessProvider?'" | awk 'NF'
  test_provider
