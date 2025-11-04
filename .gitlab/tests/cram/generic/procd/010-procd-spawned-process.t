Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

  $ R logger -t cram "Starting process started by procd verification tests"

This Helper methods gets process enabled by Procd and pid of the process \
provided, #Param1 - Name of the process or service:

  $ get_status_and_pid() { EnableStatus=$(R "ubus call service list | " \
  > "sed '/^$/d' | jsonfilter -e '@[\"$1\"][\"instances\"][\"$1\"].running'"); \
  > echo "$1 $EnableStatus"; \
  > Pid=$(R "ubus call service list | sed '/^$/d' | " \
  > "jsonfilter -e '@[\"$1\"][\"instances\"][\"$1\"].pid'"); echo "$1 $Pid";}

Ensure that all services migrated to procd are no longer using the obsolete amx_init_functions.sh-based init system, with the exception of non-migrated prplware components:

  $ R "grep -r amx_init_functions.sh /etc/init.d | grep -vE '(acl-manager|\
  > amx-fcgi|amx-shutdown-wait|cthulhu|netmodel-clients|rlyeh|timingila|\
  > tr181-conmon|tr181-conntrack-query|tr181-flashmonitor|tr181-gnimanager\
  > |tr181-homeplug|tr181-upnpdiscovery|data-model-mapper|tr069-discovery|\
  > tr181-gatewayinfo|usp-discovery)'"
  [1]

Verify expected processes that should be started by procd are running, using \
ubus call service list command, verify procd enabled true and pid:

  $ for process in tr181-dnssd tr181-upnp tr181-httpaccess tr181-syslog \
  > tr181-powerstatus; do get_status_and_pid $process; done
  tr181-dnssd true
  tr181-dnssd \d+ (re)
  tr181-upnp true
  tr181-upnp \d+ (re)
  tr181-httpaccess true
  tr181-httpaccess \d+ (re)
  tr181-syslog true
  tr181-syslog \d+ (re)
  tr181-powerstatus true
  tr181-powerstatus \d+ (re)

  $ for process in tr181-security tr181-periodicfileupload tr181-bulkdata \
  > tr181-temperature deviceinfo-system tr181-usermanagement; \
  > do get_status_and_pid $process; done
  tr181-security true
  tr181-security \d+ (re)
  tr181-periodicfileupload true
  tr181-periodicfileupload \d+ (re)
  tr181-bulkdata true
  tr181-bulkdata \d+ (re)
  tr181-temperature true
  tr181-temperature \d+ (re)
  deviceinfo-system true
  deviceinfo-system \d+ (re)
  tr181-usermanagement true
  tr181-usermanagement \d+ (re)

  $ for process in tr181-ipdiagnostics tr181-dynamicdns tr181-mcastd tr181-led \
  > tr181-button tr181-captiveportal; do get_status_and_pid $process; done
  tr181-ipdiagnostics true
  tr181-ipdiagnostics \d+ (re)
  tr181-dynamicdns true
  tr181-dynamicdns \d+ (re)
  tr181-mcastd true
  tr181-mcastd \d+ (re)
  tr181-led true
  tr181-led \d+ (re)
  tr181-button true
  tr181-button \d+ (re)
  tr181-captiveportal true
  tr181-captiveportal \d+ (re)

  $ for process in tr181-mqttbroker tr181-dhcpv4client tr181-dhcpv6client \
  > tr181-sfp tr181-logical; do get_status_and_pid $process; done
  tr181-mqttbroker true
  tr181-mqttbroker \d+ (re)
  tr181-dhcpv4client true
  tr181-dhcpv4client \d+ (re)
  tr181-dhcpv6client true
  tr181-dhcpv6client \d+ (re)
  tr181-sfp true
  tr181-sfp \d+ (re)
  tr181-logical true
  tr181-logical \d+ (re)

  $ for process in tr181-usb tr181-neighbordiscovery ethernet-manager \
  > tr181-routeradvertisement tr181-xpon; do get_status_and_pid $process; done
  tr181-usb true
  tr181-usb \d+ (re)
  tr181-neighbordiscovery true
  tr181-neighbordiscovery \d+ (re)
  ethernet-manager true
  ethernet-manager \d+ (re)
  tr181-routeradvertisement true
  tr181-routeradvertisement \d+ (re)
  tr181-xpon true
  tr181-xpon \d+ (re)

  $ for process in tr181-dslite amx-processmonitor multisettings \
  > packet-interception oopsmonitor amx-faultmonitor; \
  > do get_status_and_pid $process; done
  tr181-dslite true
  tr181-dslite \d+ (re)
  amx-processmonitor true
  amx-processmonitor \d+ (re)
  multisettings true
  multisettings \d+ (re)
  packet-interception true
  packet-interception \d+ (re)
  oopsmonitor true
  oopsmonitor \d+ (re)
  amx-faultmonitor true
  amx-faultmonitor \d+ (re)

  $ for process in netmodel reboot-service tr181-pcp tr181-device tr181-mqtt; \
  > do get_status_and_pid $process; done
  netmodel true
  netmodel \d+ (re)
  reboot-service true
  reboot-service \d+ (re)
  tr181-pcp true
  tr181-pcp \d+ (re)
  tr181-device true
  tr181-device \d+ (re)
  tr181-mqtt true
  tr181-mqtt \d+ (re)

  $ for process in tr181-firewall tr181-qos tr181-bridging tr181-ppp \
  > time-manager deviceinfo-manager; do get_status_and_pid $process; done
  tr181-firewall true
  tr181-firewall \d+ (re)
  tr181-qos true
  tr181-qos \d+ (re)
  tr181-bridging true
  tr181-bridging \d+ (re)
  tr181-ppp true
  tr181-ppp \d+ (re)
  time-manager true
  time-manager \d+ (re)
  deviceinfo-manager true
  deviceinfo-manager \d+ (re)

  $ for process in gmap-server  hosts-manager dhcpv4-manager \
  > ip-manager; do get_status_and_pid $process; done
  gmap-server true
  gmap-server \d+ (re)
  hosts-manager true
  hosts-manager \d+ (re)
  dhcpv4-manager true
  dhcpv4-manager \d+ (re)
  ip-manager true
  ip-manager \d+ (re)

  $ for process in routing-manager netdev-plugin pcm-manager dhcpv6s-manager; \
  > do get_status_and_pid $process; done
  routing-manager true
  routing-manager \d+ (re)
  netdev-plugin true
  netdev-plugin \d+ (re)
  pcm-manager true
  pcm-manager \d+ (re)
  dhcpv6s-manager true
  dhcpv6s-manager \d+ (re)

Verify pwhm process:

  $ EnableStatus=$(R "ubus call service list | sed '/^$/d' | jsonfilter -e " \
  > "'@[\"prplmesh_whm\"][\"instances\"][\"wld\"].running'"); \
  > Pid=$(R "ubus call service list | sed '/^$/d' | jsonfilter -e " \
  > "'@[\"prplmesh_whm\"][\"instances\"][\"wld\"].pid'");
  > echo "wld $EnableStatus"; echo "wld $Pid"
  wld true
  wld \d+ (re)

Verify odhcpd process:

  $ EnableStatus=$(R "ubus call service list | sed '/^$/d' | jsonfilter -e " \
  > "'@[\"odhcpd\"][\"instances\"][\"instance1\"].running'"); \
  > Pid=$(R "ubus call service list | sed '/^$/d' | jsonfilter -e " \
  > "'@[\"odhcpd\"][\"instances\"][\"instance1\"].pid'");
  > echo "odhcpd $EnableStatus"; echo "odhcpd $Pid"
  odhcpd true
  odhcpd \d+ (re)

  $ if echo "$CI_JOB_NAME" | grep -q -E "(Mozart|Turris|Haze|HDK-3)"; then exit 80; fi

  $ get_status_and_pid cellular-manager
  cellular-manager true
  cellular-manager \d+ (re)