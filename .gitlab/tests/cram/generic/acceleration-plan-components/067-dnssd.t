Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check the root datamodel settings:

  $ R "ba-cli --json DNSSD.? | sed -n '2p'" | jq --sort-keys '.[0]'
  {
    "DNSSD.": {
      "AdvertiseNumberOfEntries": 1,
      "AdvertisedInterfaces": "Device.IP.Interface.3.",
      "Enable": 1,
      "ServiceNumberOfEntries": 0,
      "Status": "Enabled"
    },
    "DNSSD.Advertise.1.": {
      "Alias": "usp-agt-mqtt",
      "ApplicationProtocol": "mqtt",
      "Enable": 1,
      "InstanceName": "usp-agt-mqtt",
      "Port": 0,
      "Status": "Enabled",
      "TextRecordNumberOfEntries": 1,
      "TransportProtocol": "TCP"
    },
    "DNSSD.Advertise.1.TextRecord.1.": {
      "Key": "From",
      "Value": "sah"
    }
  }

Check that firewall is configured properly:

  $ R "iptables -nL | grep 5353"
  ACCEPT     17   --  0.0.0.0/0            0.0.0.0/0            udp dpt:5353

Check that DNS-Based Service Discovery service is responding:

  $ sudo nmap -Pn  -p5353 -sU 192.168.1.1 2>&1 | grep zeroconf
  5353/udp open|filtered zeroconf
