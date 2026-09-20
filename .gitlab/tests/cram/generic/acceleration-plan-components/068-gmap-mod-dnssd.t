Create R alias:
  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Find the interface and address that route to the DUT.  gmap needs this
host's LAN-facing address before it tags the device, and avahi-daemon below
is confined to the same interface so it does not announce on whatever other
network the job container sits on, such as the docker executor's default
bridge that concurrent jobs on a runner share:

  $ ROUTE="$(ip -4 route get $TARGET_LAN_IP 2>/dev/null)"
  $ CLIENT_IP="$(printf '%s' "$ROUTE" | sed -n 's/.* src \([0-9.]*\).*/\1/p')"
  $ IFACE="$(printf '%s' "$ROUTE" | sed -n 's/.* dev \([^ ]*\).*/\1/p')"
  $ test -n "$CLIENT_IP" && test -n "$IFACE" && echo "client ip and interface found" || echo "no route to $TARGET_LAN_IP"
  client ip and interface found

Ensure avahi-daemon is running, confined to $IFACE.  Kill any instance
already running under the default, unconfined configuration first:

  $ sudo service dbus start 2>&1 | grep -v "unable to resolve host" | tee /dev/stderr | grep -q "Starting system message bus: dbus." && echo "dbus started OK" || echo "dbus may have failed to start"
  Starting system message bus: dbus.
  dbus started OK
  $ cat > "$CRAMTMP/avahi-daemon.conf" << EOF
  > [server]
  > use-ipv4=yes
  > use-ipv6=yes
  > allow-interfaces=$IFACE
  > ratelimit-interval-usec=1000000
  > ratelimit-burst=1000
  > [publish]
  > publish-hinfo=no
  > publish-workstation=no
  > EOF
  $ if avahi-daemon --check 2>/dev/null; then sudo avahi-daemon -k && sleep 1; fi
  $ sudo avahi-daemon -D -f "$CRAMTMP/avahi-daemon.conf" >/dev/null 2>&1 && sleep 2
  $ avahi-daemon --check && echo "avahi-daemon running"
  avahi-daemon running

Ensure DNS.SD service is enabled on HGW:

  $ R "ba-cli 'DNSSD.Enable?'" | grep -Ev '^(>|$)'
  DNSSD.Enable=1

Set the DNSSD.RemoveServiceTimeout to 5 seconds (5000ms) to ensure quick service removal detection:

  $ remove_timeout=5000
  $ R "ba-cli -j -l 'protected; DNSSD.RemoveServiceTimeout=$remove_timeout'" >/dev/null

Check the removal timeout took effect and derive the removal wait from it:

  $ R "ba-cli -j -l 'protected; DNSSD.RemoveServiceTimeout?' | grep RemoveServiceTimeout"
  .*"RemoveServiceTimeout":5000.* (re)
  $ remove_tries=$(( (remove_timeout / 1000 + 25) / 2 ))

Every query below filters on the exact service name, and avahi renames a
service whose name is already taken on the interface ("CramTestService1 #2")
instead of failing, so give each run a name of its own:

  $ SVC="CramTest-$(head -c4 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  $ echo "$SVC" | grep -Eq '^CramTest-[0-9a-f]{8}$' && echo "service name ok"
  service name ok

Query the gmap datamodel for the test service.  ba-cli answers a missing object
with a plain "ERROR:" line, which is not JSON, so feed jq only when the reply
parses and otherwise print what the DUT actually said -- piping the reply
straight into jq turns every distinct product error into the same unreadable
"Invalid numeric literal" message:

  $ gmap_mdns() { reply="$(R "ba-cli --json 'Devices.Device.*.mDNSService.[Name==\"$SVC\"].?' | sed -n '2p'")"; \
  > printf '%s' "$reply" | jq --sort-keys '.[0]' 2>/dev/null || printf '%s\n' "${reply:-<empty reply>}"; }

Devices.Device.*.mDNSService. is a gmap MIB, attached only to a device tagged
"dnssd".  gmap-mod-dnssd sets that tag from a single gmap_devices_findByIp()
lookup 2s after the DNSSD instance appears, and drops the service permanently
when that lookup fails, so wait for gmap to know this host before advertising
anything -- polling afterwards cannot recover a service already dropped:

  $ gmap_knows_host() { R "ba-cli --json 'Devices.Device.*.IPv4Address.[Address==\"$CLIENT_IP\"].?' | sed -n '2p'" | grep -q "$CLIENT_IP"; }
  $ for i in $(seq 1 30); do gmap_knows_host && break; sleep 2; done
  $ gmap_knows_host && echo "gmap knows this host" || echo "gmap does not know this host"
  gmap knows this host

Test 1: Service Advertisement (mDNS announcement):

  $ avahi-publish-service "$SVC" _http._tcp 8080 "path=/test1" >/dev/null 2>"$CRAMTMP/avahi-publish.log" &
  $ AVAHI_PID1=$!

Wait for the advertisement to reach the TR-181 datamodel:

  $ for i in $(seq 1 15); do R "ba-cli --json 'Device.DNS.SD.Service.[InstanceName==\"$SVC\"].?' | sed -n '2p'" | grep -q "$SVC" && break; sleep 2; done
  $ kill -0 $AVAHI_PID1

Check that avahi kept the requested name; a renamed service means another
publisher on the same interface got there first:

  $ grep -o "Established under name '[^']*'" "$CRAMTMP/avahi-publish.log"
  Established under name 'CramTest-[0-9a-f]{8}' (re)

Verify new entry appears in TR-181 datamodel:

  $ R "ba-cli --json 'Device.DNS.SD.Service.[InstanceName==\"$SVC\"].?' | sed -n '2p'" | jq --sort-keys '.[0]' | grep -v -E '(LastUpdate)'
  {
    "Device.DNS.SD.Service.\d+.": { (re)
      "ApplicationProtocol": "http",
      "Domain": "",
      "Host": "Device.Hosts.Host.\d+", (re)
      "InstanceName": "CramTest-[0-9a-f]{8}", (re)
      "Port": 8080,
      "Priority": 0,
      "Status": "LeaseActive",
      "Target": ".*", (re)
      "TextRecordNumberOfEntries": 1,
      "TimeToLive": 4294967295,
      "TransportProtocol": "TCP",
      "Weight": 0
    },
    "Device.DNS.SD.Service.\d+.TextRecord.\d+.": { (re)
      "Key": "path",
      "Value": "/test1"
    }
  }

Wait for the advertisement to reach the gmap datamodel:

  $ for i in $(seq 1 30); do gmap_mdns | grep -q "\"Name\": \"$SVC\"" && break; sleep 2; done

Verify entry appears in gmap datamodel:

  $ gmap_mdns
  {
    "Devices.Device.\d+.mDNSService.\d+.": { (re)
      "Alias": "_http__tcp",
      "Domain": "local",
      "Name": "CramTest-[0-9a-f]{8}", (re)
      "Port": 8080,
      "ServiceName": "_http._tcp"
    },
    "Devices.Device.\d+.mDNSService.\d+.TextRecord.\d+.": { (re)
      "Alias": "path",
      "Key": "path",
      "Value": "/test1"
    }
  }

Test 2: Explicit Departure (Graceful shutdown):

  $ kill $AVAHI_PID1 2>/dev/null

Wait for the removal to clear the TR-181 datamodel:

  $ for i in $(seq 1 $remove_tries); do R "ba-cli --json 'Device.DNS.SD.Service.[InstanceName==\"$SVC\"].?' | sed -n '2p'" | grep -q "$SVC" || break; sleep 2; done

Verify the DNSSD service is still answering:

  $ R "ba-cli 'DNSSD.Enable?'" | grep -Ev '^(>|$)'
  DNSSD.Enable=1

Verify entry is removed from TR-181:

  $ R "ba-cli --json 'Device.DNS.SD.Service.[InstanceName==\"$SVC\"].?' | sed -n '2p'" | jq --sort-keys '.[0]'
  {}

Wait for the removal to clear the gmap datamodel:

  $ for i in $(seq 1 $remove_tries); do gmap_mdns | grep -q "\"Name\": \"$SVC\"" || break; sleep 2; done

Verify entry is removed from gmap datamodel:

  $ gmap_reply="$(gmap_mdns)"
  $ case "$gmap_reply" in "{}"|*"object not found"*) echo "removed";; *) printf '%s\n' "$gmap_reply";; esac
  removed

Cleanup and restore default DNSSD settings:

  $ kill $AVAHI_PID1 2>/dev/null || true
  $ R "ba-cli -j -l 'protected; DNSSD.RemoveServiceTimeout=300000'" >/dev/null
  $ sudo service dbus stop >/dev/null 2>&1
