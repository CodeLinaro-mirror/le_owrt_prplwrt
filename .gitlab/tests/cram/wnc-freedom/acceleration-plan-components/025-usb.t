Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Assure USB. datamodel content with single SanDisk USB flash disk plugged in:

  $ R "ba-cli -lj USB.?" | jq .
  [
    {
      "USB.Port.1.": {
        "Standard": "2.0",
        "Name": "usb-Port-1",
        "Power": "Unknown",
        "Alias": "usb-Port-1",
        "Rate": "High",
        "Type": "Host",
        "Receptacle": "Standard-A"
      },
      "USB.USBHosts.": {
        "AllowAllDevices": 1,
        "AllowedDeviceNumberOfEntries": 0,
        "HostNumberOfEntries": 2
      },
      "USB.USBHosts.Host.1.": {
        "USBVersion": "2.10",
        "DeviceNumberOfEntries": 0,
        "PowerManagementEnable": 0,
        "Enable": 1,
        "Name": "usb-Host-1",
        "Reset": 0,
        "Alias": "usb-Host-1",
        "Type": "xHCI"
      },
      "USB.Interface.1.": {
        "Port": "",
        "Upstream": 0,
        "MaxBitRate": 0,
        "Status": "Down",
        "LowerLayers": "",
        "MACAddress": "",
        "LastChange": 0,
        "Enable": 0,
        "Name": "usb-Interface-1",
        "Alias": "usb-Interface-1"
      },
      "USB.Interface.1.Stats.": {
        "MulticastPacketsSent": 0,
        "ErrorsSent": 0,
        "BroadcastPacketsSent": 0,
        "BytesSent": 0,
        "PacketsSent": 0,
        "BytesReceived": 0,
        "DiscardPacketsReceived": 0,
        "ErrorsReceived": 0,
        "MulticastPacketsReceived": 0,
        "UnknownProtoPacketsReceived": 0,
        "UnicastPacketsSent": 0,
        "UnicastPacketsReceived": 0,
        "PacketsReceived": 0,
        "DiscardPacketsSent": 0,
        "BroadcastPacketsReceived": 0
      },
      "USB.": {
        "InterfaceNumberOfEntries": 1,
        "PortNumberOfEntries": 1
      },
      "USB.USBHosts.Host.2.Device.[0-9]+.Configuration.1.Interface.1.": { (re)
        "InterfaceClass": "08",
        "InterfaceProtocol": "50",
        "InterfaceSubClass": "06",
        "InterfaceNumber": 0
      },
      "USB.USBHosts.Host.2.Device.[0-9]+.": { (re)
        "Port": 1,
        "DeviceClass": "00",
        "VendorID": 1921,
        "ProductID": 21905,
        "IsSelfPowered": 0,
        "Rate": "Super",
        "Parent": "",
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
      "USB.USBHosts.Host.2.": {
        "USBVersion": "3.20",
        "DeviceNumberOfEntries": 1,
        "PowerManagementEnable": 0,
        "Enable": 1,
        "Name": "usb-Host-2",
        "Reset": 0,
        "Alias": "usb-Host-2",
        "Type": "xHCI"
      },
      "USB.USBHosts.Host.2.Device.[0-9]+.Configuration.1.": { (re)
        "ConfigurationNumber": 1,
        "InterfaceNumberOfEntries": 1
      }
    }
  ]
