AFC inquiry against a local HTTPS server.

The LAN client (this cram host) runs a small AFC server. The DUT must have a
WAN address; if wan has none, the demo WAN mode below is applied. The server
address is the source IP of the route to TARGET_LAN_IP (the LAN client address
on the DUT LAN, for example 192.168.5.7 when the DUT br-lan is 192.168.5.1).
Device.WiFi.AFC.RequestVersion stays 1.4. That value is the AFC protocol
version inside the inquiry JSON, not the server address.

mxl25641 6 GHz is Radio.3, AccessPoint 3, 6, and 9. Country and
PowerType are already US and Indoor, so those are left alone. Standard
Power is set only after location is installed, because AFC.Enable is
rejected unless PowerType is already StandardPower.

CABundle stays Device.Security.CABundle.3. That object resolves to
/usr/share/ca-certificates/afc/afc_ca.pem. The test backs that file up,
installs the test CA under the same name, and restores the original
when it finishes. afcd verifies this CA; curl -k does not, so a
successful curl -k does not mean afcd can complete the handshake.

Location.+ does not return instance 3. On a DUT that already has
location objects it returns the next index, for example
Device.DeviceInfo.Location.20. The add must be run without -l;
ba-cli -l Device.DeviceInfo.Location.+ prints nothing.

Create R/C helpers. R must not forward stdin to the DUT: cram drives the
local shell over a pipe, and ba-cli will otherwise consume that pipe (ssh
without -n), which shows up as busybox "Unterminated quoted string" or a
cram IndexError. Prefer CRAM_REMOTE_COMMAND with ssh -n (see testbed.yml).

  $ R() { ${CRAM_REMOTE_COMMAND:-} "$@" </dev/null; }
  $ C() { ${CRAM_REMOTE_COPY:-scp} "$@"; }
  $ . "${TESTDIR}/../scripts/wifi.sh"

  $ R logger -t cram "Starting $TESTFILE"

  $ afc_tmp="${CRAMTMP:-/tmp}/afc-cram-$$"
  $ mkdir -p "$afc_tmp"
  $ afc_pid=""
  $ gps_idx=""
  $ bar_idx=""
  $ ca_backed=0
  $ url_set=0
  $ stop_afc_server() { if [ -n "$afc_pid" ]; then kill "$afc_pid" 2>/dev/null || true; wait "$afc_pid" 2>/dev/null || true; afc_pid=""; fi; pkill -f afc_https_server.py 2>/dev/null || true; }
  $ cleanup_afc() { stop_afc_server; R "ba-cli -l Device.WiFi.AFC.Enable=0" >/dev/null 2>&1 || true; if [ "$url_set" = 1 ]; then R "ba-cli -l Device.WiFi.AFC.ServerURL=https://testserver.wfatestorg.org/afc-simulator-api/availableSpectrumInquiry" >/dev/null 2>&1 || true; R "ba-cli -l Device.WiFi.AFC.Port=443" >/dev/null 2>&1 || true; fi; R "ba-cli -l Device.WiFi.Radio.3.PowerType=Indoor" >/dev/null 2>&1 || true; R "ba-cli -l Device.WiFi.AFC.Location.GPS=Device.DeviceInfo.Location.1." >/dev/null 2>&1 || true; R "ba-cli -l Device.WiFi.AFC.Location.Barometer=Device.DeviceInfo.Location.2." >/dev/null 2>&1 || true; if [ -n "$bar_idx" ]; then R "ba-cli Device.DeviceInfo.Location.${bar_idx}.-" >/dev/null 2>&1 || true; fi; if [ -n "$gps_idx" ]; then R "ba-cli Device.DeviceInfo.Location.${gps_idx}.-" >/dev/null 2>&1 || true; fi; if [ "$ca_backed" = 1 ]; then R "cp /tmp/afc_ca.pem.cram-bak /usr/share/ca-certificates/afc/afc_ca.pem" >/dev/null 2>&1 || true; fi; }
  $ trap cleanup_afc EXIT

Give the DUT a WAN address when it does not have one:

  $ wan_ip=$(R "ip -4 -o addr show dev wan 2>/dev/null | awk '{print \$4}' | sed 's#/.*##' | head -1" || true)
  $ if [ -z "$wan_ip" ]; then R 'ubus-cli Device.Bridging.Bridge.lan.Port.2.LowerLayers=""' >/dev/null 2>&1 || true; R 'ubus-cli Device.Ethernet.Link.2.LowerLayers="Device.Ethernet.Interface.2."' >/dev/null 2>&1 || true; R 'ubus-cli WANManager.WAN.demo_wanmode.PhysicalReference="Device.Ethernet.Interface.2"' >/dev/null 2>&1 || true; R 'ubus-cli WANManager.WANMode="demo_wanmode"' >/dev/null 2>&1 || true; sleep 8; wan_ip=$(R "ip -4 -o addr show dev wan 2>/dev/null | awk '{print \$4}' | sed 's#/.*##' | head -1" || true); fi
  $ echo "dut-wan-ip=${wan_ip:-none}"
  dut-wan-ip=(none|[0-9]+(\.[0-9]+){3}) (re)

Start the local HTTPS AFC server on the LAN client. A server left by a
previous run is stopped first.

  $ stop_afc_server

  $ SERVER_IP=$(ip route get "$TARGET_LAN_IP" 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}')
  $ echo "afc-server-ip=${SERVER_IP}"
  afc-server-ip=[0-9]+(\.[0-9]+){3} (re)

  $ sed "s/@SERVER_IP@/${SERVER_IP}/g" "${TESTDIR}/../scripts/afc/openssl.cnf.in" > "$afc_tmp/openssl.cnf"
  $ openssl req -x509 -newkey rsa:2048 -nodes -keyout "$afc_tmp/afc-ca.key" -out "$afc_tmp/afc-ca.crt" -subj "/CN=AFC Cram CA" -days 1 -addext basicConstraints=critical,CA:TRUE -addext keyUsage=critical,keyCertSign,cRLSign >/dev/null 2>&1
  $ openssl req -new -newkey rsa:2048 -nodes -keyout "$afc_tmp/afc-server.key" -out "$afc_tmp/afc-server.csr" -subj "/CN=${SERVER_IP}" >/dev/null 2>&1
  $ openssl x509 -req -in "$afc_tmp/afc-server.csr" -CA "$afc_tmp/afc-ca.crt" -CAkey "$afc_tmp/afc-ca.key" -CAcreateserial -out "$afc_tmp/afc-server.crt" -days 1 -extfile "$afc_tmp/openssl.cnf" -extensions v3_srv >/dev/null 2>&1
  $ python3 "${TESTDIR}/../scripts/afc_https_server.py" --cert "$afc_tmp/afc-server.crt" --key "$afc_tmp/afc-server.key" --port 8443 >"$afc_tmp/afc-server.log" 2>&1 &
  $ afc_pid=$!
  $ sleep 1
  $ python3 -c 'import ssl,urllib.request; c=ssl._create_unverified_context(); print(urllib.request.urlopen("https://127.0.0.1:8443/", context=c, timeout=5).read().decode())'
  {"status": "AFC server running"}

Bring up 6 GHz. Country and Indoor are already the DUT defaults.
check_wifi_defaults is not used: it requires hostapd to be stopped, and
on this DUT hostapd is already running. prplMesh is stopped so it does
not take the VAPs back.

  $ prplmesh_stop
  $ testbed_set_wifi_defaults

  $ enable_ap_sync 3 1 30
  AccessPoint.\d+.Enable=1 (re)

  $ enable_ap_sync 6 1 30
  AccessPoint.\d+.Enable=1 (re)

  $ enable_ap_sync 9 1 30
  AccessPoint.\d+.Enable=1 (re)

  $ R "pgrep -f '[h]ostapd' >/dev/null && echo hostapd-running || echo hostapd-down"
  hostapd-running

  $ sleep 5

Install the test CA as the file CABundle.3 already uses. Add two
Location instances without -l and keep the indexes ba-cli prints
(Location.+ with -l prints nothing, which is why the instance used to
be empty).

  $ R "cp /usr/share/ca-certificates/afc/afc_ca.pem /tmp/afc_ca.pem.cram-bak"
  $ ca_backed=1
  $ C "$afc_tmp/afc-ca.crt" "root@${TARGET_LAN_IP}:/tmp/afc-ca.crt" 2>/dev/null
  $ R "cp /tmp/afc-ca.crt /usr/share/ca-certificates/afc/afc_ca.pem"
  $ R "openssl x509 -in /usr/share/ca-certificates/afc/afc_ca.pem -noout -subject" | grep -o 'AFC Cram CA'
  AFC Cram CA
  $ C "${TESTDIR}/../scripts/afc/hostapd-inquiry.json" "root@${TARGET_LAN_IP}:/tmp/afc-inquiry.json" 2>/dev/null
  $ R "curl -sS --cacert /usr/share/ca-certificates/afc/afc_ca.pem -H 'Content-Type: application/json' --data @/tmp/afc-inquiry.json https://${SERVER_IP}:8443/availableSpectrumInquiry" | grep -o '"requestId": "1104284761"'
  "requestId": "1104284761"
  $ C "${TESTDIR}/../scripts/afc/location-gps.xml" "root@${TARGET_LAN_IP}:/tmp/afc-gps.xml" 2>/dev/null
  $ C "${TESTDIR}/../scripts/afc/location-barometer.xml" "root@${TARGET_LAN_IP}:/tmp/afc-barometer.xml" 2>/dev/null
  $ C "${TESTDIR}/../scripts/afc/set-dataobject.sh" "root@${TARGET_LAN_IP}:/tmp/afc-set-dataobject.sh" 2>/dev/null

  $ gps_idx=$(R "ba-cli Device.DeviceInfo.Location.+" | sed -n 's/.*Device\.DeviceInfo\.Location\.\([0-9][0-9]*\)\..*/\1/p' | tail -1)
  $ sleep 0.5
  $ bar_idx=$(R "ba-cli Device.DeviceInfo.Location.+" | sed -n 's/.*Device\.DeviceInfo\.Location\.\([0-9][0-9]*\)\..*/\1/p' | tail -1)
  $ echo "gps=${gps_idx} barometer=${bar_idx}"
  gps=[0-9]+ barometer=[0-9]+ (re)

  $ R "sh /tmp/afc-set-dataobject.sh ${gps_idx} /tmp/afc-gps.xml" >/dev/null
  $ R "sh /tmp/afc-set-dataobject.sh ${bar_idx} /tmp/afc-barometer.xml" >/dev/null
  $ R "ba-cli Device.DeviceInfo.Location.${gps_idx}.DataObject?" | grep -o '37.7749 -122.4194'
  37.7749 -122.4194

  $ R "ba-cli Device.DeviceInfo.Location.${gps_idx}.DataObject?" | grep -o 'METHOD_VALUE'
  METHOD_VALUE

  $ R "ba-cli Device.DeviceInfo.Location.${bar_idx}.DataObject?" | grep -o barometricHeight
  barometricHeight

  $ R "ba-cli Device.DeviceInfo.Location.${bar_idx}.DataObject?" | grep -o 'heightType'
  heightType

Point AFC at the local server and the new location instances. CABundle
stays Device.Security.CABundle.3. OCSP is off: this server has no OCSP
responder. mTLS stays off.

  $ wifi_dm "AFC.CABundle=Device.Security.CABundle.3"
  Device.WiFi.AFC.CABundle="Device.Security.CABundle.3"

  $ wifi_dm "AFC.ServerURL=https://${SERVER_IP}:8443/availableSpectrumInquiry"
  Device.WiFi.AFC.ServerURL="https://[0-9.]+:8443/availableSpectrumInquiry" (re)

  $ wifi_dm "AFC.Port=8443"
  Device.WiFi.AFC.Port=8443
  $ url_set=1

  $ wifi_dm "AFC.OCSPEnable=0"
  Device.WiFi.AFC.OCSPEnable=0

  $ wifi_dm "AFC.MTLSEnable=0"
  Device.WiFi.AFC.MTLSEnable=0

  $ wifi_dm "AFC.Location.GPS=Device.DeviceInfo.Location.${gps_idx}."
  Device.WiFi.AFC.Location.GPS="Device.DeviceInfo.Location.[0-9]+." (re)

  $ wifi_dm "AFC.Location.Barometer=Device.DeviceInfo.Location.${bar_idx}."
  Device.WiFi.AFC.Location.Barometer="Device.DeviceInfo.Location.[0-9]+." (re)

  $ dm_radio_powertype_set 3 StandardPower
  StandardPower

Enable AFC. afcd starts only after this, then hostapd is asked to inquire.
Stats are read after 120 seconds.

  $ wifi_dm "AFC.Enable=1"
  Device.WiFi.AFC.Enable=1

  $ sleep 120

  $ wifi_dm "AFC.Stats.GrantStatus?"
  Device.WiFi.AFC.Stats.GrantStatus="Success"

  $ wifi_dm "AFC.Stats.GrantResponse?"
  Device.WiFi.AFC.Stats.GrantResponse="The request is approved by the AFC System."

  $ wifi_dm "AFC.Stats.GrantExpiryTime?"
  Device.WiFi.AFC.Stats.GrantExpiryTime=20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z (re)

  $ R "pgrep -f '[h]ostapd' >/dev/null && echo hostapd-running || echo hostapd-down"
  hostapd-running

  $ wifi_dm "Radio.3.Status?"
  Device.WiFi.Radio.3.Status="Up"

  $ R "pgrep -x afcd >/dev/null && echo afcd-running || echo afcd-down"
  afcd-running

  $ R "ba-cli -j -l Device.WiFi.AFC.Status?" | grep -o GRANT_SUCCESS | head -1
  GRANT_SUCCESS

  $ R "ba-cli -l Device.WiFi.AFC.Stats.AvailableSpectrumResponse? > /tmp/afc-cram-resp.out; grep -o responseCode /tmp/afc-cram-resp.out | head -1"
  responseCode

  $ grep -q afc-inquiry-bytes "$afc_tmp/afc-server.log" && echo inquiry-seen
  inquiry-seen

Restore the default AFC server, Indoor power, and the original CA. Stop the local server.

  $ wifi_dm "AFC.Enable=0"
  Device.WiFi.AFC.Enable=0

  $ wifi_dm "AFC.ServerURL=https://testserver.wfatestorg.org/afc-simulator-api/availableSpectrumInquiry"
  Device.WiFi.AFC.ServerURL="https://testserver.wfatestorg.org/afc-simulator-api/availableSpectrumInquiry"

  $ wifi_dm "AFC.Port=443"
  Device.WiFi.AFC.Port=443
  $ url_set=0

  $ wifi_dm "AFC.Location.GPS=Device.DeviceInfo.Location.1."
  Device.WiFi.AFC.Location.GPS="Device.DeviceInfo.Location.1."

  $ wifi_dm "AFC.Location.Barometer=Device.DeviceInfo.Location.2."
  Device.WiFi.AFC.Location.Barometer="Device.DeviceInfo.Location.2."

  $ R "ba-cli Device.DeviceInfo.Location.${bar_idx}.-" >/dev/null
  $ R "ba-cli Device.DeviceInfo.Location.${gps_idx}.-" >/dev/null
  $ bar_idx=""
  $ gps_idx=""

  $ R "cp /tmp/afc_ca.pem.cram-bak /usr/share/ca-certificates/afc/afc_ca.pem"
  $ ca_backed=0

  $ dm_radio_powertype_set 3 Indoor
  Indoor

  $ enable_ap_sync 3 0
  AccessPoint.\d+.Enable=0 (re)

  $ enable_ap_sync 6 0
  AccessPoint.\d+.Enable=0 (re)

  $ enable_ap_sync 9 0
  AccessPoint.\d+.Enable=0 (re)

  $ stop_afc_server

  $ prplmesh_start

  $ R logger -t cram "$TESTFILE finished!"
