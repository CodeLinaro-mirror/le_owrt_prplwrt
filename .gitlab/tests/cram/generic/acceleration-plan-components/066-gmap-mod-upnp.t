Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Install minidlna if not already present:

  $ sudo sed -i 's|http://deb.debian.org/debian|http://archive.debian.org/debian|g' /etc/apt/sources.list 2>/dev/null
  $ sudo sed -i 's|http://deb.debian.org/debian-security|http://archive.debian.org/debian-security|g' /etc/apt/sources.list 2>/dev/null
  $ which minidlnad >/dev/null 2>&1 || (sudo apt-get update >/dev/null 2>&1 && sudo apt-get install -y minidlna >/dev/null 2>&1)

Test 1: Service Advertisement (start minidlna):

Create minidlna configuration:

  $ mkdir -p /tmp/minidlna-test/media
  $ cat > /tmp/minidlna-test/minidlna.conf << EOF
  > port=8200
  > network_interface=$TESTBED_LAN_INTERFACE
  > friendly_name=CramTestUPnPDevice
  > serial=12345678
  > model_number=1
  > media_dir=/tmp/minidlna-test/media
  > db_dir=/tmp/minidlna-test/db
  > log_dir=/tmp/minidlna-test/log
  > inotify=no
  > enable_tivo=no
  > strict_dlna=no
  > notify_interval=5
  > max_connections=1
  > EOF

Start minidlna:

  $ minidlnad -f /tmp/minidlna-test/minidlna.conf -P /tmp/minidlna-test/minidlna.pid >/dev/null 2>&1 &
  $ sleep 5

Verify minidlna is running (check if process exists):

  $ test -f /tmp/minidlna-test/minidlna.pid && kill -0 $(cat /tmp/minidlna-test/minidlna.pid) 2>/dev/null && echo "minidlna running"
  minidlna running

Verify device entry appears in TR-181 datamodel:

  $ R "ba-cli --json 'Device.UPnP.Description.DeviceInstance.[FriendlyName==\"CramTestUPnPDevice\"].?' | sed -n '2p'" | jq --sort-keys '.[0]'
  {
    "Device.UPnP.Description.DeviceInstance.\d+.": { (re)
      "DeviceCategory": "",
      "DeviceType": "urn:schemas-upnp-org:device:MediaServer:1",
      "DiscoveryDevice": "Device.UPnP.Discovery.Device.\d+", (re)
      "FriendlyName": "CramTestUPnPDevice",
      "Manufacturer": "Justin Maggard",
      "ManufacturerOUI": "",
      "ManufacturerURL": "http://www.netgear.com/",
      "ModelDescription": "MiniDLNA on Linux",
      "ModelName": "Windows Media Connect compatible (MiniDLNA)",
      "ModelNumber": "1",
      "ModelURL": "http://www.netgear.com",
      "ParentDevice": "",
      "PresentationURL": "/",
      "SerialNumber": "12345678",
      "UDN": "4d696e69-444c-164e-9d41-.*", (re)
      "UPC": ""
    }
  }
  

Verify device entry appears in gmap datamodel:

  $ R "ba-cli --json 'Devices.Device.[FriendlyName==\"CramTestUPnPDevice\"].?' | sed -n '2p'" | jq --sort-keys '.[0]' | grep -v -E '(FirstSeen|LastConnection)'
  {
    "Devices.Device.\d+.": { (re)
      "Active": 0,
      "Alias": "UPnP-\d+", (re)
      "DiscoverySource": "gmap_upnp",
      "FriendlyName": "CramTestUPnPDevice",
      "Key": "UPnP-\d+", (re)
      "LastChanged": "0001-01-01T00:00:00Z",
      "Manufacturer": "Justin Maggard",
      "ManufacturerURL": "http://www.netgear.com/",
      "Master": "",
      "ModelDescription": "MiniDLNA on Linux",
      "ModelName": "Windows Media Connect compatible (MiniDLNA)",
      "ModelNumber": "1",
      "ModelURL": "http://www.netgear.com",
      "Name": "Windows Media Connect compatible (MiniDLNA)",
      "PresentationURL": "/",
      "SerialNumber": "12345678",
      "Server": "Debian DLNADOC/1.50 UPnP/1.0 MiniDLNA/1.2.1",
      "Tags": "upnp logical",
      "Type": "urn:schemas-upnp-org:device:MediaServer:1",
      "UDN": "4d696e69-444c-164e-9d41-.*", (re)
      "UPC": ""
    },
    "Devices.Device.\d+.Link.\d+.": { (re)
      "Alias": "gmap_upnp_service"
    },
    "Devices.Device.\d+.Link.\d+.UDevice.\d+.": { (re)
      "Alias": "ID-.*", (re)
      "Type": "upnp"
    },
    "Devices.Device.\d+.Names.\d+.": { (re)
      "Name": "Windows Media Connect compatible (MiniDLNA)",
      "Source": "default",
      "Suffix": ""
    },
    "Devices.Device.\d+.Service.\d+.": { (re)
      "ControlURL": "/ctl/ContentDir",
      "EventSubURL": "/evt/ContentDir",
      "SCPDURL": "/ContentDir.xml",
      "ServiceId": "urn:upnp-org:serviceId:ContentDirectory",
      "ServiceType": "urn:schemas-upnp-org:service:ContentDirectory:1"
    },
    "Devices.Device.\d+.Service.\d+.": { (re)
      "ControlURL": "/ctl/ConnectionMgr",
      "EventSubURL": "/evt/ConnectionMgr",
      "SCPDURL": "/ConnectionMgr.xml",
      "ServiceId": "urn:upnp-org:serviceId:ConnectionManager",
      "ServiceType": "urn:schemas-upnp-org:service:ConnectionManager:1"
    },
    "Devices.Device.\d+.Service.\d+.": { (re)
      "ControlURL": "/ctl/X_MS_MediaReceiverRegistrar",
      "EventSubURL": "/evt/X_MS_MediaReceiverRegistrar",
      "SCPDURL": "/X_MS_MediaReceiverRegistrar.xml",
      "ServiceId": "urn:microsoft.com:serviceId:X_MS_MediaReceiverRegistrar",
      "ServiceType": "urn:microsoft.com:service:X_MS_MediaReceiverRegistrar:1"
    },
    "Devices.Device.\d+.UDevice.\d+.": { (re)
      "Alias": "ID-.*", (re)
      "Type": "upnp"
    }
  }

Test 2: Explicit Departure (Stop minidlna):

  $ kill $(cat /tmp/minidlna-test/minidlna.pid 2>/dev/null) 2>/dev/null

Wait for byebye to propagate (based on SSDP TTL):

  $ sleep 35

Verify entries are deactivated from gmap datamodel:

  $ R 'ba-cli "Devices.Device.[FriendlyName==\"CramTestUPnPDevice\"].Service.*.?"' | grep -v '>'
  No data found


Cleanup:

  $ rm -rf /tmp/minidlna-test
