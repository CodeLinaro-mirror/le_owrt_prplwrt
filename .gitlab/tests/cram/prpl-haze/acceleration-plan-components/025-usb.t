Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Assure USB. datamodel content with no USB devices plugged in:

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
        "HostNumberOfEntries": 4
      },
      "USB.USBHosts.Host.1.": {
        "USBVersion": "2.00",
        "DeviceNumberOfEntries": 0,
        "PowerManagementEnable": 0,
        "Enable": 1,
        "Name": "usb-Host-1",
        "Reset": 0,
        "Alias": "usb-Host-1",
        "Type": "xHCI"
      },
      "USB.USBHosts.Host.3.": {
        "USBVersion": "2.00",
        "DeviceNumberOfEntries": 0,
        "PowerManagementEnable": 0,
        "Enable": 1,
        "Name": "usb-Host-3",
        "Reset": 0,
        "Alias": "usb-Host-3",
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
      "USB.USBHosts.Host.2.": {
        "USBVersion": "3.00",
        "DeviceNumberOfEntries": 0,
        "PowerManagementEnable": 0,
        "Enable": 1,
        "Name": "usb-Host-2",
        "Reset": 0,
        "Alias": "usb-Host-2",
        "Type": "xHCI"
      },
      "USB.USBHosts.Host.4.": {
        "USBVersion": "3.00",
        "DeviceNumberOfEntries": 0,
        "PowerManagementEnable": 0,
        "Enable": 1,
        "Name": "usb-Host-4",
        "Reset": 0,
        "Alias": "usb-Host-4",
        "Type": "xHCI"
      }
    }
  ]
