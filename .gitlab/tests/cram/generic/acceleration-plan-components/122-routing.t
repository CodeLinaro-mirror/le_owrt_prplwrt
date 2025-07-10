Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Create route in OS:

  $ R "ip r a 8.8.8.8 dev br-lan" > /dev/null 2>&1


Check that Routing data model is populated automatically with above created route:

  $ R "ba-cli --json 'Routing.Router.1.IPv4Forwarding.[DestIPAddress==\"8.8.8.8\"].?' | sed -n '2p'" | jq --sort-keys '.[0]' | grep -v -E '(Interface|Alias)'
  {
    "Routing.Router.1.IPv4Forwarding.\d+.": { (re)
      "DestIPAddress": "8.8.8.8",
      "DestSubnetMask": "255.255.255.255",
      "Enable": 1,
      "ForwardingMetric": 0,
      "ForwardingPolicy": -1,
      "GatewayIPAddress": "",
      "MTU": 0,
      "Origin": "Automatic",
      "StaticRoute": 0,
      "Status": "Enabled"
    }
  }


Check that NetDev data model is populated automatically with above created route:

  $ R "ba-cli --json 'NetDev.Link.[Alias==\"br-lan\"].IPv4Route.[Dst==\"8.8.8.8\"].?' | sed -n '2p'" | jq --sort-keys '.[0]' | grep -v -E '(Alias)'
  {
    "NetDev.Link.\d+.IPv4Route.\d+.": { (re)
      "AdvMSS": 0,
      "Dst": "8.8.8.8",
      "DstLen": 32,
      "Gateway": "",
      "HopLimit": 0,
      "MTU": 0,
      "PrefSrc": "",
      "Priority": 0,
      "Protocol": "boot",
      "Scope": "link",
      "Table": "main",
      "Type": "unicast"
    }
  }

Try to delete the route added to the OS. The command should succeed but the route should not be removed from the OS. 
  $ R "ba-cli 'Routing.Router.1.IPv4Forwarding.[DestIPAddress==\"8.8.8.8\"].-'" > /dev/null 

  $ R "ip r | grep 8.8.8.8"
  8.8.8.8 dev br-lan scope link 


Delete route in OS:

  $ R "ip r d 8.8.8.8 dev br-lan" > /dev/null 2>&1
