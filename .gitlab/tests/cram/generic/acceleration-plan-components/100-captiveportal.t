Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Enable Captive Portal (not activated by default):

  $ R "ba-cli 'CaptivePortal.Enable=1'" >/dev/null
  $ R "ba-cli 'CaptivePortal.Status?' | grep -Ev '^(>|$)'"
  CaptivePortal.Status="Enabled"
  $ sleep 1

Disable WAN using IP datamodel and check that Captive Portal starts intercepting:

  $ R "ba-cli 'Device.IP.Interface.[Alias==\"wan\"].Enable=0'" >/dev/null

Get a DHCP lease from the router (openNDS requires clients to be registered):

  $ sudo nmap -sU -p 67 --script=dhcp-discover --script-args dhcptype=DHCPREQUEST,DHCPACK "${TARGET_LAN_IP}" 2>&1 | grep "DHCP Message Type"
  |   DHCP Message Type: DHCPACK

Wait for status change:

  $ sleep 15
  $ R "ba-cli -lj 'ubus-protected;CaptivePortal.State?'" 2>&1 | grep -v "^>" | sed -n "4p" 
  [{"CaptivePortal.":{"State":"Running"}}]

Check openNDS http interface has been opened on br-lan:

  $ R "ba-cli 'UserInterface.HTTPAccess.[Alias==\"captive\"].Interface?' | grep -Ev '^(>|$)'"
  UserInterface.HTTPAccess.3.Interface="Device.IP.Interface.3"

Send a curl http request to detectportal.firefox.com and check we have a 307 temporary redirect:

  $ curl -i --resolve "detectportal.firefox.com:80:${TARGET_LAN_IP}" detectportal.firefox.com 2>/dev/null | head -1
  HTTP/1.1 307 Temporary Redirect\r (esc)

Reenable WAN:

  $ R "ba-cli -lj 'Device.IP.Interface.[Alias==\"wan\"].Enable=1' | grep -Ev '^(>|$)'"
  [{"Device.IP.Interface.2.":{"Enable":1}}]
  $ R "ba-cli 'CaptivePortal.Status?' | grep -Ev '^(>|$)'"
  CaptivePortal.Status="Enabled"

Cleanup:

  $ R "ba-cli 'CaptivePortal.Enable=0'" >/dev/null

Wait until captive portal cleanup is complete and WAN HTTPS access works:

  $ R " \
  > i=0; \
  > while [ \$i -lt 60 ]; do \
  >     if ba-cli 'CaptivePortal.Status?' 2>/dev/null | grep -q '\.Status=\"Disabled\"$' && \
  >         ba-cli 'Device.IP.Interface.[Alias==\"wan\"].Status?' 2>/dev/null | grep -q '\.Status=\"Up\"$' && \
  >         curl --silent --show-error --connect-timeout 5 --max-time 5 https://registry.gitlab.com >/dev/null 2>&1; then \
  >         echo 'Captive portal is disabled and WAN HTTPS works'; \
  >         exit 0; \
  >     fi; \
  >     sleep 1; \
  >     i=\$((i + 1)); \
  > done; \
  > echo 'WAN HTTPS did not recover after 60 attempts' >&2; \
  > exit 1 \
  > "
  Captive portal is disabled and WAN HTTPS works

