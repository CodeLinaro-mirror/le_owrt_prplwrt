Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Assure USB. datamodel content with single SanDisk USB flash disk plugged in:

  $ R "ba-cli -lj USB.?" | jq --sort-keys '.[0]'
  {
    "USB.": {
      "InterfaceNumberOfEntries": 1,
      "PortNumberOfEntries": 4
    },
    "USB.Interface.1.": {
      "Alias": "usb-Interface-1",
      "Enable": 0,
      "LastChange": 0,
      "LowerLayers": "",
      "MACAddress": "",
      "MaxBitRate": 0,
      "Name": "usb-Interface-1",
      "Port": "",
      "Status": "Down",
      "Upstream": 0
    },
    "USB.Interface.1.Stats.": {
      "BroadcastPacketsReceived": 0,
      "BroadcastPacketsSent": 0,
      "BytesReceived": 0,
      "BytesSent": 0,
      "DiscardPacketsReceived": 0,
      "DiscardPacketsSent": 0,
      "ErrorsReceived": 0,
      "ErrorsSent": 0,
      "MulticastPacketsReceived": 0,
      "MulticastPacketsSent": 0,
      "PacketsReceived": 0,
      "PacketsSent": 0,
      "UnicastPacketsReceived": 0,
      "UnicastPacketsSent": 0,
      "UnknownProtoPacketsReceived": 0
    },
    "USB.Port.1.": {
      "Alias": "cpe-Port-1",
      "Name": "usb-1-1-port1",
      "Power": "Unknown",
      "PowerCapability": "On,Off",
      "PowerStatus": "On",
      "Rate": "High",
      "Receptacle": "Standard-A",
      "Standard": "[0-9]+.[0-9]+", (re)
      "Type": "Host"
    },
    "USB.Port.2.": {
      "Alias": "cpe-Port-2",
      "Name": "usb-1-1-port2",
      "Power": "Unknown",
      "PowerCapability": "On,Off",
      "PowerStatus": "On",
      "Rate": "High",
      "Receptacle": "Standard-A",
      "Standard": "[0-9]+.[0-9]+", (re)
      "Type": "Host"
    },
    "USB.Port.3.": {
      "Alias": "cpe-Port-3",
      "Name": "usb-1-1-port3",
      "Power": "Unknown",
      "PowerCapability": "On,Off",
      "PowerStatus": "On",
      "Rate": "High",
      "Receptacle": "Standard-A",
      "Standard": "[0-9]+.[0-9]+", (re)
      "Type": "Host"
    },
    "USB.Port.4.": {
      "Alias": "cpe-Port-4",
      "Name": "usb-1-1-port4",
      "Power": "Unknown",
      "PowerCapability": "On,Off",
      "PowerStatus": "On",
      "Rate": "High",
      "Receptacle": "Standard-A",
      "Standard": "[0-9]+.[0-9]+", (re)
      "Type": "Host"
    },
    "USB.USBHosts.": {
      "AllowAllDevices": 1,
      "AllowedDeviceNumberOfEntries": 0,
      "HostNumberOfEntries": 2
    },
    "USB.USBHosts.Host.1.": {
      "Alias": "usb-Host-1",
      "DeviceNumberOfEntries": 0,
      "Enable": 1,
      "Name": "usb-Host-1",
      "PowerManagementEnable": 0,
      "Reset": 0,
      "Type": "xHCI",
      "USBVersion": "2.(1|0)0" (re)
    },
    "USB.USBHosts.Host.2.": {
      "Alias": "usb-Host-2",
      "DeviceNumberOfEntries": 1,
      "Enable": 1,
      "Name": "usb-Host-2",
      "PowerManagementEnable": 0,
      "Reset": 0,
      "Type": "xHCI",
      "USBVersion": "3.(2|0)0" (re)
    },
    "USB.USBHosts.Host.2.Device.[0-9]+.": { (re)
      "ConfigurationNumberOfEntries": 1,
      "DeviceClass": "00",
      "DeviceNumber": 2,
      "DeviceProtocol": "00",
      "DeviceSubClass": "00",
      "DeviceVersion": 100,
      "IsAllowed": 1,
      "IsSelfPowered": 0,
      "IsSuspended": 0,
      "Manufacturer": "USB",
      "MaxChildren": 0,
      "Parent": "",
      "Port": 1,
      "ProductClass": "SanDisk 3.2Gen1",
      "ProductID": 21905,
      "Rate": "Super",
      "SerialNumber": "*", (glob)
      "USBPort": "Device.USB.Port.[0-9]+.", (re)
      "USBVersion": "3.(2|0)0", (re)
      "VendorID": 1921
    },
    "USB.USBHosts.Host.2.Device.[0-9]+.Configuration.1.": { (re)
      "ConfigurationNumber": 1,
      "InterfaceNumberOfEntries": 1
    },
    "USB.USBHosts.Host.2.Device.[0-9]+.Configuration.1.Interface.1.": { (re)
      "InterfaceClass": "08",
      "InterfaceNumber": 0,
      "InterfaceProtocol": "50",
      "InterfaceSubClass": "06"
    }
  }
