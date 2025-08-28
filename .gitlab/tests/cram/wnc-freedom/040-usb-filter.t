Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Assure SanDisk USB flash disk is plugged in and allowed:

  $ R 'ba-cli -lj "ubus-protected;USB.USBHosts.Host.2.Device.[SysfsId=="2-1.2"].?" 2>&1 | grep -v "^>" | sed -n "4p"' | jq .
  [
    {
      "USB.USBHosts.Host.2.Device.[0-9]+.": { (re)
        "Port": 1,
        "DeviceClass": "00",
        "VendorID": 1921,
        "ProductID": 21905,
        "IsSelfPowered": 0,
        "SysfsId": "2-1.2",
        "Rate": "Super",
        "Parent": "",
        "SysDevName": "/dev/sda",
        "USBVersion": "3.20",
        "IsSuspended": 0,
        "USBPort": "Device.USB.Port.1.",
        "ProductClass": "SanDisk 3.2Gen1",
        "SerialNumber": "*", (glob)
        "ConfigurationNumberOfEntries": 1,
        "DeviceProtocol": "00",
        "Manufacturer": "USB",
        "DeviceSubClass": "00",
        "DeviceVersion": 100,
        "IsAllowed": 1,
        "DeviceNumber": 2,
        "MaxChildren": 0
      },
      "USB.USBHosts.Host.2.Device.[0-9]+.Configuration.1.": { (re)
        "ConfigurationNumber": 1,
        "InterfaceNumberOfEntries": 1
      },
      "USB.USBHosts.Host.2.Device.[0-9]+.Configuration.1.Interface.1.": { (re)
        "InterfaceClass": "08",
        "InterfaceProtocol": "50",
        "InterfaceSubClass": "06",
        "InterfaceNumber": 0
      }
    }
  ]

Disallow all USB devices:

  $ R "ba-cli -ajl 'USB.USBHosts.AllowAllDevices=0' | awk NF"
  [{"USB.USBHosts.":{"AllowAllDevices":0}}]

Check USB flash disk is no longer allowed:

  $ R 'ba-cli -al "ubus-protected;USB.USBHosts.Host.2.Device.[SysfsId==\"2-1.2\"].IsAllowed?" 2>&1 ' | grep -v "^>" | sed -n "4p" | awk NF
  0

  $ R 'cat /sys/bus/usb/devices/2-1.2/authorized'
  0

Simulate unplugging USB flash disk:

  $ R 'echo "2-1.2" | tee /sys/bus/usb/drivers/usb/unbind'
  [0-9]+\-[0-9]+\.[0-9]+ (re)

Simulate plugging USB flash disk in again:

  $ R 'echo "2-1.2" | tee /sys/bus/usb/drivers/usb/bind'
  [0-9]+\-[0-9]+\.[0-9]+ (re)

Check USB flash disk is no longer allowed:

  $ R 'ba-cli -al "ubus-protected;USB.USBHosts.Host.1.Device.[SysfsId==\"2-1.2\"].IsAllowed?" 2>&1 ' | grep -v "^>" | sed -n "4p" | awk NF
  0

  $ R 'cat /sys/bus/usb/devices/2-1.2/authorized'
  0

Add whitelist instance to allow USB flash disk:

  $ R "ba-cli -ajl 'USB.USBHosts.AllowedDevice.+{Alias=\"usb-flash\", Enable=true, DeviceClass=\"00\",DeviceProtocol=\"00\", DeviceSubClass=\"00\", ProductID=\"5591\",VendorID=\"781\", Interfaces=\"08:06:50\"}' | awk NF"
  {"USB\.USBHosts\.AllowedDevice\.[0-9]+\.":{"Alias":"usb-flash"}} (re)

Check USB flash disk is allowed:

  $ R 'ba-cli -al "ubus-protected;USB.USBHosts.Host.1.Device.[SysfsId==\"2-1.2\"].IsAllowed?" 2>&1 ' | grep -v "^>" | sed -n "4p" | awk NF
  1

  $ R 'cat /sys/bus/usb/devices/2-1.2/authorized'
  1

Allow all USB devices again:

  $ R "ba-cli -ajl 'USB.USBHosts.AllowAllDevices=1' | awk NF"
  [{"USB.USBHosts.":{"AllowAllDevices":1}}]

Check USB flash disk is allowed:

  $ R 'ba-cli -al "ubus-protected;USB.USBHosts.Host.1.Device.[SysfsId==\"2-1.2\"].IsAllowed?" 2>&1 ' | grep -v "^>" | sed -n "4p" | awk NF
  1

  $ R 'cat /sys/bus/usb/devices/2-1.2/authorized'
  1

Remove whitelist entry:

  $ R "ba-cli -ajl 'USB.USBHosts.AllowedDevice.usb-flash.-' | awk NF"
  ["USB\.USBHosts\.AllowedDevice\.[0-9]+\."] (re)

Check USB flash disk is allowed:

  $ R 'ba-cli -al "ubus-protected;USB.USBHosts.Host.1.Device.[SysfsId==\"2-1.2\"].IsAllowed?" 2>&1 ' | grep -v "^>" | sed -n "4p" | awk NF
  1

  $ R 'cat /sys/bus/usb/devices/2-1.2/authorized'
  1

