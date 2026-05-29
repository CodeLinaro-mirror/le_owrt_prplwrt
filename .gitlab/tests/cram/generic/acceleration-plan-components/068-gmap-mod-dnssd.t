Create R alias:
  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Ensure avahi-daemon is running:

  $ sudo service dbus start 2>&1 | grep -v "unable to resolve host" | tee /dev/stderr | grep -q "Starting system message bus: dbus." && echo "dbus started OK" || echo "dbus may have failed to start"
  Starting system message bus: dbus.
  dbus started OK
  $ avahi-daemon --check 2>/dev/null || (sudo avahi-daemon -D >/dev/null 2>&1 && sleep 2)
  $ avahi-daemon --check && echo "avahi-daemon running"
  avahi-daemon running

Ensure DNS.SD service is enabled on HGW:

  $ R "ba-cli 'DNSSD.Enable?'" | grep -Ev '^(>|$)'
  DNSSD.Enable=1

Test 1: Service Advertisement (mDNS announcement):

  $ avahi-publish-service CramTestService1 _http._tcp 8080 "path=/test1" >/dev/null 2>&1 &
  $ AVAHI_PID1=$!
  $ sleep 15

Verify new entry appears in TR-181 datamodel:

  $ R "ba-cli --json 'Device.DNS.SD.Service.[InstanceName==\"CramTestService1\"].?' | sed -n '2p'" | jq --sort-keys '.[0]' | grep -v -E '(LastUpdate)'
  {
    "Device.DNS.SD.Service.\d+.": { (re)
      "ApplicationProtocol": "http",
      "Domain": "",
      "Host": "Device.Hosts.Host.\d+", (re)
      "InstanceName": "CramTestService1",
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

Verify entry appears in gmap datamodel:

  $ R "ba-cli --json 'Devices.Device.*.mDNSService.[Name==\"CramTestService1\"].?' | sed -n '2p'" | jq --sort-keys '.[0]'
  {
    "Devices.Device.\d+.mDNSService.\d+.": { (re)
      "Alias": "_http__tcp",
      "Domain": "local",
      "Name": "CramTestService1",
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

Wait for removal to propagate:

  $ sleep 15

Verify entry is removed from TR-181:

  $ R 'ba-cli "Device.DNS.SD.Service.[InstanceName==\"CramTestService1\"].?"' 2>&1 | grep -Ev '^(>|$)'
  No data found

Verify entry is removed from gmap datamodel:

  $ R 'ba-cli "Devices.Device.*.mDNSService.[Name==\"CramTestService1\"].?"' | grep -Ev '^(>|$)' | grep 'CramTestService1' || echo "Not found"
  Not found

Cleanup:

  $ kill $AVAHI_PID1 2>/dev/null || true
  $ sudo service dbus stop >/dev/null 2>&1
