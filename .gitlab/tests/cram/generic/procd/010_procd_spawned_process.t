Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting process started by procd verification tests"

This Helper methods gets process enabled by Procd and pid of the process provided, #Param1 - Name of the process or service:

  $ get_status_and_pid() {  R "ubus call service list | sed '/^$/d' | jsonfilter -e '@[\"$1\"][\"instances\"][\"$1\"].running' -e '@[\"$1\"][\"instances\"][\"$1\"].pid'";}

Verify expected processes that should be started by procd are running, using ubus call service list command:

  $ for process in tr181-dnssd tr181-upnp tr181-pcm tr181-httpaccess tr181-syslog tr181-powerstatus; do get_status_and_pid $process; done
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)

  $ for process in tr181-security tr181-periodicfileupload tr181-bulkdata tr181-temperature deviceinfo-system tr181-usermanagement; do get_status_and_pid $process; done
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)

  $ for process in tr181-ipdiagnostics tr181-dynamicdns tr181-mcastd tr181-led tr181-button tr181-captiveportal; do get_status_and_pid $process; done
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)

  $ for process in tr181-mqttbroker tr181-dhcpv4client tr181-moca tr181-dhcpv6client tr181-sfp tr181-logical; do get_status_and_pid $process; done
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)

  $ for process in tr181-usb tr181-neighbordiscovery tr181-dhcpv6s tr181-ethernet tr181-routeradvertisement tr181-xpon; do get_status_and_pid $process; done
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)

  $ for process in tr181-dslite amx-processmonitor multisettings packet-interception oopsmonitor amx-faultmonitor; do get_status_and_pid $process; done
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)

  $ for process in netmodel reboot-service pwhm tr181-pcp tr181-device tr181-mqtt; do get_status_and_pid $process; done
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)

  $ for process in tr181-firewall tr181-qos tr181-bridging tr181-ppp time-manager deviceinfo-manager; do get_status_and_pid $process; done
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)

  $ for process in gmap-server  hosts-manager cellular-manager dhcpv4-manager ip-manager; do get_status_and_pid $process; done
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)
  true
  \d+ (re)

  $ for process in routing-manager netdev-plugin; do get_status_and_pid $process; done
  true
  \d+ (re)
  true
  \d+ (re)

Verify odhcpd process:

  $ R "ubus call service list | sed '/^$/d' | jsonfilter -e '@[\"odhcpd\"][\"instances\"][\"instance1\"].running' -e '@[\"odhcpd\"][\"instances\"][\"instance1\"].pid'"
  true
  \d+ (re)

  $ R logger -t cram "procd verification test finished"