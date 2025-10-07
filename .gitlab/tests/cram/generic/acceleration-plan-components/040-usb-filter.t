Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

If test is running on a Mozart, Turris, OSPv1 or Haze, lets skip the test as there is no USB storage device attached:

  $ if echo "$CI_JOB_NAME" | grep -q -E "(Mozart|Turris|Haze|HDK-3)"; then exit 80; fi

Create alias for finding SysfsId:

  $ export ID=$(if echo "$CI_JOB_NAME" | grep -q -E "Freedom"; then echo "2-1.2"; else echo "2-1"; fi)

Make sure the USB device is plugged in:

  $ R "test -d /sys/bus/usb/devices/$(echo $ID) && echo OK"
  OK

Simulate unplugging USB flash disk:

  $ R "echo \"$(echo $ID)\" | tee /sys/bus/usb/drivers/usb/unbind"
  [0-9]+\-[0-9]+(\.[0-9]+)? (re)

Simulate plugging USB flash disk in to be sure it is recognized:

  $ R "echo \"$(echo $ID)\" | tee /sys/bus/usb/drivers/usb/bind"
  [0-9]+\-[0-9]+(\.[0-9]+)? (re)

Wait for DM to update:

  $ sleep 5

Assure SanDisk USB flash disk is plugged in and allowed:

  $ R 'ba-cli -lj "ubus-protected;USB.USBHosts.Host.2.Device.[ProductClass==\"SanDisk 3.2Gen1\"].?" 2>&1 | grep -v "^>" | sed -n "4p"' | jq .
  [
    {
      "USB.USBHosts.Host.2.Device.[0-9]+.": { (re)
        "Port": 1,
        "DeviceClass": "00",
        "VendorID": 1921,
        "ProductID": 21905,
        "IsSelfPowered": 0,
        "SysfsId": "2-1(\.2)?", (re)
        "Rate": "Super",
        "Parent": "",
        "SysDevName": "/dev/(2-1(\.2)?|sda)", (re)
        "USBVersion": "3.20",
        "IsSuspended": 0,
        "USBPort": "Device.USB.Port.1.",
        "ProductClass": "SanDisk 3.2Gen1",
        "SerialNumber": "*", (glob)
        "DeviceProtocol": "00",
        "ConfigurationNumberOfEntries": 1,
        "Manufacturer": "USB",
        "DeviceSubClass": "00",
        "DeviceVersion": 100,
        "IsAllowed": 1,
        "DeviceNumber": 2,
        "MaxChildren": 0
      },
      "USB.USBHosts.Host.2.Device.[0-9]+.Configuration.": {}, (re)
      "USB.USBHosts.Host.2.Device.[0-9]+.Configuration.1.Interface.1.": { (re)
        "InterfaceClass": "08",
        "InterfaceProtocol": "50",
        "InterfaceSubClass": "06",
        "InterfaceNumber": 0
      },
      "USB.USBHosts.Host.2.Device.[0-9]+.Configuration.1.": { (re)
        "ConfigurationNumber": 1,
        "InterfaceNumberOfEntries": 1
      },
      "USB.USBHosts.Host.2.Device.[0-9]+.Configuration.1.Interface.": {} (re)
    }
  ]

Disallow all USB devices:

  $ R "ba-cli -ajl 'USB.USBHosts.AllowAllDevices=0' | awk NF"
  [{"USB.USBHosts.":{"AllowAllDevices":0}}]

Check USB flash disk is no longer allowed:

  $ R 'ba-cli -al "ubus-protected;USB.USBHosts.Host.2.Device.[ProductClass==\"SanDisk 3.2Gen1\"].IsAllowed?" 2>&1 ' | grep -v "^>" | sed -n "4p" | awk NF
  0

  $ R "cat /sys/bus/usb/devices/$(echo $ID)/authorized"
  0

Simulate unplugging USB flash disk:

  $ R "echo \"$(echo $ID)\" | tee /sys/bus/usb/drivers/usb/unbind"
  [0-9]+\-[0-9]+(\.[0-9]+)? (re)

Simulate plugging USB flash disk in again:

  $ R "echo \"$(echo $ID)\" | tee /sys/bus/usb/drivers/usb/bind"
  [0-9]+\-[0-9]+(\.[0-9]+)? (re)

Check USB flash disk is no longer allowed:

  $ R 'ba-cli -al "ubus-protected;USB.USBHosts.Host.2.Device.[ProductClass==\"SanDisk 3.2Gen1\"].IsAllowed?" 2>&1 ' | grep -v "^>" | sed -n "4p" | awk NF
  0

  $ R "cat /sys/bus/usb/devices/$(echo $ID)/authorized"
  0

Add whitelist instance to allow USB flash disk:

  $ R "ba-cli -ajl 'USB.USBHosts.AllowedDevice.+{Alias=\"usb-flash\", Enable=true, DeviceClass=\"00\",DeviceProtocol=\"00\", DeviceSubClass=\"00\", ProductID=\"5591\",VendorID=\"781\", Interfaces=\"08:06:50\"}' | awk NF"
  {"USB\.USBHosts\.AllowedDevice\.[0-9]+\.":{"Alias":"usb-flash"}} (re)

Check USB flash disk is allowed:

  $ R 'ba-cli -al "ubus-protected;USB.USBHosts.Host.2.Device.[ProductClass==\"SanDisk 3.2Gen1\"].IsAllowed?" 2>&1 ' | grep -v "^>" | sed -n "4p" | awk NF
  1

  $ R "cat /sys/bus/usb/devices/$(echo $ID)/authorized"
  1

Allow all USB devices again:

  $ R "ba-cli -ajl 'USB.USBHosts.AllowAllDevices=1' | awk NF"
  [{"USB.USBHosts.":{"AllowAllDevices":1}}]

Check USB flash disk is allowed:

  $ R 'ba-cli -al "ubus-protected;USB.USBHosts.Host.2.Device.[ProductClass==\"SanDisk 3.2Gen1\"].IsAllowed?" 2>&1 ' | grep -v "^>" | sed -n "4p" | awk NF
  1

  $ R "cat /sys/bus/usb/devices/$(echo $ID)/authorized"
  1

Remove whitelist entry:

  $ R "ba-cli -ajl 'USB.USBHosts.AllowedDevice.usb-flash.-' | awk NF"
  ["USB\.USBHosts\.AllowedDevice\.[0-9]+\."] (re)

Check USB flash disk is allowed:

  $ R 'ba-cli -al "ubus-protected;USB.USBHosts.Host.2.Device.[ProductClass==\"SanDisk 3.2Gen1\"].IsAllowed?" 2>&1 ' | grep -v "^>" | sed -n "4p" | awk NF
  1

  $ R "cat /sys/bus/usb/devices/$(echo $ID)/authorized"
  1

Cleanup: Unplug and replug to have a clean USB DM after the test:

  $ R "echo \"$(echo $ID)\" | tee /sys/bus/usb/drivers/usb/unbind"
  [0-9]+\-[0-9]+(\.[0-9]+)? (re)

  $ R "echo \"$(echo $ID)\" | tee /sys/bus/usb/drivers/usb/bind"
  [0-9]+\-[0-9]+(\.[0-9]+)? (re)

